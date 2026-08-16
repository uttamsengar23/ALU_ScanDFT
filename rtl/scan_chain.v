// scan_chain.v
// -----------------------------------------------------------------------------
// Parameterized scan-chain module for DFT.
//
// This module instantiates multiple scan flip-flops and connects them in
// series to form a single scan path.
//
// Functional mode:
//   Each scan flip-flop receives its normal functional input d[i] and behaves
//   like an ordinary flip-flop.
//
// Scan mode:
//   The flip-flops are connected serially:
//
//       scan_in → FF0 → FF1 → FF2 → ... → FF(N-1) → scan_out
//
//   The Q output of each flip-flop becomes the scan_in of the next flip-flop.
//   This allows internal sequential state to be shifted into and out of the
//   design for DFT testing.
//
// WIDTH:
//   Number of scan flip-flops in the chain.
//
//   For the ALU_DFT project:
//       result[3:0] = 4 bits
//       zero        = 1 bit
//       carry       = 1 bit
//       negative    = 1 bit
//
//   Total = 7 scan flip-flops.
//
// IMPORTANT:
//   scan_chain.v only creates and connects the scan structure.
//   It does not generate the functional data. The normal functional inputs
//   d[i] are supplied by the module that integrates this chain, such as
//   alu_scan.v.
// -----------------------------------------------------------------------------

module scan_chain #(
    parameter WIDTH = 9
) (
    input                    clk,
    input                    rst,
    input                    scan_enable,
    input      [WIDTH-1:0]   d,          // Normal functional input for each scan FF
    input                    scan_in,    // External serial test input; feeds the first FF
    output     [WIDTH-1:0]   q,          // Parallel Q outputs from all scan FFs
    output                   scan_out    // Serial test output from the last FF
);

    // -------------------------------------------------------------------------
    // chain_q contains the Q output of every scan flip-flop.
    //
    // chain_q[i] is the Q output of flip-flop i.
    //
    // These signals serve two purposes:
    //   1. They form the parallel output bus q.
    //   2. Each Q output feeds the scan input of the next flip-flop.
    //
    // Example:
    //   chain_q[0] → FF1.scan_in
    //   chain_q[1] → FF2.scan_in
    //   chain_q[2] → FF3.scan_in
    // -------------------------------------------------------------------------
    wire [WIDTH-1:0] chain_q;

    // genvar is used to generate multiple identical scan_ff instances.
    // The loop below creates WIDTH scan flip-flops.
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : scan_ff_gen

            // Determine the scan input for the current flip-flop.
            //
            // For the first flip-flop (i == 0):
            //   External scan_in directly feeds FF0.
            //
            // For every subsequent flip-flop:
            //   The previous flip-flop's Q output feeds its scan input.
            //
            // Therefore the complete scan path becomes:
            //
            //   scan_in → FF0 → FF1 → FF2 → ... → FF(N-1) → scan_out
            //
            wire flop_scan_in = (i == 0) ? scan_in : chain_q[i-1];

            // Instantiate one scan-capable flip-flop.
            //
            // d[i]          → normal functional data
            // flop_scan_in  → serial scan data
            // chain_q[i]    → Q output of this flip-flop
            //
            // scan_enable inside scan_ff determines whether the flip-flop
            // uses the normal functional input or the serial scan input.
            scan_ff u_scan_ff (
                .clk         (clk),
                .rst         (rst),
                .scan_enable (scan_enable),
                .d           (d[i]),
                .scan_in     (flop_scan_in),
                .q           (chain_q[i])
            );
        end
    endgenerate

    // Expose the Q outputs of all scan flip-flops as a parallel output bus.
    // This allows the integrating design to observe the complete registered
    // state of the scan chain.
    assign q = chain_q;

    // The Q output of the final scan flip-flop becomes the external Scan-Out.
    //
    // During scan shifting:
    //   scan_in → FF0 → FF1 → ... → FF(N-1) → scan_out
    assign scan_out = chain_q[WIDTH-1];

endmodule