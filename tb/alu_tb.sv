// alu_tb.sv
// -----------------------------------------------------------------------
// Standalone functional testbench for alu.v.
// Goal: prove the plain ALU is correct BEFORE any scan/DFT logic is
// introduced. This file never talks to alu_scan.v / scan_ff.v / anything
// DFT-related — it is purely a functional sanity check on the golden
// design.
// -----------------------------------------------------------------------

`timescale 1ns/1ps
module alu_tb;

    logic        clk, rst;
    logic [3:0]  a, b;
    logic [2:0]  opcode;
    logic [3:0]  result;
    logic        zero, carry, negative;

    // Instantiate the golden ALU (unmodified)
    alu dut (
        .clk      (clk),
        .rst      (rst),
        .a        (a),
        .b        (b),
        .opcode   (opcode),
        .result   (result),
        .zero     (zero),
        .carry    (carry),
        .negative (negative)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Reference model: plain behavioral computation to compare against
    function automatic [3:0] expected_result(input [3:0] a_in, input [3:0] b_in, input [2:0] op);
        case (op)
            3'b000:  expected_result = a_in + b_in;
            3'b001:  expected_result = a_in - b_in;
            3'b010:  expected_result = a_in & b_in;
            3'b011:  expected_result = a_in | b_in;
            3'b100:  expected_result = a_in ^ b_in;
            default: expected_result = 4'b0000;
        endcase
    endfunction

    int pass_count = 0;
    int fail_count = 0;

    task automatic check_one(input [3:0] a_in, input [3:0] b_in, input [2:0] op, input string label);
        logic [3:0] exp;
        begin
            a      = a_in;
            b      = b_in;
            opcode = op;
            @(posedge clk); // apply
            @(posedge clk); // wait for registered result to update
            exp = expected_result(a_in, b_in, op);

            if (result === exp) begin
                $display("[PASS] %-6s a=%0d b=%0d op=%0d -> result=%0d (exp=%0d) zero=%0b carry=%0b neg=%0b",
                          label, a_in, b_in, op, result, exp, zero, carry, negative);
                pass_count++;
            end
            else begin
                $display("[FAIL] %-6s a=%0d b=%0d op=%0d -> result=%0d (exp=%0d)",
                          label, a_in, b_in, op, result, exp);
                fail_count++;
            end
        end
    endtask

    initial begin
        rst = 1'b1;
        a = 0; b = 0; opcode = 0;
        repeat (3) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);

        // Directed tests covering each op, plus zero/negative/carry corners
        check_one(4'd3,  4'd2,  3'b000, "ADD");   // normal add
        check_one(4'd15, 4'd1,  3'b000, "ADD");   // add overflow -> carry
        check_one(4'd5,  4'd5,  3'b001, "SUB");   // sub -> zero flag
        check_one(4'd2,  4'd5,  3'b001, "SUB");   // sub -> borrow (negative)
        check_one(4'd12, 4'd10, 3'b010, "AND");
        check_one(4'd12, 4'd10, 3'b011, "OR");
        check_one(4'd12, 4'd10, 3'b100, "XOR");
        check_one(4'd0,  4'd0,  3'b000, "ADD0");  // zero flag on add
        check_one(4'd9,  4'd3,  3'b101, "DFLT");  // unused opcode -> default 0

        // A handful of randomized checks for extra coverage
        for (int i = 0; i < 20; i++) begin
            check_one($urandom_range(0,15), $urandom_range(0,15), $urandom_range(0,4), "RAND");
        end

        $display("--------------------------------------------------");
        $display("ALU functional test complete: %0d passed, %0d failed", pass_count, fail_count);
        $display("--------------------------------------------------");
        $finish;
    end

endmodule