// mac_pe.v -- weight-stationary MAC processing element
//
// Behaviour (see docs/spec.md, scheme A):
//   - w_load = 1 at a clock edge: weight register <= w_in
//   - every clock edge:
//       x_out    <= x_in                       (x chain: 1 register / PE)
//       psum_mid <= psum_in + x_in * weight    (psum stage 1)
//       psum_out <= psum_mid                   (psum stage 2)
//     i.e. psum_out = psum_in + x_in * weight, delayed by 2 cycles.
//     The psum chain has 2 registers per PE, so partial sums move at half
//     the speed of x and x can be fed in natural order x0, x1, x2, x3.
//   - rst_n = 0 (async, active low): all registers cleared to 0
//
// All arithmetic is unsigned. The product is 2*DATA_W bits and is
// zero-extended to ACC_W before the add. Requires ACC_W >= 2*DATA_W.

`timescale 1ns / 1ps

module mac_pe #(
    parameter DATA_W = 8,
    parameter ACC_W  = 24
) (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              w_load,
    input  wire [DATA_W-1:0] w_in,
    input  wire [DATA_W-1:0] x_in,
    input  wire [ACC_W-1:0]  psum_in,
    output reg  [DATA_W-1:0] x_out,
    output reg  [ACC_W-1:0]  psum_out
);

    reg  [DATA_W-1:0]   w_reg;
    reg  [ACC_W-1:0]    psum_mid;
    wire [2*DATA_W-1:0] prod = x_in * w_reg;

    // Weight register: written only when w_load is high
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            w_reg <= {DATA_W{1'b0}};
        else if (w_load)
            w_reg <= w_in;
    end

    // x forwarding and two-stage multiply-accumulate, updated every edge
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_out    <= {DATA_W{1'b0}};
            psum_mid <= {ACC_W{1'b0}};
            psum_out <= {ACC_W{1'b0}};
        end else begin
            x_out    <= x_in;
            psum_mid <= psum_in + prod;
            psum_out <= psum_mid;
        end
    end

endmodule
