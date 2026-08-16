// scan_ff.v
// -----------------------------------------------------------------------
// Single scan-capable flip-flop -- the basic building block of scan-based
// DFT. This one flop replaces a plain D flip-flop anywhere we want the
// internal state to be controllable/observable from outside the chip.
//
// Two modes, selected by scan_enable:
//   scan_enable = 0 (functional mode) -> Q captures D on posedge clk,
//                                         same as a normal flip-flop.
//   scan_enable = 1 (scan mode)       -> Q captures scan_in on posedge
//                                         clk instead of D. Chaining many
//                                         of these together (scan_out of
//                                         one -> scan_in of the next)
//                                         forms a shift register that
//                                         lets you shift a known pattern
//                                         IN and shift the captured
//                                         result OUT, without needing
//                                         separate physical access to
//                                         every internal flop.
//
// scan_out is just Q, exposed under its own name for clarity when wiring
// up scan_chain.v -- it's always equal to Q, in both modes.
// -----------------------------------------------------------------------

module scan_ff (
    input  clk,
    input  rst,          // synchronous active-high reset (functional reset)
    input  scan_enable,  // 1 = scan/shift mode, 0 = normal functional mode
    input  d,            // functional data input
    input  scan_in,       // scan chain data input (previous flop's scan_out)
    output reg q,         // functional / captured output
    output     scan_out   // == q, named separately for chain wiring clarity
);

    always @(posedge clk) begin
        if (rst)
            q <= 1'b0;
        else if (scan_enable)
            q <= scan_in;   // shift mode: take data from the chain
        else
            q <= d;         // functional mode: normal flip-flop behavior
    end

    assign scan_out = q;

endmodule