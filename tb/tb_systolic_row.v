// tb_systolic_row.v -- self-checking testbench for systolic_row
//
// Per case (cases and expected values from golden/golden_cases.vh):
//   1. preload w0..w3 with 4 consecutive w_load cycles
//   2. feed x0..x3 on 4 consecutive x_valid cycles, then drive x = 0
//   3. wait for done (with timeout), compare y_out with the golden value
//
// Timing discipline:
//   - inputs are driven on the falling edge, so they are stable at the
//     next rising edge where the DUT samples them
//   - done and y_out are sampled ONLY on the falling edge (negedge clk)
//
// Checks per case (any failure -> FAIL line):
//   - y_out == golden expected value
//   - done seen exactly at the spec latency: the DUT samples x0 at edge 0
//     and raises done at edge 8, which is the 9th negedge after the negedge
//     that drove x0 (DONE_NEG = 9)
//   - done is high for exactly 1 cycle
//   - done arrives within TIMEOUT negedges, otherwise TIMEOUT error
//
// Compile from the project root:
//   iverilog -g2005 -Wall -I golden -o sim/tb_systolic_row.vvp \
//            rtl/mac_pe.v rtl/systolic_row.v tb/tb_systolic_row.v
//   vvp -n sim/tb_systolic_row.vvp [+vcd=path/to/file.vcd]
// Default VCD: sim/tb_systolic_row.vcd (relative to the run directory).
//
// Exit code: 0 when every case passes (ALL PASS); 1 when any case fails
// or the global watchdog fires (via $fatal).

`timescale 1ns / 1ps

module tb_systolic_row;

`include "golden_cases.vh"

    localparam integer CLK_PERIOD = 10;           // ns
    localparam integer DONE_NEG   = 9;            // negedges from x0 drive to done
    localparam integer TIMEOUT    = 50;           // negedges before giving up
    localparam integer GLOBAL_TO  = 20000;        // ns, whole-simulation watchdog

    // ------------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------------
    reg                    clk;
    reg                    rst_n;
    reg                    w_load;
    reg  [GOLD_DATA_W-1:0] w_in;
    reg  [GOLD_DATA_W-1:0] x_in;
    reg                    x_valid;
    wire [GOLD_ACC_W-1:0]  y_out;
    wire                   done;

    systolic_row #(
        .DATA_W (GOLD_DATA_W),
        .ACC_W  (GOLD_ACC_W)
    ) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .w_load  (w_load),
        .w_in    (w_in),
        .x_in    (x_in),
        .x_valid (x_valid),
        .y_out   (y_out),
        .done    (done)
    );

    // ------------------------------------------------------------------
    // Clock: 10 ns period, first rising edge at 5 ns
    // ------------------------------------------------------------------
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ------------------------------------------------------------------
    // VCD
    // ------------------------------------------------------------------
    reg [8*256-1:0] vcd_file;
    initial begin
        if (!$value$plusargs("vcd=%s", vcd_file))
            vcd_file = "sim/tb_systolic_row.vcd";
        $dumpfile(vcd_file);
        $dumpvars(0, tb_systolic_row);
    end

    // ------------------------------------------------------------------
    // Global watchdog: never hang, whatever happens
    // ------------------------------------------------------------------
    initial begin
        #(GLOBAL_TO);
        $display("ERROR: global timeout at %0t ns, simulation aborted", $time);
        $fatal(1, "global timeout");                  // exit code 1
    end

    // ------------------------------------------------------------------
    // Negedge sampler: advances one falling edge and samples done / y_out
    // ------------------------------------------------------------------
    integer                neg_cnt;   // negedges since the negedge that drove x0
    integer                done_at;   // neg_cnt where done was first seen (-1 = never)
    integer                done_hi;   // number of negedges with done = 1
    reg  [GOLD_ACC_W-1:0]  y_cap;     // y_out captured when done first seen

    task step;
        begin
            @(negedge clk);
            neg_cnt = neg_cnt + 1;
            if (done === 1'b1) begin
                done_hi = done_hi + 1;
                if (done_at < 0) begin
                    done_at = neg_cnt;
                    y_cap   = y_out;
                end
            end
        end
    endtask

    // ------------------------------------------------------------------
    // One test case
    // ------------------------------------------------------------------
    integer n_pass;
    integer n_fail;

    task run_case;
        input integer c;
        integer i;
        reg [GOLD_ACC_W-1:0] y_exp;
        reg                  ok;
        begin
            y_exp = GOLD_Y[c*GOLD_ACC_W +: GOLD_ACC_W];

            // 1. preload weights, one per cycle, w0 first
            for (i = 0; i < GOLD_N; i = i + 1) begin
                w_load = 1'b1;
                w_in   = GOLD_W[(c*GOLD_N + i)*GOLD_DATA_W +: GOLD_DATA_W];
                @(negedge clk);
            end
            w_load = 1'b0;
            w_in   = {GOLD_DATA_W{1'b0}};

            // 2. feed x0..x3, then 0; sample done/y_out on each negedge
            neg_cnt = 0;
            done_at = -1;
            done_hi = 0;
            for (i = 0; i < GOLD_N; i = i + 1) begin
                x_valid = 1'b1;
                x_in    = GOLD_X[(c*GOLD_N + i)*GOLD_DATA_W +: GOLD_DATA_W];
                step;
            end
            x_valid = 1'b0;
            x_in    = {GOLD_DATA_W{1'b0}};

            // 3. wait for done, bounded
            while (done_at < 0 && neg_cnt < TIMEOUT)
                step;

            if (done_at < 0) begin
                $display("FAIL case%0d: TIMEOUT, no done within %0d cycles (expected y=%0d)",
                         c, TIMEOUT, y_exp);
                n_fail = n_fail + 1;
            end else begin
                step;   // one more negedge: done must have dropped (1-cycle pulse)
                ok = (y_cap === y_exp) && (done_at == DONE_NEG) && (done_hi == 1);
                if (ok) begin
                    $display("PASS case%0d: y_out=%0d expected=%0d (done at negedge %0d, width %0d)",
                             c, y_cap, y_exp, done_at, done_hi);
                    n_pass = n_pass + 1;
                end else begin
                    $display("FAIL case%0d: y_out=%0d expected=%0d, done at negedge %0d (expected %0d), width %0d (expected 1)",
                             c, y_cap, y_exp, done_at, DONE_NEG, done_hi);
                    n_fail = n_fail + 1;
                end
            end

            // idle gap before the next case
            repeat (2) @(negedge clk);
        end
    endtask

    // ------------------------------------------------------------------
    // Main sequence
    // ------------------------------------------------------------------
    integer c;
    initial begin
        n_pass  = 0;
        n_fail  = 0;
        rst_n   = 1'b0;
        w_load  = 1'b0;
        w_in    = {GOLD_DATA_W{1'b0}};
        x_in    = {GOLD_DATA_W{1'b0}};
        x_valid = 1'b0;

        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);

        for (c = 0; c < GOLD_NCASE; c = c + 1)
            run_case(c);

        $display("----------------------------------------");
        $display("SUMMARY: %0d/%0d passed, %0d failed", n_pass, GOLD_NCASE, n_fail);
        if (n_fail == 0 && n_pass == GOLD_NCASE) begin
            $display("ALL PASS");
            $finish;                                  // exit code 0
        end else begin
            $display("SOME TESTS FAILED");
            $fatal(1, "%0d test case(s) failed", n_fail);   // exit code 1
        end
    end

endmodule
