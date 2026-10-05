// Copyright (C) 2026 Christos Nikolaou (SV1EIA)
// Christos Nikolaou can be reached by email at : sv1eia@gmail.com
//
// =============================================================================
// Module  : ADF4001_refctl
// Purpose : PlutoSky R2 - reference controller for the ADF4001 PLL.
//
// The ADF4001 has a single MUXOUT pin (AA22, also the yellow LED). It can
// show the R divider output (REFIN pulses: tells whether a 10 MHz reference
// is connected), the digital lock detect (tells whether the loop is locked)
// or a constant level, never two of them at once. With REFIN open the
// ADF4001 input chatters at tens of MHz, so the R divider output cannot be
// left on MUXOUT: the LED would look lit. The controller therefore probes
// briefly (well under a millisecond) and parks MUXOUT on DGND in between:
//
//   IDLE    : MUXOUT = DGND (LED off), charge pump three-state, wait.
//   PROBE   : MUXOUT = R divider. Chatter or silence is rejected within
//             PROBE_BAD_N windows -> IDLE; a steady 10 MHz
//             (ADF4001_refdet.present) -> ACQUIRE, or -> IDLE with the
//             reference remembered when the loop is forced open.
//   ACQUIRE : MUXOUT = lock detect, charge pump active. Wait for lock.
//   LOCKED  : MUXOUT = lock detect, charge pump active. The LED shows lock.
//   RECHECK : lock lost (or never reached): MUXOUT back to the R divider
//             for a few windows, charge pump left active. Good count ->
//             ACQUIRE, else IDLE (or ACQUIRE again when forced closed).
//
// present (for the PS) is remembered from the last probe or recheck, so it
// is 1 while locked, 1 in IDLE after a good probe with the loop forced
// open, and 0 while the loop is forced closed without a reference.
//
// force_int keeps the loop open, force_ext keeps it closed (the stock
// firmware's behaviour). With neither set the controller is automatic.
//
// Timing parameters are in clk cycles (40 MHz: 40000 = 1 ms) so that a
// testbench can shorten them.
// =============================================================================

module ADF4001_refctl #(
    parameter [31:0] IDLE_CYC      = 32'd40_000_000,  // 1 s between probes
    parameter [31:0] ACQ_CYC       = 32'd20_000_000,  // 500 ms: lock not reached -> RECHECK
    parameter [31:0] LOCK_OK_CYC   = 32'd80_000,      // 2 ms of lock high -> LOCKED
    parameter [31:0] LOCK_LOST_CYC = 32'd320_000,     // 8 ms of lock low -> RECHECK
    parameter [3:0]  PROBE_BAD_N   = 4'd3,            // bad windows that end a probe
    parameter [3:0]  RECHECK_WIN   = 4'd3             // windows judged in RECHECK
)(
    input  wire       clk,          // 40 MHz from the VCTCXO
    input  wire       force_ext,    // EMIO o32: loop always closed
    input  wire       force_int,    // EMIO o34: loop always open
    input  wire       det_present,  // ADF4001_refdet: reference accepted (hysteresis)
    input  wire       det_window,   // ADF4001_refdet: one pulse per judged window
    input  wire       det_good,     // ADF4001_refdet: that window had a 10 MHz count
    input  wire       muxout,       // ADF4001 MUXOUT, lock detect level in ACQUIRE/LOCKED
    input  wire       cfg_applied,  // ADF4001_init has written the requested mux_sel
    output reg        cp_en    = 1'b0,   // request to ADF4001_init: charge pump active
    output reg  [1:0] mux_sel  = 2'd2,   // request to ADF4001_init: 0 R div, 1 lock, 2 DGND
    output wire       det_enable,        // detector may judge windows
    output reg        present  = 1'b0,   // reference present, as last established
    output reg        locked   = 1'b0,
    output reg  [1:0] state    = 2'd0    // 0 absent, 1 acquire, 2 locked, 3 recheck
);

    localparam [2:0] IDLE = 3'd0, PROBE = 3'd1, ACQUIRE = 3'd2, LOCKED = 3'd3, RECHECK = 3'd4;
    localparam [1:0] MUX_RDIV = 2'd0, MUX_LOCK = 2'd1, MUX_LOW = 2'd2;

    reg [2:0] st = IDLE;

    (* ASYNC_REG = "TRUE" *) reg [1:0] mux_s = 2'b00;
    always @(posedge clk) mux_s <= {mux_s[0], muxout};
    wire lock_lvl = mux_s[1];

    // the detector may only judge windows once the R divider is really on MUXOUT
    assign det_enable = (mux_sel == MUX_RDIV) & cfg_applied;

    reg [31:0] t      = 32'd0;   // time in IDLE / ACQUIRE
    reg [31:0] t_lock = 32'd0;   // lock level persistence
    reg [3:0]  win    = 4'd0;    // windows counted in PROBE / RECHECK

    always @(posedge clk) begin
        locked <= (st == LOCKED);
        case (st)
            IDLE, PROBE: state <= 2'd0;
            ACQUIRE:     state <= 2'd1;
            LOCKED:      state <= 2'd2;
            default:     state <= 2'd3;
        endcase
        case (st)
        IDLE: begin
            cp_en   <= force_ext;
            mux_sel <= MUX_LOW;
            t_lock <= 32'd0; win <= 4'd0;
            t <= t + 32'd1;
            if (force_ext)            begin st <= ACQUIRE; t <= 32'd0; end
            else if (t >= IDLE_CYC)   begin st <= PROBE;   t <= 32'd0; end
        end
        PROBE: begin
            cp_en   <= force_ext;
            mux_sel <= MUX_RDIV;
            if (force_ext) begin
                st <= ACQUIRE; t <= 32'd0;
            end else if (det_present) begin
                present <= 1'b1;
                if (force_int) begin st <= IDLE;    t <= 32'd0; end   // remembered, LED off
                else           begin st <= ACQUIRE; t <= 32'd0; end
            end else if (det_enable && det_window) begin
                if (det_good) begin
                    win <= 4'd0;                 // keep probing, hysteresis builds up
                end else begin
                    win <= win + 4'd1;
                    if (win + 4'd1 >= PROBE_BAD_N) begin
                        present <= 1'b0;
                        st <= IDLE; t <= 32'd0; win <= 4'd0;
                    end
                end
            end
        end
        ACQUIRE: begin
            cp_en   <= 1'b1;
            mux_sel <= MUX_LOCK;
            if (force_int) begin
                st <= IDLE; t <= IDLE_CYC;   // probe at once
            end else if (cfg_applied) begin
                t <= t + 32'd1;
                t_lock <= lock_lvl ? t_lock + 32'd1 : 32'd0;
                if (t_lock >= LOCK_OK_CYC) begin
                    st <= LOCKED; t <= 32'd0; t_lock <= 32'd0;
                end else if (t >= ACQ_CYC) begin
                    st <= RECHECK; t <= 32'd0; t_lock <= 32'd0; win <= 4'd0;
                end
            end
        end
        LOCKED: begin
            cp_en   <= 1'b1;
            mux_sel <= MUX_LOCK;
            present <= 1'b1;
            if (force_int) begin
                st <= IDLE; t <= IDLE_CYC;   // probe at once
            end else if (cfg_applied) begin
                t_lock <= lock_lvl ? 32'd0 : t_lock + 32'd1;
                if (t_lock >= LOCK_LOST_CYC) begin
                    st <= RECHECK; t_lock <= 32'd0; win <= 4'd0;
                end
            end
        end
        RECHECK: begin
            cp_en   <= 1'b1;         // keep the loop closed while looking
            mux_sel <= MUX_RDIV;
            if (force_int) begin
                st <= IDLE; t <= IDLE_CYC;
            end else if (det_enable && det_window) begin
                win <= win + 4'd1;
                if (det_good) begin
                    present <= 1'b1;
                    st <= ACQUIRE; t <= 32'd0;
                end else if (win + 4'd1 >= RECHECK_WIN) begin
                    present <= 1'b0;
                    if (force_ext) begin st <= ACQUIRE; t <= 32'd0; end
                    else           begin st <= IDLE;    t <= 32'd0; end
                end
            end
        end
        default: st <= IDLE;
        endcase
    end

endmodule
