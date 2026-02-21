#!/usr/bin/env python3
import os
import sys
import subprocess
import json
import re

def compute_wer(reference, hypothesis):
    """
    Computes Word Error Rate.
    WER = (S + D + I) / N
    where S=Substitutions, D=Deletions, I=Insertions, N=Number of reference words
    """
    # Normalize by lowercasing and removing punctuation
    def normalize(text):
        text = text.lower()
        text = re.sub(r'[^\w\s]', '', text)
        return text.split()
        
    ref_words = normalize(reference)
    hyp_words = normalize(hypothesis)
    
    # Distance matrix
    # rows = ref_words (len+1), cols = hyp_words (len+1)
    d = [[0] * (len(hyp_words) + 1) for _ in range(len(ref_words) + 1)]
    
    for i in range(len(ref_words) + 1):
        d[i][0] = i
    for j in range(len(hyp_words) + 1):
        d[0][j] = j
        
    for i in range(1, len(ref_words) + 1):
        for j in range(1, len(hyp_words) + 1):
            if ref_words[i-1] == hyp_words[j-1]:
                cost = 0
            else:
                cost = 1
            d[i][j] = min(
                d[i-1][j] + 1,      # Deletion
                d[i][j-1] + 1,      # Insertion
                d[i-1][j-1] + cost  # Substitution
            )
            
    errors = d[len(ref_words)][len(hyp_words)]
    if len(ref_words) == 0:
        return float('inf') if len(hyp_words) > 0 else 0.0
    return float(errors) / len(ref_words)

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Run WER benchmark sweep")
    parser.add_argument("audio_dir", help="Directory containing .wav files")
    parser.add_argument("transcripts_json", help="JSON file mapping filenames to expected transcripts")
    parser.add_argument("--model", type=str, default="tiny.en", help="Model name to use (e.g., base.en)")
    args = parser.parse_args()
    
    audio_dir = args.audio_dir
    transcripts_file = args.transcripts_json
    model_name = args.model
    
    with open(transcripts_file, 'r') as f:
        transcripts = json.load(f)
        
    total_latency_ms = 0
    total_wer = 0.0
    processed = 0
    
    print("Starting Benchmark Sweep...")
    print("-" * 50)
    
    for audio_file, expected_text in transcripts.items():
        file_path = os.path.join(audio_dir, audio_file)
        if not os.path.exists(file_path):
            print(f"[{audio_file}] SKIPPED (File not found)")
            continue
            
        # Run VerificationRunner
        try:
            result = subprocess.run(
                ["./scripts/benchmark.sh", file_path, model_name],
                capture_output=True,
                text=True,
                check=False
            )
        except Exception as e:
            print(f"[{audio_file}] FAILED ({e})")
            continue
            
        output = result.stdout + "\n" + result.stderr
        
        # Parse output
        actual_text = ""
        latency_ms = 0
        
        for line in output.split('\n'):
            if line.startswith("BENCHMARK_RESULT:"):
                actual_text = line.replace("BENCHMARK_RESULT:", "").strip()
            elif line.startswith("BENCHMARK_LATENCY_MS:"):
                latency_ms = int(line.replace("BENCHMARK_LATENCY_MS:", "").strip())
                
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
        print(f"=== BENCHMARK SUMMARY ===")
        print(f"Total Files: {processed}")
        print(f"Avg Latency: {avg_latency:.1f} ms")
        print(f"Avg WER:     {avg_wer:.2%}")
    else:
        print("No files processed.")
        
if __name__ == "__main__":
    main()
