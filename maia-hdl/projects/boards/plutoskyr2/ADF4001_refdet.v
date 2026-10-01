// =============================================================================
// Module  : ADF4001_refdet
// Purpose : PlutoSky R2 - detect the 10 MHz reference on the ADF4001 REFIN.
//
// REFIN is only wired to the ADF4001, so the PLL is programmed with MUXOUT =
// R divider output (REFIN / R, R = 1) and MUXOUT is counted here against the
// 40 MHz VCTCXO clock. The R counter runs whether or not the charge pump is
// three-stated, so the reference can be seen before the loop is closed.
//
// A window of 2^WINDOW_LOG2 clk cycles expects EXPECTED edges (10 MHz pulses)
// or EXPECTED/2 (if MUXOUT toggles at REFIN/2R). An absent input chatters at
// tens of MHz (the ADF4001 input is open) and gives a random count. present
// rises after GOOD_N good windows in a row and falls after BAD_N bad windows
// in a row. Windows are short (102.4 us) because MUXOUT also drives the
// yellow LED: a probe of a chattering input must stay far below the eye's
// flash threshold.
//
// enable is low while MUXOUT does not carry the R divider output (see
// ADF4001_refctl): present is then cleared together with the hysteresis
// counters, count keeps its last value, and the first window after enable
// returns is skipped because it is partial. window pulses once per judged
// window, with good telling whether that window had a 10 MHz count.
// =============================================================================
// Modified by Christos Nikolaou (SV1EIA) 2026.
// Christos Nikolaou can be reached by email at : sv1eia@gmail.com

module ADF4001_refdet #(
    parameter        WINDOW_LOG2 = 12,          // 102.4 us at 40 MHz
    parameter [15:0] EXPECTED    = 16'd1024,    // 10 MHz * 2^12 / 40 MHz
    parameter [15:0] TOL         = 16'd4,       // +-0.4 %
    parameter [5:0]  GOOD_N      = 6'd32,       // ~3.3 ms to declare present
    parameter [5:0]  BAD_N       = 6'd8,        // ~0.8 ms to declare absent
    parameter        ACCEPT_HALF = 0            // 1: also accept EXPECTED/2 (REFIN/2R)
)(
    input  wire        clk,         // 40 MHz from the VCTCXO
    input  wire        muxout,      // ADF4001 MUXOUT
    input  wire        enable,      // MUXOUT carries the R divider output
    output reg         present = 1'b0,
    output reg  [15:0] count   = 16'd0,  // edges in the last window
    output reg         window  = 1'b0,   // pulse: a window was judged
    output reg         good    = 1'b0    // with window: that window was 10 MHz
);

    // Edge counter clocked by MUXOUT, gray coded for the crossing to clk
    reg [15:0] mux_bin  = 16'd0;
    reg [15:0] mux_gray = 16'd0;

    always @(posedge muxout) begin
        mux_bin  <= mux_bin + 16'd1;
        mux_gray <= mux_bin ^ (mux_bin >> 1);
    end

    (* ASYNC_REG = "TRUE" *) reg [15:0] gray_s1 = 16'd0;
    (* ASYNC_REG = "TRUE" *) reg [15:0] gray_s2 = 16'd0;

    always @(posedge clk) begin
        gray_s1 <= mux_gray;
        gray_s2 <= gray_s1;
    end

    function [15:0] gray2bin;
        input [15:0] g;
        integer i;
        begin
            gray2bin[15] = g[15];
            for (i = 14; i >= 0; i = i - 1)
                gray2bin[i] = gray2bin[i + 1] ^ g[i];
        end
    endfunction

    reg  [WINDOW_LOG2-1:0] tick = 0;
    reg  [15:0]            last = 16'd0;
    reg  [5:0]             ngood = 6'd0;
    reg  [5:0]             bad  = 6'd0;
    reg                    skip = 1'b1;   // first window after enable is partial

    wire [15:0] now   = gray2bin(gray_s2);
    wire [15:0] delta = now - last;
    wire        full  = (delta >= EXPECTED - TOL) && (delta <= EXPECTED + TOL);
    wire        half  = (delta >= (EXPECTED >> 1) - (TOL >> 1)) &&
                        (delta <= (EXPECTED >> 1) + (TOL >> 1));

    always @(posedge clk) begin
        tick   <= tick + 1'b1;
        window <= 1'b0;
        if (&tick) begin
            last  <= now;
            if (!enable) begin
                present <= 1'b0;
                ngood   <= 6'd0;
                bad     <= 6'd0;
                skip    <= 1'b1;
            end else if (skip) begin
                skip    <= 1'b0;
            end else begin
            count  <= delta;
            window <= 1'b1;
            good   <= full || (ACCEPT_HALF && half);
            if (full || (ACCEPT_HALF && half)) begin
                bad <= 6'd0;
                if (ngood == GOOD_N)
                    present <= 1'b1;
                else
                    ngood <= ngood + 6'd1;
            end else begin
                ngood <= 6'd0;
                if (bad == BAD_N)
                    present <= 1'b0;
                else
                    bad <= bad + 6'd1;
            end
            end
        end
    end

endmodule
