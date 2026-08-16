// alu.v
// -----------------------------------------------------------------------
// Simple 4-bit ALU with a clocked result register and flags register.
// This is the golden functional baseline BEFORE any DFT/scan logic is
// added. Nothing in this file changes once alu_tb.sv proves it correct.
// -----------------------------------------------------------------------
//
// Opcodes:
//   000 = ADD   result <= a + b
//   001 = SUB   result <= a - b
//   010 = AND   result <= a & b
//   011 = OR    result <= a | b
//   100 = XOR   result <= a ^ b
//   others -> result <= 4'b0000 (default / unused)
//
// Flags (registered, same cycle as result):
//   zero     - result == 4'b0000
//   carry    - carry-out of ADD, or NOT borrow for SUB, else 0
//   negative - result[3] (MSB used as a sign bit for SUB results)
//
// -----------------------------------------------------------------------

module alu (
    input        clk,
    input        rst,          // synchronous active-high reset
    input  [3:0] a,
    input  [3:0] b,
    input  [2:0] opcode,
    output reg [3:0] result,
    output reg   zero,
    output reg   carry,
    output reg   negative
);

    // Internal 5-bit wires so we can capture carry/borrow cleanly
    // before truncating down to the 4-bit result.
    wire [4:0] add_ext = {1'b0, a} + {1'b0, b};
    wire [4:0] sub_ext = {1'b0, a} - {1'b0, b};

    always @(posedge clk) begin
        if (rst) begin
            result   <= 4'b0000;
            zero     <= 1'b0;
            carry    <= 1'b0;
            negative <= 1'b0;
        end
        else begin
            case (opcode)
                3'b000: begin // ADD
                    result <= add_ext[3:0];
                    carry  <= add_ext[4];
                end
                3'b001: begin // SUB
                    result <= sub_ext[3:0];
                    carry  <= ~sub_ext[4]; // 1 = no borrow, 0 = borrow occurred
                end
                3'b010: begin // AND
                    result <= a & b;
                    carry  <= 1'b0;
                end
                3'b011: begin // OR
                    result <= a | b;
                    carry  <= 1'b0;
                end
                3'b100: begin // XOR
                    result <= a ^ b;
                    carry  <= 1'b0;
                end
                default: begin
                    result <= 4'b0000;
                    carry  <= 1'b0;
                end
            endcase

            // zero/negative are derived from the value that's about to be
            // registered into `result` this same cycle. We recompute them
            // combinationally here based on opcode, mirroring `result`'s
            // next value, so all three regs update in lockstep.
            case (opcode)
                3'b000:  begin zero <= (add_ext[3:0] == 4'b0000); negative <= add_ext[3]; end
                3'b001:  begin zero <= (sub_ext[3:0] == 4'b0000); negative <= sub_ext[3]; end
                3'b010:  begin zero <= ((a & b) == 4'b0000);      negative <= (a & b)[3]; end
                3'b011:  begin zero <= ((a | b) == 4'b0000);      negative <= (a | b)[3]; end
                3'b100:  begin zero <= ((a ^ b) == 4'b0000);      negative <= (a ^ b)[3]; end
                default: begin zero <= 1'b1;                      negative <= 1'b0;       end
            endcase
        end
    end

endmodule