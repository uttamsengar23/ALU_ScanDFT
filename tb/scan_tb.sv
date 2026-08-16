// scan_tb.sv
// -----------------------------------------------------------------------
// Proves the complete scan-shift/capture flow on alu_scan.v:
//
//   1. FUNCTIONAL CHECK  : run a normal ALU operation with scan_enable=0,
//                          confirm alu_scan behaves like alu.v.
//   2. CAPTURE           : with a known a/b/opcode applied, let the
//                          combinational result settle, then do ONE
//                          functional clock edge to capture it into the
//                          scan chain's flops (still scan_enable=0 for
//                          this single capture edge).
//   3. SHIFT-OUT         : switch to scan_enable=1 and shift the
//                          captured 7 bits out through scan_out, MSB
//                          first (bit 6 = negative ... bit 0 = result[0]),
//                          comparing each bit against what we expect.
//   4. SHIFT-IN           : switch to scan_enable=1 and shift a KNOWN
//                          7-bit test pattern IN through scan_in,
//                          proving every state bit is independently
//                          controllable, not just observable.
//   5. RE-CAPTURE/READBACK: shift the just-loaded pattern back out to
//                          confirm it landed exactly as shifted in.
//
// This is the core DFT proof: every internal state bit is both
// observable (step 3) and controllable (step 4) from the chip's
// boundary, without needing direct physical access to each flop.
// -----------------------------------------------------------------------

`timescale 1ns/1ps

module scan_tb;

    localparam WIDTH = 7;

    logic        clk, rst, scan_enable, scan_in;
    logic [3:0]  a, b;
    logic [2:0]  opcode;
    logic [3:0]  result;
    logic        zero, carry, negative, scan_out;

    alu_scan dut (
        .clk         (clk),
        .rst         (rst),
        .scan_enable (scan_enable),
        .scan_in     (scan_in),
        .a           (a),
        .b           (b),
        .opcode      (opcode),
        .result      (result),
        .zero        (zero),
        .carry       (carry),
        .negative    (negative),
        .scan_out    (scan_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    int pass_count = 0;
    int fail_count = 0;

    task automatic check(input bit got, input bit exp, input string label);
        if (got === exp) begin
            $display("[PASS] %-28s got=%0b exp=%0b", label, got, exp);
            pass_count++;
        end
        else begin
            $display("[FAIL] %-28s got=%0b exp=%0b", label, got, exp);
            fail_count++;
        end
    endtask

    // Shifts `pattern_in` into the chain (MSB first) while simultaneously
    // capturing whatever shifts OUT into `captured_out`. Both happen on
    // the same WIDTH clock edges since it's a single shared shift register.
    task automatic scan_shift(input logic [WIDTH-1:0] pattern_in,
                               output logic [WIDTH-1:0] captured_out);
        integer i;
        begin
            scan_enable = 1'b1;
            for (i = WIDTH-1; i >= 0; i = i - 1) begin
                // Sample scan_out BEFORE this cycle's shift edge -- scan_out
                // still reflects the chain's content from before this clock,
                // which is exactly the bit we want to capture this cycle.
                captured_out = {captured_out[WIDTH-2:0], scan_out};
                scan_in = pattern_in[i];
                @(posedge clk);
                #1; // let the update settle before the next iteration samples
            end
        end
    endtask

    logic [WIDTH-1:0] shifted_out;
    logic [WIDTH-1:0] expected_bits;

    initial begin
        rst = 1'b1;
        scan_enable = 1'b0;
        scan_in = 1'b0;
        a = 0; b = 0; opcode = 0;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);

        // ---------------- 1. FUNCTIONAL CHECK ----------------
        a = 4'd6; b = 4'd3; opcode = 3'b000; // ADD: 6+3=9
        @(posedge clk); // apply
        @(posedge clk); #1; // let result register update, then settle
        check(result == 4'd9, 1'b1, "Functional ADD result==9");
        check(zero,     1'b0, "Functional ADD zero flag");

        // ---------------- 2. CAPTURE a known value ----------------
        rst = 1'b0;
        a = 4'd5; b = 4'd5; opcode = 3'b001; // SUB: 5-5=0 -> zero flag set
        @(posedge clk); #1; // capture edge, scan_enable still 0, then settle

        // Expected 7-bit pattern: {negative, carry, zero, result[3:0]}
        expected_bits = {1'b0, 1'b1, 1'b1, 4'b0000}; // no borrow->carry=1, zero=1, result=0
        check(result == 4'b0000, 1'b1, "Captured result==0 (5-5)");
        check(zero,              1'b1, "Captured zero flag set");

        // ---------------- 3. SHIFT-OUT and verify ----------------
        // NOTE: shifting will disturb the chain's contents (it's a shift
        // register), so we only get ONE clean read of the captured value.
        scan_shift(7'b0000000, shifted_out); // shift in dummy zeros, capture what comes out
        check(shifted_out == expected_bits, 1'b1, "Shifted-out pattern matches captured result");
        $display("        shifted_out=%07b expected=%07b", shifted_out, expected_bits);

        // ---------------- 4. SHIFT-IN a known test pattern ----------------
        scan_enable = 1'b1;
        scan_shift(7'b1011010, shifted_out); // arbitrary known pattern

        // ---------------- 5. READBACK: shift it straight back out ----------------
        scan_shift(7'b0000000, shifted_out);
        check(shifted_out == 7'b1011010, 1'b1, "Shifted-in pattern reads back correctly");
        $display("        shifted_out=%07b expected=%07b", shifted_out, 7'b1011010);

        scan_enable = 1'b0;

        $display("--------------------------------------------------");
        $display("Scan chain test complete: %0d passed, %0d failed", pass_count, fail_count);
        $display("--------------------------------------------------");
        $finish;
    end

