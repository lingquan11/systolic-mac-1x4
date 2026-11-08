// systolic_row.v -- 1x4 weight-stationary systolic row, y = W . x
//
// See docs/spec.md. Summary of external behaviour:
//   - Weight preload: each cycle with w_load = 1 writes w_in into the next
//     PE (PE0, PE1, PE2, PE3, then wraps). Load order is w0..w3.
//   - Compute: x_valid = 1 for 4 consecutive cycles with x_in = x0..x3.
//     Taking the edge that samples x0 as edge 0, y_out and done are both
//     updated at edge 8; done is high for exactly 1 cycle and y_out holds
//     the result until the next done.
//   - rst_n = 0 (async, active low): all registers cleared to 0.
//
// Structure:
//   - x chain:    PE_j.x_in   = PE_(j-1).x_out, PE0.x_in = gated x_in
//   - psum chain: PE_j.psum_in = PE_(j-1).psum_out, PE0.psum_in = 0
//   - PE3.psum_out holds the full sum after edge 2*N-1 = 7.
//   - done: a valid flag marks the edge that samples x0 (rising edge of
//     x_valid) and is delayed through a 2*N-bit shift register; done and
//     y_out are registered when it reaches the end (edge 2*N = 8).
//     Groups are separated by idle cycles (next x0 at edge >= 9), so the
//     rising edge of x_valid identifies x0 uniquely.

`timescale 1ns / 1ps

module systolic_row #(
    parameter DATA_W = 8,
    parameter ACC_W  = 24
) (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              w_load,
    input  wire [DATA_W-1:0] w_in,
    input  wire [DATA_W-1:0] x_in,
    input  wire              x_valid,
    output reg  [ACC_W-1:0]  y_out,
    output reg               done
);

    localparam N   = 4;       // number of PEs
    localparam LAT = 2 * N;   // edges from x0 sample to done (= 8)

    // ------------------------------------------------------------------
    // Weight load counter: selects which PE takes w_in on w_load
    // ------------------------------------------------------------------
    reg  [1:0]   w_cnt;
    wire [N-1:0] pe_w_load;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            w_cnt <= 2'd0;
        else if (w_load)
            w_cnt <= w_cnt + 2'd1;   // wraps 3 -> 0
    end

    // ------------------------------------------------------------------
    // x_valid gating into PE0
    // ------------------------------------------------------------------
    wire [DATA_W-1:0] x_gated = x_valid ? x_in : {DATA_W{1'b0}};

    // ------------------------------------------------------------------
    // PE chain
    //   x_bus[j]    : x into PE_j   (x_bus[N] = PE3.x_out, unused)
    //   psum_bus[j] : psum into PE_j (psum_bus[N] = PE3.psum_out)
    // ------------------------------------------------------------------
    wire [(N+1)*DATA_W-1:0] x_bus;
    wire [(N+1)*ACC_W-1:0]  psum_bus;

    assign x_bus[0 +: DATA_W]   = x_gated;
    assign psum_bus[0 +: ACC_W] = {ACC_W{1'b0}};

    genvar j;
    generate
        for (j = 0; j < N; j = j + 1) begin : g_pe
            assign pe_w_load[j] = w_load && (w_cnt == j);

            mac_pe #(
                .DATA_W (DATA_W),
                .ACC_W  (ACC_W)
            ) u_pe (
                .clk      (clk),
                .rst_n    (rst_n),
                .w_load   (pe_w_load[j]),
                .w_in     (w_in),
                .x_in     (x_bus[j*DATA_W +: DATA_W]),
                .psum_in  (psum_bus[j*ACC_W +: ACC_W]),
                .x_out    (x_bus[(j+1)*DATA_W +: DATA_W]),
                .psum_out (psum_bus[(j+1)*ACC_W +: ACC_W])
            );
        end
    endgenerate

    wire [ACC_W-1:0] psum_final = psum_bus[N*ACC_W +: ACC_W];

    // ------------------------------------------------------------------
    // done logic: mark x0 (rising edge of x_valid), delay LAT edges
    // ------------------------------------------------------------------
    reg            x_valid_d;
    reg  [LAT-1:0] vld_sr;    // vld_sr[k] = 1 after edge k of a group
    wire           x0_start = x_valid & ~x_valid_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_valid_d <= 1'b0;
            vld_sr    <= {LAT{1'b0}};
        end else begin
            x_valid_d <= x_valid;
            vld_sr    <= {vld_sr[LAT-2:0], x0_start};
        end
    end

    // ------------------------------------------------------------------
    // Output registers: done pulse and y_out hold register (edge 8)
    // ------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done  <= 1'b0;
            y_out <= {ACC_W{1'b0}};
        end else begin
            done <= vld_sr[LAT-1];
            if (vld_sr[LAT-1])
                y_out <= psum_final;
        end
    end

endmodule
