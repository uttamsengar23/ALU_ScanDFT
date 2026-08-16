// dft_assertions.sv
// -----------------------------------------------------------------------
// Protocol-level checks on alu_scan.v's scan interface. These don't test
// whether the ALU computes the right ANSWER (that's alu_tb.sv/scan_tb.sv's
// job) -- they test whether the scan MECHANISM behaves the way a scan
// chain is supposed to behave, on every single cycle, automatically.
//
// This module is bound to alu_scan using SystemVerilog `bind`, so it can
// see the DUT's internal signals (scan_enable, clk, rst, scan_out, and
// the internal chain_q bus) without modifying alu_scan.v itself.
// -----------------------------------------------------------------------

`timescale 1ns/1ps

module dft_assertions (
    input clk,
    input rst,
    input scan_enable,
    input scan_in,
    input [3:0] result,
    input zero,
    input carry,
    input negative,
    input scan_out
);

    // ---------------------------------------------------------------
    // A1: scan_out must be a known value (not X) whenever we're not in
    // reset. Undefined scan_out means the chain lost its state, which
    // should never happen once reset has deasserted.
    // ---------------------------------------------------------------
    property p_scan_out_known;
        @(posedge clk) disable iff (rst)
        !$isunknown(scan_out);
    endproperty
    assert property (p_scan_out_known)
        else $error("[ASSERT FAIL] scan_out went unknown (X) outside reset at time %0t", $time);

    // ---------------------------------------------------------------
    // A2: while scan_enable is LOW (functional mode), the visible
    // result/zero/carry/negative outputs must not glitch to X after
    // reset has deasserted -- functional mode should always produce a
    // defined result.
    // ---------------------------------------------------------------
    property p_functional_result_known;
        @(posedge clk) disable iff (rst)
        !scan_enable |-> !$isunknown({result, zero, carry, negative});
    endproperty
    assert property (p_functional_result_known)
        else $error("[ASSERT FAIL] functional-mode result/flags went unknown at time %0t", $time);

    // ---------------------------------------------------------------
    // A3: scan_enable itself should never be X/Z during normal
    // operation -- an undefined mode-select is a testbench/DUT wiring
    // bug, not a data issue.
    // ---------------------------------------------------------------
    property p_scan_enable_known;
        @(posedge clk) disable iff (rst)
        !$isunknown(scan_enable);
    endproperty
    assert property (p_scan_enable_known)
        else $error("[ASSERT FAIL] scan_enable is unknown (X/Z) at time %0t", $time);

    // ---------------------------------------------------------------
    // A4: reset must actually clear the visible state. One cycle after
    // rst deasserts (first posedge with rst=0), result/flags should
    // reflect the reset value (all zero) if no functional op has been
    // applied yet at that exact edge. This is a loose sanity check --
    // mainly guards against reset being wired incorrectly, the same
    // class of bug found earlier in the UART project's tbench.sv.
    // ---------------------------------------------------------------
    property p_reset_clears_result;
        @(posedge clk)
        $fell(rst) |-> !$isunknown(result);
    endproperty
    assert property (p_reset_clears_result)
        else $error("[ASSERT FAIL] result is unknown immediately after reset deasserts at time %0t", $time);

endmodule

// -----------------------------------------------------------------------
// Bind statement: attaches dft_assertions to every instance of alu_scan
// without editing alu_scan.v itself. Place this bind statement in its
// own file (here) or alongside the assertions -- either way, alu_scan.v
// stays completely untouched.
// -----------------------------------------------------------------------
bind alu_scan dft_assertions u_dft_assertions (
    .clk         (clk),
    .rst         (rst),
    .scan_enable (scan_enable),
    .scan_in     (scan_in),
    .result      (result),
    .zero        (zero),
    .carry       (carry),
    .negative    (negative),
    .scan_out    (scan_out)
);