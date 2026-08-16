# ALU_DFT

A small 4-bit ALU made testable using scan-based Design for Test (DFT),
with a stuck-at fault model demonstrating manufacturing-defect
detectability. Built to demonstrate core DFT concepts: controllability,
observability, and test quality measurement.

## What's in here

Take a functional ALU -> make its internal state controllable and
observable through a scan chain -> apply test patterns -> model
manufacturing faults -> measure how many faults those patterns catch.

## Results

| Check | Result |
|-------|--------|
| ALU functional correctness | 29/29 passed |
| Scan chain shift/capture (observability + controllability) | 6/6 passed |
| Continuous protocol assertions | Confirmed running, no violations |
| Stuck-at fault detection | 8/8 faults detected — 100% fault coverage |

See `docs/dft_datasheet.md` for the full writeup, architecture diagram,
interface tables, and a real debugged-bug story from development.

## Structure

```
ALU_DFT/
├── rtl/
│   ├── alu.v              golden functional ALU (untouched baseline)
│   ├── scan_ff.v          scan-capable flip-flop primitive
│   ├── scan_chain.v       chains multiple scan_ff instances
│   └── alu_scan.v         ALU + scan chain integrated (testable version)
├── tb/
│   ├── alu_tb.sv          functional testbench for alu.v
│   ├── scan_tb.sv         scan shift/capture verification
│   ├── dft_assertions.sv  continuous SVA protocol checks (bound to alu_scan)
│   └── fault_tb.sv        stuck-at fault injection and detection
├── fault_Analysis/
│   ├── stuck_at_faults.md fault model explanation
│   ├── test_patterns.txt  the 10 test patterns used
│   └── fault_coverage.py  parses fault_results.log into a formatted report
├── docs/
│   └── dft_datasheet.md   full engineering writeup
├── waveforms/
│   ├── functional/
│   ├── scan_shift/        includes before/after: bug found, then fixed
│   └── fault_detection/
└── scripts/
```

## How to run

1. Open the project in Vivado (WebPACK edition works fine — no UVM
   license needed, this uses hand-built SystemVerilog classes, not
   the UVM library).
2. Add `rtl/*.v` as design sources.
3. Add `tb/alu_tb.sv` as a simulation source, set as top, run
   behavioral simulation -> confirms the golden ALU is correct.
4. Add `tb/scan_ff.v` through `tb/alu_scan.v`'s dependencies, plus
   `tb/scan_tb.sv` and `tb/dft_assertions.sv`, set `scan_tb` as top,
   run -> confirms scan observability/controllability.
5. Add `tb/fault_tb.sv`, set as top, run -> prints fault detection
   results to console and writes `fault_results.log`.
6. Copy `fault_results.log` into `atpg/`, then run:
   ```
   python fault_coverage.py fault_results.log
   ```
   for the formatted coverage report.

## Notes

- `alu.v` and `alu_scan.v` are separate, independent top-level
  modules — the golden baseline is never modified once proven
  correct; the testable version is built alongside it.
- This project intentionally scopes to the stuck-at fault model and
  hand-picked test patterns rather than commercial ATPG tooling — see
  `docs/dft_datasheet.md` for the full scope/limitations discussion.
