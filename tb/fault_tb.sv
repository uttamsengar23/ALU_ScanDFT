// fault_tb.sv
// -----------------------------------------------------------------------
// Demonstrates the core ATPG concept: modeling a manufacturing defect as
// a "stuck-at" fault (a node permanently stuck at 0 or 1, regardless of
// what it should actually be driving), then checking whether a given
// test pattern's OUTPUT changes because of that fault. If the output
// changes, the fault is "detected" by that pattern. If not, that pattern
// is blind to that particular fault.
// We don't have access to real ATPG tooling (commercial, out of scope
// for a student project) -- instead we hand-pick a few candidate fault
// sites on alu.v's internal nodes and manually check detection, which is
// exactly what stuck_at_faults.md documents conceptually.
//
// Method used here: since Verilog doesn't have a built-in "inject fault"
// primitive, we use a small modified copy of the ALU's logic inline in
// this testbench (faulty_alu function) that forces one specific internal
// signal to a fixed value, mirroring what `force` would do on a real
// signal in a live simulation, but done functionally so it works
// reliably across simulators without needing force/release commands on
// driven nets (see the console debugging earlier in this project for
// why forcing driven nets doesn't behave predictably in xsim).
// -----------------------------------------------------------------------

`timescale 1ns/1ps
module fault_tb;

    // Test patterns applied to both the golden (fault-free) ALU and each
    // faulty variant. Covers all 5 opcodes plus a couple of edge-case
    // operand values (0, all-ones) since those are more likely to expose
    // stuck-at faults that identity-like operations might otherwise hide.
    typedef struct {
        logic [3:0] a;
        logic [3:0] b;
        logic [2:0] opcode;
    } test_pattern_t;

    test_pattern_t patterns[10] = '{
        '{4'd3,  4'd2,  3'b000}, // ADD
        '{4'd15, 4'd1,  3'b000}, // ADD overflow
        '{4'd5,  4'd5,  3'b001}, // SUB -> zero
        '{4'd0,  4'd1,  3'b001}, // SUB -> borrow
        '{4'd12, 4'd10, 3'b010}, // AND
        '{4'd0,  4'd0,  3'b010}, // AND with zero
        '{4'd12, 4'd10, 3'b011}, // OR
        '{4'd15, 4'd15, 3'b011}, // OR all-ones
        '{4'd12, 4'd10, 3'b100}, // XOR
        '{4'd9,  4'd9,  3'b100}  // XOR identical -> zero
    };

    // ---------------------------------------------------------------
    // Golden (fault-free) 4-bit result, mirrors alu.v's combinational logic exactly.
    // ---------------------------------------------------------------
    function automatic [3:0] golden_result(input [3:0] a, input [3:0] b, input [2:0] op);
        case (op)
            3'b000:  golden_result = a + b;
            3'b001:  golden_result = a - b;
            3'b010:  golden_result = a & b;
            3'b011:  golden_result = a | b;
            3'b100:  golden_result = a ^ b;
            default: golden_result = 4'b0000;
        endcase
    endfunction

    // ---------------------------------------------------------------
    // Faulty result: same logic, but with a chosen internal bit forced
    // to a fixed stuck-at value AFTER computing the real result -- this
    // models the effect of that bit's driving gate being permanently
    // shorted to 0 or 1 in a real chip, regardless of what it should  have computed.
    //   fault_site : which result bit is stuck (0-3)
    //   stuck_val  : the value it's stuck at (0 or 1)
    // ---------------------------------------------------------------
    function automatic [3:0] faulty_result(input [3:0] a, input [3:0] b, input [2:0] op,
                                            input int fault_site, input bit stuck_val);
        logic [3:0] r;
        begin
            r = golden_result(a, b, op);
            r[fault_site] = stuck_val;
            faulty_result = r;
        end
    endfunction

    int total_faults    = 0;
    int detected_faults = 0;
    int log_fd;

    initial begin
        log_fd = $fopen("fault_results.log", "w");
        if (log_fd == 0) begin
            $display("WARNING: could not open fault_results.log for writing -- continuing with console output only");
        end

        $display("====================================================");
        $display("Stuck-at fault injection: result[3:0], stuck-at-0 and stuck-at-1");
        $display("====================================================");
        if (log_fd) $fwrite(log_fd, "site,stuck_at,detected\n");

        // Sweep every bit of result[3:0], both stuck-at-0 and stuck-at-1,  and check every test pattern for detection.
        for (int site = 0; site < 4; site++) begin
            for (int stuck = 0; stuck <= 1; stuck++) begin
                bit fault_detected = 0;
                total_faults++;

                for (int p = 0; p < 10; p++) begin
                    logic [3:0] good = golden_result(patterns[p].a, patterns[p].b, patterns[p].opcode);
                    logic [3:0] bad  = faulty_result(patterns[p].a, patterns[p].b, patterns[p].opcode,
                                                      site, stuck[0]);
                    if (good !== bad) begin
                        fault_detected = 1;
                        $display("  [DETECTED] result[%0d] stuck-at-%0d  <- pattern a=%0d b=%0d op=%0d (good=%0h bad=%0h)",
                                  site, stuck, patterns[p].a, patterns[p].b, patterns[p].opcode, good, bad);
                    end
                end

                if (fault_detected)
                    detected_faults++;
                else
                    $display("  [MISSED]   result[%0d] stuck-at-%0d  <- no pattern in the set detects this fault",
                              site, stuck);

                if (log_fd) $fwrite(log_fd, "%0d,%0d,%0d\n", site, stuck, fault_detected);
            end
        end

        $display("----------------------------------------------------");
        $display("Total faults modeled : %0d", total_faults);
        $display("Faults detected      : %0d", detected_faults);
        $display("Fault coverage       : %0.2f%%", (detected_faults * 100.0) / total_faults);
        $display("----------------------------------------------------");

        if (log_fd) begin
            $fwrite(log_fd, "TOTAL,%0d,%0d\n", total_faults, detected_faults);
            $fclose(log_fd);
        end
        $finish;
    end
endmodule