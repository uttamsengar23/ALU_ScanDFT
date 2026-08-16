· V
// alu_scan.v
// -----------------------------------------------------------------------
// The testable version of the ALU: same combinational logic as alu.v,
// but the result/flag registers are now scan_ff instances (wired through
// scan_chain.v) instead of plain flip-flops.
//
// In functional mode (scan_enable = 0) this behaves EXACTLY like alu.v --
// same ops, same timing, same outputs. alu.v itself is left completely
// untouched; this is a separate, new top-level module.
//
// In scan mode (scan_enable = 1) the 7 state bits below can be shifted
// in/out through scan_in/scan_out instead of being driven by the ALU's
// normal datapath:
//
//   bit 0..3 -> result[3:0]
//   bit 4    -> zero
//   bit 5    -> carry
//   bit 6    -> negative
//
// -----------------------------------------------------------------------
 
module alu_scan (
    input        clk,
    input        rst,
    input        scan_enable,
    input        scan_in,
    input  [3:0] a,
    input  [3:0] b,
    input  [2:0] opcode,
    output [3:0] result,
    output       zero,
    output       carry,
    output       negative,
    output       scan_out
);
 
    localparam WIDTH = 7;
 
    // ---- Same combinational logic as alu.v (functional "d" inputs) ----
    wire [4:0] add_ext = {1'b0, a} + {1'b0, b};
    wire [4:0] sub_ext = {1'b0, a} - {1'b0, b};
    wire [3:0] and_result = a & b;
    wire [3:0] or_result  = a | b;
    wire [3:0] xor_result = a ^ b;
 
    reg [3:0] result_d;
    reg       zero_d, carry_d, negative_d;
 
    always @(*) begin
        case (opcode)
            3'b000: begin // ADD
                result_d   = add_ext[3:0];
                carry_d    = add_ext[4];
                zero_d     = (add_ext[3:0] == 4'b0000);
                negative_d = add_ext[3];
            end
            3'b001: begin // SUB
                result_d   = sub_ext[3:0];
                carry_d    = ~sub_ext[4];
                zero_d     = (sub_ext[3:0] == 4'b0000);
                negative_d = sub_ext[3];
            end
            3'b010: begin // AND
                result_d   = and_result;
                carry_d    = 1'b0;
                zero_d     = (and_result == 4'b0000);
                negative_d = and_result[3];
            end
            3'b011: begin // OR
                result_d   = or_result;
                carry_d    = 1'b0;
                zero_d     = (or_result == 4'b0000);
                negative_d = or_result[3];
            end
            3'b100: begin // XOR
                result_d   = xor_result;
                carry_d    = 1'b0;
                zero_d     = (xor_result == 4'b0000);
                negative_d = xor_result[3];
            end
            default: begin
                result_d   = 4'b0000;
                carry_d    = 1'b0;
                zero_d     = 1'b1;
                negative_d = 1'b0;
            end
        endcase
    end
 
    // ---- Pack functional "d" inputs into the scan chain's bus ----
    wire [WIDTH-1:0] chain_d = {negative_d, carry_d, zero_d, result_d};
    wire [WIDTH-1:0] chain_q;
 
    scan_chain #(.WIDTH(WIDTH)) u_scan_chain (
        .clk         (clk),
        .rst         (rst),
        .scan_enable (scan_enable),
        .d           (chain_d),
        .scan_in     (scan_in),
        .q           (chain_q),
        .scan_out    (scan_out)
    );
 
    // ---- Unpack the chain's registered outputs back to named signals ----
    assign result   = chain_q[3:0];
    assign zero     = chain_q[4];
    assign carry    = chain_q[5];
    assign negative = chain_q[6];
 
endmodule