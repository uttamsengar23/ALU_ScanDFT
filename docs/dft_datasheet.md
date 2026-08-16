# ALU_DFT — Design for Test Datasheet

## Overview

`ALU_DFT` takes a small 4-bit ALU and makes it testable using
scan-based Design for Test (DFT): a standard technique for making a
chip's internal state controllable and observable from outside the
chip, without needing physical probe access to every internal node.

This document covers the architecture, how scan operation works in
this design, the fault model used to demonstrate test quality, and
the verification results.

---

## 1. Architecture

```
              alu.v (golden functional baseline)
                       |
              Functional verification (alu_tb.sv) -- 29/29 passed
                       |
                       v
                 scan_ff.v (scan flip-flop primitive)
                       |
                       v
              scan_chain.v (7-bit shift register)
                       |
                       v
                 alu_scan.v (ALU + scan chain integrated)
                       |
         +-------------+-------------+
         |                           |
   scan_tb.sv                 dft_assertions.sv
   (shift verification)       (continuous protocol checks)
   6/6 passed                 bound via `bind`, confirmed
                               instantiated and running
         |                           |
         +-------------+-------------+
                       |
                       v
              fault_tb.sv (stuck-at fault injection)
                       |
                       v
              fault_results.log --> fault_coverage.py
                       |
                 8/8 detected, 100% fault coverage
```

`alu.v` is the golden, unmodified functional design — it is never
edited once proven correct. `alu_scan.v` is a **separate, new**
top-level module that re-implements the same combinational logic but
routes the result/flag registers through a scan chain instead of
plain flip-flops. This mirrors the "prove the baseline, then build a
parallel testable version without touching the baseline" approach
used earlier in this portfolio's UART+FIFO project.

---

## 2. Interface

### `alu.v` (golden functional baseline)

| Port | Direction | Width | Description |
|------|-----------|-------|--------------|
| `clk` | in | 1 | System clock |
| `rst` | in | 1 | Synchronous active-high reset |
| `a` | in | 4 | Operand A |
| `b` | in | 4 | Operand B |
| `opcode` | in | 3 | Operation select (see table below) |
| `result` | out | 4 | Registered ALU result |
| `zero` | out | 1 | Set when result == 0 |
| `carry` | out | 1 | Carry-out (ADD) / not-borrow (SUB), else 0 |
| `negative` | out | 1 | Sign bit of the result |

Opcodes: `000`=ADD, `001`=SUB, `010`=AND, `011`=OR, `100`=XOR, others
default to `result=0`.

### `alu_scan.v` (testable version)

Same functional ports as `alu.v`, plus:

| Port | Direction | Width | Description |
|------|-----------|-------|--------------|
| `scan_enable` | in | 1 | 0 = functional mode, 1 = scan/shift mode |
| `scan_in` | in | 1 | Serial scan chain input |
| `scan_out` | out | 1 | Serial scan chain output |

In functional mode (`scan_enable=0`), `alu_scan` behaves identically
to `alu.v` — same operations, same timing. In scan mode
(`scan_enable=1`), the 7 internal state bits below can be shifted in
and out serially instead of being driven by the ALU's normal
datapath:

| Chain bit | Signal |
|-----------|--------|
| 0-3 | `result[3:0]` |
| 4 | `zero` |
| 5 | `carry` |
| 6 | `negative` |

---

## 3. How scan operation works

1. **Functional mode** (`scan_enable=0`): each scan flip-flop
   (`scan_ff.v`) behaves as a normal D flip-flop, capturing the ALU's
   computed result/flags every clock cycle, same as `alu.v`.
2. **Capture**: a normal functional operation runs for one clock
   edge, latching a result into the 7-bit scan chain — this is a
   completely ordinary functional clock edge, no special scan
   behavior needed.
3. **Shift-out** (`scan_enable=1`): each subsequent clock edge shifts
   the entire 7-bit chain by one position, with `scan_out` exposing
   the last flop's value each cycle. Over 7 clock edges, every bit of
   the captured state becomes observable at the chip boundary.
4. **Shift-in** (`scan_enable=1`): the same mechanism works in
   reverse — driving `scan_in` with a chosen pattern over 7 clock
   edges loads that exact pattern into the chain, proving every bit
   is independently controllable, not just observable.

This combination — controllability (shift-in) and observability
(shift-out) — is the fundamental purpose of scan-based DFT.

**Sampling note:** `scan_out` reflects the chain's state *before* a
shift edge is applied, not after — a testbench must sample it prior
to issuing the next clock edge to read out bits in the correct order.
(This was a real bug hit and fixed during development of
`scan_tb.sv` — see verification results below.)

---

## 4. Fault model

Manufacturing-defect testability is demonstrated using the
**stuck-at fault model** — see `stuck_at_faults.md` for the full
explanation. In short: 8 faults are modeled (each bit of `result[3:0]`,
stuck-at-0 and stuck-at-1), and a 10-pattern test set
(`test_patterns.txt`) is checked for whether it can detect each one
by comparing golden vs. faulty ALU output.

---

## 5. Verification results

| Test | File | Result |
|------|------|--------|
| Functional correctness | `alu_tb.sv` | 29/29 passed (9 directed + 20 randomized) |
| Scan shift/capture (observability + controllability) | `scan_tb.sv` | 6/6 passed |
| Continuous protocol assertions | `dft_assertions.sv` | Confirmed instantiated via `bind`; no violations across all runs |
| Stuck-at fault detection | `fault_tb.sv` / `fault_coverage.py` | 8/8 faults detected — 100% fault coverage |

**A real bug found and fixed during development:** the initial
`scan_tb.sv` sampled `scan_out` *after* each clock edge instead of
before, causing every shifted-out bit to be read one position late
(`shifted_out=0x34` vs expected `0x30`). Root-caused via waveform
inspection, fixed by reordering the sample-then-shift sequence, and
re-verified passing. Both the failing and passing waveforms are kept
in `waveforms/scan_shift/` as before/after evidence.

---

## 6. Tooling

Simulated entirely in **Vivado's xsim** (bundled free with Vivado
WebPACK — no separate UVM/commercial simulator license required,
since this project uses hand-built SystemVerilog classes/behavioral
constructs rather than the UVM library). `fault_coverage.py` is a
standalone Python script with no external dependencies beyond the
standard library.

---

## 7. Scope and limitations

This is a student-scoped project demonstrating core DFT concepts, not
a production ATPG flow:

- Only `result[3:0]` is modeled as fault sites; a full flow would
  also cover internal gates, flag logic, and the scan chain's own
  flops.
- Test patterns are hand-picked for good coverage, not generated by
  an automated ATPG algorithm.
- Only the stuck-at fault model is covered (no bridging, transition,
  or delay faults).
- No physical synthesis / gate-level netlist was generated for this
  project — everything is verified at the RTL/behavioral level.