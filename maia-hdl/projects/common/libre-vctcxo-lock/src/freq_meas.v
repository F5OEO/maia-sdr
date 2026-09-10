//
// Frequency Measurement
//
// Counts VCTCXO edges relative to an external reference, using clk (an
// INDEPENDENT, PS-derived clock - NOT derived from the VCTCXO being
// measured) as the timebase.
//
// This is the key architectural difference from the earlier antsdr-hdl-
// derived b205_ref_pll.v design: there, the sample clock used to judge
// reference/VCTCXO quality was itself PLL-derived from the VCTCXO under
// discipline, so the measurement and the thing being measured shared
// noise - the root cause of a whole class of bugs found and worked
// around over many iterations (a bootstrap deadlock, a long-window
// tolerance that had to be loosened past its own statistical noise
// floor, a lock-detection threshold that could never sustain). Using an
// independent clock here avoids that coupling entirely rather than
// tuning around it.
//
// Modeled on ocpi.osp.libresdr's freq_meas.vhd (ref-clk-support-2
// branch), ported to Verilog for this ADI-style IP. Logic is a faithful
// port; see pi_ctrl.v for one deliberate addition (integrator
// anti-windup) beyond the reference.
//
// Mode "00" (none)  : no measurement; error_valid never pulses
// Mode "01" (pps)   : count VCTCXO edges between 1PPS rising edges;
//                     error = count - CLK_HZ  (negative = slow, positive = fast)
// Mode "10" (mhz10) : count VCTCXO edges over MEAS_CYCLES 10 MHz ref periods;
//                     error = count - (CLK_HZ/10MHz)*MEAS_CYCLES
//
// First measurement after mode change or init is discarded (partial window).
//
// ref_present goes high when reference edges arrive, times out (a
// saturating counter that resets on every ref edge) when they stop -
// debounced against a single missed edge by design, not reactive to it.
//
`timescale 1ns / 1ps

module freq_meas #(
    parameter integer CLK_HZ      = 40_000_000, // VCTCXO frequency being measured
    parameter integer MEAS_CYCLES = 1_000_000,  // 10 MHz ref periods per window (100 ms)
    parameter integer COUNT_W     = 32          // error output width (signed)
)(
    input  wire                       clk,          // independent measurement clock (PS-derived)
    input  wire                       init,
    input  wire [1:0]                 mode,         // 00=none 01=pps 10=mhz10
    input  wire                       vctcxo_40mhz, // raw async VCTCXO output
    input  wire                       ref_10mhz,    // raw async 10 MHz reference input
    input  wire                       ref_1pps,     // raw async 1 PPS input
    output wire                       ref_present,
    output reg  signed [COUNT_W-1:0]  error_out,
    output reg                        error_valid
);

    localparam signed [COUNT_W-1:0] EXP_10MHZ = (CLK_HZ / 10_000_000) * MEAS_CYCLES;
    localparam signed [COUNT_W-1:0] EXP_1PPS  = CLK_HZ;

    // ------------------------------------------------------------------
    // 2-FF synchronisers (all async inputs into clk domain)
    // ------------------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) reg [1:0] svco_ff = 2'b00;
    (* ASYNC_REG = "TRUE" *) reg [1:0] s10_ff  = 2'b00;
    (* ASYNC_REG = "TRUE" *) reg [1:0] spps_ff = 2'b00;
    reg svco_r = 1'b0;
    reg s10_r  = 1'b0;
    reg spps_r = 1'b0;

    wire rise_vco = svco_ff[1] & ~svco_r;
    wire rise_10  = s10_ff[1]  & ~s10_r;
    wire rise_pps = spps_ff[1] & ~spps_r;

    // ------------------------------------------------------------------
    // 10 MHz mode: count VCTCXO edges within MEAS_CYCLES ref periods
    // ------------------------------------------------------------------
    reg [25:0] cnt_10   = 26'd0; // 40M max (CLK_HZ/10MHz * MEAS_CYCLES) -> fits comfortably
    reg [23:0] ref_cnt  = 24'd0; // MEAS_CYCLES max (up to 10M -> needs 24 bits)
    reg        first_10 = 1'b1;
    reg [7:0]  pres_10  = 8'hFF; // presence timeout

    // ------------------------------------------------------------------
    // 1PPS mode: count VCTCXO edges between PPS edges
    // ------------------------------------------------------------------
    reg [25:0] cnt_pps    = 26'd0; // 40M max -> fits
    reg        first_pps  = 1'b1;
    reg [26:0] pres_pps   = 27'h7FFFFFF; // ~1.34s timeout @ 100 MHz clk

    reg pres_i = 1'b0;
    assign ref_present = pres_i;

    always @(posedge clk) begin
        // Synchroniser chains
        svco_ff <= {svco_ff[0], vctcxo_40mhz};
        s10_ff  <= {s10_ff[0],  ref_10mhz};
        spps_ff <= {spps_ff[0], ref_1pps};
        svco_r  <= svco_ff[1];
        s10_r   <= s10_ff[1];
        spps_r  <= spps_ff[1];

        error_valid <= 1'b0;

        if (init) begin
            cnt_10    <= 26'd0;
            cnt_pps   <= 26'd0;
            ref_cnt   <= 24'd0;
            first_10  <= 1'b1;
            first_pps <= 1'b1;
            pres_10   <= 8'hFF;
            pres_pps  <= 27'h7FFFFFF;
            pres_i    <= 1'b0;
            error_out <= {COUNT_W{1'b0}};
        end
        else begin
            case (mode)

                // ---------------------------------------------------------
                2'b10: begin // 10 MHz reference mode
                // ---------------------------------------------------------
                    // Count VCTCXO edges
                    if (rise_vco)
                        cnt_10 <= cnt_10 + 1'b1;

                    // Presence: saturating counter, resets on each ref edge
                    if (rise_10) begin
                        pres_10 <= 8'd0;
                        pres_i  <= 1'b1;
                    end
                    else if (~pres_10[7]) begin
                        pres_10 <= pres_10 + 1'b1;
                    end
                    else begin
                        pres_i <= 1'b0;
                    end

                    // Gate: one measurement window per MEAS_CYCLES ref periods
                    if (rise_10) begin
                        if (first_10) begin
                            first_10 <= 1'b0;
                            cnt_10   <= 26'd0;
                            ref_cnt  <= 24'd0;
                        end
                        else if (ref_cnt == MEAS_CYCLES - 1) begin
                            error_out   <= $signed({1'b0, cnt_10}) - EXP_10MHZ;
                            error_valid <= 1'b1;
                            cnt_10      <= 26'd0;
                            ref_cnt     <= 24'd0;
                        end
                        else begin
                            ref_cnt <= ref_cnt + 1'b1;
                        end
                    end
                end

                // ---------------------------------------------------------
                2'b01: begin // 1 PPS reference mode
                // ---------------------------------------------------------
                    // Count VCTCXO edges
                    if (rise_vco)
                        cnt_pps <= cnt_pps + 1'b1;

                    // Presence: saturating counter
                    if (rise_pps) begin
                        pres_pps <= 27'd0;
                        pres_i   <= 1'b1;
                    end
                    else if (~pres_pps[26]) begin
                        pres_pps <= pres_pps + 1'b1;
                    end
                    else begin
                        pres_i <= 1'b0;
                    end

                    if (rise_pps) begin
                        if (first_pps) begin
                            first_pps <= 1'b0;
                            cnt_pps   <= 26'd0;
                        end
                        else begin
                            error_out   <= $signed({1'b0, cnt_pps}) - EXP_1PPS;
                            error_valid <= 1'b1;
                            cnt_pps     <= 26'd0;
                        end
                    end
                end

                // ---------------------------------------------------------
                default: begin // none: reset state, hold outputs
                // ---------------------------------------------------------
                    cnt_10    <= 26'd0;
                    cnt_pps   <= 26'd0;
                    ref_cnt   <= 24'd0;
                    first_10  <= 1'b1;
                    first_pps <= 1'b1;
                    pres_i    <= 1'b0;
                end

            endcase
        end
    end

endmodule
