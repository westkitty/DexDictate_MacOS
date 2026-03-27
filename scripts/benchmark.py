#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import sys


def compute_wer(reference, hypothesis):
    """
    Computes Word Error Rate.
    WER = (S + D + I) / N
    where S=Substitutions, D=Deletions, I=Insertions, N=Number of reference words
    """

    def normalize(text):
        text = text.lower()
        text = re.sub(r"[^\w\s]", "", text)
        return text.split()

    ref_words = normalize(reference)
    hyp_words = normalize(hypothesis)

    d = [[0] * (len(hyp_words) + 1) for _ in range(len(ref_words) + 1)]

    for i in range(len(ref_words) + 1):
        d[i][0] = i
    for j in range(len(hyp_words) + 1):
        d[0][j] = j

    for i in range(1, len(ref_words) + 1):
        for j in range(1, len(hyp_words) + 1):
            cost = 0 if ref_words[i - 1] == hyp_words[j - 1] else 1
            d[i][j] = min(
                d[i - 1][j] + 1,
                d[i][j - 1] + 1,
                d[i - 1][j - 1] + cost,
            )

    errors = d[len(ref_words)][len(hyp_words)]
    if len(ref_words) == 0:
        return float("inf") if len(hyp_words) > 0 else 0.0
    return float(errors) / len(ref_words)


def build_runner(build_mode):
    subprocess.run(
        ["swift", "build", "-c", build_mode, "--product", "VerificationRunner"],
        check=True,
    )
    result = subprocess.run(
        ["swift", "build", "-c", build_mode, "--show-bin-path"],
        capture_output=True,
        text=True,
        check=True,
    )
    runner = os.path.join(result.stdout.strip(), "VerificationRunner")
    if not os.path.exists(runner):
        raise FileNotFoundError(f"VerificationRunner not found at {runner}")
    return runner


def load_corpus(audio_dir, transcripts_file):
    manifest_file = os.path.join(audio_dir, "benchmark_manifest.json")
    if os.path.isfile(manifest_file):
        with open(manifest_file, "r", encoding="utf-8") as handle:
            manifest = json.load(handle)

        prompts = manifest.get("prompts", []) if isinstance(manifest, dict) else []
        captured_entries = manifest.get("capturedEntries", []) if isinstance(manifest, dict) else []
        captured_names = {entry.get("fileName") for entry in captured_entries if isinstance(entry, dict) and entry.get("fileName")}

        selected_prompts = []
        for prompt in prompts:
            if not isinstance(prompt, dict):
                continue
            file_name = prompt.get("fileName")
            reference_text = prompt.get("referenceText")
            if not file_name or reference_text is None:
                continue
            if captured_names and file_name not in captured_names:
                continue
            selected_prompts.append((file_name, os.path.join(audio_dir, file_name), reference_text))

        if selected_prompts:
            return selected_prompts

    with open(transcripts_file, "r", encoding="utf-8") as handle:
        transcripts = json.load(handle)

    if not isinstance(transcripts, dict):
        raise ValueError("transcripts JSON must map filenames to expected transcripts")

    corpus = []
    for audio_file, reference_text in transcripts.items():
        file_path = os.path.join(audio_dir, audio_file)
        corpus.append((audio_file, file_path, reference_text))
    return corpus


def main():
    parser = argparse.ArgumentParser(description="Run WER benchmark sweep")
    parser.add_argument("audio_dir", nargs="?", help="Directory containing .wav files")
    parser.add_argument("transcripts_json", nargs="?", help="JSON file mapping filenames to expected transcripts")
    parser.add_argument("--corpus-dir", dest="corpus_dir", help="Directory containing wav files plus transcripts.json")
    parser.add_argument("--model", type=str, default="tiny.en", help="Model name to use (e.g., base.en)")
    parser.add_argument(
        "--decode-profile",
        type=str,
        default="accuracy",
        choices=["accuracy", "balanced", "speed"],
        help="Whisper decode profile used by the benchmark runner",
    )
    parser.add_argument("--build", type=str, default="release", choices=["debug", "release"], help="Swift build mode")
    args = parser.parse_args()

    audio_dir = args.corpus_dir or args.audio_dir
    transcripts_file = args.transcripts_json

    if args.corpus_dir:
        transcripts_file = transcripts_file or os.path.join(args.corpus_dir, "transcripts.json")

    if not audio_dir or not transcripts_file:
        parser.error("Provide either --corpus-dir or the legacy audio_dir + transcripts_json positional arguments.")

    if not os.path.isdir(audio_dir):
        parser.error(f"Audio directory not found: {audio_dir}")
    if not os.path.isfile(transcripts_file):
        parser.error(f"Transcripts JSON not found: {transcripts_file}")

    corpus = load_corpus(audio_dir, transcripts_file)
    runner = build_runner(args.build)

    total_latency_ms = 0
    total_wer = 0.0
    processed = 0

    print("Starting Benchmark Sweep...")
    print("-" * 50)

    for audio_file, file_path, expected_text in corpus:
        if not os.path.exists(file_path):
            print(f"[{audio_file}] SKIPPED (File not found)")
            continue

        try:
            result = subprocess.run(
                [runner, "--benchmark", file_path, "--model", args.model, "--decode-profile", args.decode_profile],
                capture_output=True,
                text=True,
                check=False,
            )
        except Exception as exc:
            print(f"[{audio_file}] FAILED ({exc})")
            continue

        output = (result.stdout or "") + ("\n" + result.stderr if result.stderr else "")

        actual_text = ""
        latency_ms = 0

        for line in output.split("\n"):
            if line.startswith("BENCHMARK_RESULT:"):
                actual_text = line.replace("BENCHMARK_RESULT:", "").strip()
            elif line.startswith("BENCHMARK_LATENCY_MS:"):
                latency_ms = int(line.replace("BENCHMARK_LATENCY_MS:", "").strip())

        if not actual_text and result.returncode != 0:
            print(f"[{audio_file}] FAILED (VerificationRunner exited with {result.returncode})")
            print(output)
            continue

        wer = compute_wer(expected_text, actual_text)

        print(f"File:     {audio_file}")
        print(f"Expected: {expected_text}")
        print(f"Actual:   {actual_text}")
        print(f"Latency:  {latency_ms} ms")
        print(f"WER:      {wer:.2%}")
        print("-" * 50)

        total_latency_ms += latency_ms
        total_wer += wer
        processed += 1

    if processed > 0:
        avg_latency = total_latency_ms / processed
        avg_wer = total_wer / processed
        print("=== BENCHMARK SUMMARY ===")
        print(f"Total Files: {processed}")
        print(f"Avg Latency: {avg_latency:.1f} ms")
        print(f"Avg WER:     {avg_wer:.2%}")
    else:
        print("No files processed.")


if __name__ == "__main__":
    main()
