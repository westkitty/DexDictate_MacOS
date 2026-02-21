#!/usr/bin/env python3
import sys
import re

LOG_FILE = "/Users/andrew/Library/Application Support/DexDictate/debug.log"
CSV_OUT = "baseline.csv"

# Example metric line we are looking for:
# METRIC_CSV: series,config,utt_id,rep,ref,hyp,t_trigger_ms,t_audio_ms,t_resample_ms,t_submit_ms,t_done_ms,t_total_ms,raw_samples,trim_samples,resp_samples

if __name__ == "__main__":
    if len(sys.argv) > 1:
        LOG_FILE = sys.argv[1]

    print(f"Parsing logs from {LOG_FILE}...")
    headers_printed = False

    try:
        with open(LOG_FILE, "r") as f, open(CSV_OUT, "w") as out:
            for line in f:
                if "METRIC_CSV:" in line:
                    csv_part = line.split("METRIC_CSV:")[1].strip()
                    if not headers_printed:
                        # Ensure we print headers if we are starting a fresh file
                        if not csv_part.startswith("timestamp,"):
                            out.write("timestamp,raw_samples,trim_samples,resample_samples,t_audio_stop_ms,t_resample_ms,t_whisper_ms,t_total_ms\n")
                        headers_printed = True
                    out.write(csv_part + "\n")
                    
        print(f"Extracted to {CSV_OUT}")
    except FileNotFoundError:
        print(f"Log file {LOG_FILE} not found.")
