#!/usr/bin/env python3
"""
fault_coverage.py
------------------------------------------------------------------
Parses fault_results.log (produced by tb/fault_tb.sv during
simulation) and prints a clean, formatted fault-coverage report.

This does NOT recompute coverage independently -- fault_tb.sv already
calculates the real numbers during simulation and logs each fault's
site/stuck-value/detected result as a plain CSV line. This script's
job is purely to read that log and present it clearly: a per-fault
breakdown table plus a summary, the kind of report you'd hand to
someone who wants to see results without reading Verilog or scrolling
through a Tcl console.

Usage:
    python fault_coverage.py fault_results.log

If no path is given, defaults to "fault_results.log" in the current
directory.
------------------------------------------------------------------
"""

import sys
import csv
from pathlib import Path


def load_results(log_path: Path):
    """Read the CSV log written by fault_tb.sv.

    Expected format:
        site,stuck_at,detected      (header)
        <site>,<stuck_at>,<0 or 1>  (one row per fault)
        TOTAL,<total_faults>,<detected_faults>   (final summary row)
    """
    if not log_path.exists():
        print(f"ERROR: log file not found: {log_path}")
        print("Run the fault_tb.sv simulation first, then copy the")
        print("generated fault_results.log into this folder (or pass")
        print("its path as an argument to this script).")
        sys.exit(1)

    fault_rows = []
    total_faults = None
    detected_faults = None

    with open(log_path, newline="") as f:
        reader = csv.reader(f)
        header = next(reader, None)  # skip "site,stuck_at,detected"

        for row in reader:
            if not row:
                continue
            if row[0] == "TOTAL":
                total_faults = int(row[1])
                detected_faults = int(row[2])
            else:
                site, stuck_at, detected = int(row[0]), int(row[1]), int(row[2])
                fault_rows.append((site, stuck_at, detected))

    if total_faults is None:
        # Fallback: derive totals from the rows themselves if the log
        # somehow doesn't have a TOTAL line (e.g. sim was interrupted).
        total_faults = len(fault_rows)
        detected_faults = sum(1 for r in fault_rows if r[2] == 1)

    return fault_rows, total_faults, detected_faults


def print_report(fault_rows, total_faults, detected_faults):
    print("=" * 56)
    print("ALU_DFT -- Stuck-at Fault Coverage Report")
    print("=" * 56)
    print(f"{'Fault site':<14}{'Stuck-at':<12}{'Result':<10}")
    print("-" * 56)

    for site, stuck_at, detected in fault_rows:
        status = "DETECTED" if detected else "MISSED"
        print(f"result[{site}]{'':<7}stuck-at-{stuck_at:<4}{status:<10}")

    print("-" * 56)
    coverage = (detected_faults / total_faults * 100.0) if total_faults else 0.0
    print(f"Total faults modeled : {total_faults}")
    print(f"Faults detected      : {detected_faults}")
    print(f"Fault coverage        : {coverage:.2f}%")
    print("=" * 56)

    # Simple ASCII coverage bar, just for a quick visual in a terminal
    bar_width = 40
    filled = int(bar_width * coverage / 100.0)
    bar = "#" * filled + "-" * (bar_width - filled)
    print(f"[{bar}] {coverage:.1f}%")


def main():
    log_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("fault_results.log")
    fault_rows, total_faults, detected_faults = load_results(log_path)
    print_report(fault_rows, total_faults, detected_faults)


if __name__ == "__main__":
    main()