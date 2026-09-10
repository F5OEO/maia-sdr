`timescale 1 ns / 1 ps
//
// VCTCXO Discipline Loop, independent-clock architecture
//
// Disciplines the libre board's VCTCXO via a DAC5311/DAC6311/DAC7311
// using either the CLKIN_10MHz or a 1PPS (PPS_IN/PPS_GPS) external
// reference. Modeled on ocpi.osp.libresdr's vctcxo_lock.vhd
// (ref-clk-support-2 branch): frequency is measured by counting VCTCXO
// edges against s00_axi_aclk (the PS-derived AXI clock, independent of
// the VCTCXO being disciplined) rather than a PLL-derived clock, and
// corrected with a PI controller instead of a bare proportional term
// with an ad-hoc dead-band. See freq_meas.v and pi_ctrl.v for why.
//
// External port names match projects/common/antsdr-hdl/axi_vcxo_ctrl's
// axi_vcxo_ctrl_v1_0 so this is a drop-in replacement in a board's
// vcxo_ctrl.tcl (same ad_connect calls).
//
module vctcxo_lock #
(
    parameter DEVICE = "DAC5311",

    parameter integer C_S00_AXI_DATA_WIDTH = 32,
    parameter integer C_S00_AXI_ADDR_WIDTH = 6
)
(
    input  wire             CLK_40MHz_FPGA,   // raw async VCTCXO output
    input  wire             PPS_IN,
    input  wire             CLKIN_10MHz,
    input  wire             PPS_GPS,
    output wire             PPS_LED,
    output wire             PPS_LOCKED,
    output wire             REF_10M_LOCKED,
    output wire             CLK_40M_DAC_nSYNC,
    output wire             CLK_40M_DAC_SCLK,
    output wire             CLK_40M_DAC_DIN,
    output wire [31:0]      NCO_RX_FTW,
    output wire [31:0]      NCO_TX_FTW,
    output wire [3:0]       NCO_CONTROL,

    // Ports of Axi Slave Bus Interface S00_AXI
    input wire  s00_axi_aclk,
    input wire  s00_axi_aresetn,
    input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
    input wire [2 : 0] s00_axi_awprot,
    input wire  s00_axi_awvalid,
    output wire  s00_axi_awready,
    input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
    input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
    input wire  s00_axi_wvalid,
    output wire  s00_axi_wready,
    output wire [1 : 0] s00_axi_bresp,
    output wire  s00_axi_bvalid,
    input wire  s00_axi_bready,
    input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
    input wire [2 : 0] s00_axi_arprot,
    input wire  s00_axi_arvalid,
    output wire  s00_axi_arready,
    output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
    output wire [1 : 0] s00_axi_rresp,
    output wire  s00_axi_rvalid,
    input wire  s00_axi_rready
);

    wire clk  = s00_axi_aclk;
    wire init = ~s00_axi_aresetn;

    // -------------------------------------------------------------------
    // AXI-Lite register file
    // -------------------------------------------------------------------
    wire        dac_mode;
    wire [15:0] dac_user_set_value;
    wire [15:0] center_dac;
    wire [15:0] dac_dyn_value;
    wire [1:0]  dac_ref_sel;
    wire        dac_dither_dis;
    wire [7:0]  p_shift;
    wire [7:0]  i_shift;
    wire [31:0] lock_thresh;
    wire        locked;
    wire        ref_present;
    wire [31:0] freq_error;

    vctcxo_lock_v1_0_S00_AXI # (
        .C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
    ) axi_inst (
        .dac_mode(dac_mode),
        .dac_user_set_value(dac_user_set_value),
        .center_dac(center_dac),
        .dac_dyn_value(dac_dyn_value),
        .dac_ref_sel(dac_ref_sel),
        .dac_dither_dis(dac_dither_dis),
        .p_shift(p_shift),
        .i_shift(i_shift),
        .lock_thresh(lock_thresh),
        .locked(locked),
        .ref_present(ref_present),
        .freq_error(freq_error),
        .nco_rx_ftw(NCO_RX_FTW),
        .nco_tx_ftw(NCO_TX_FTW),
        .nco_control(NCO_CONTROL),
        .S_AXI_ACLK(s00_axi_aclk),
        .S_AXI_ARESETN(s00_axi_aresetn),
        .S_AXI_AWADDR(s00_axi_awaddr),
        .S_AXI_AWPROT(s00_axi_awprot),
        .S_AXI_AWVALID(s00_axi_awvalid),
        .S_AXI_AWREADY(s00_axi_awready),
        .S_AXI_WDATA(s00_axi_wdata),
        .S_AXI_WSTRB(s00_axi_wstrb),
        .S_AXI_WVALID(s00_axi_wvalid),
        .S_AXI_WREADY(s00_axi_wready),
        .S_AXI_BRESP(s00_axi_bresp),
        .S_AXI_BVALID(s00_axi_bvalid),
        .S_AXI_BREADY(s00_axi_bready),
        .S_AXI_ARADDR(s00_axi_araddr),
        .S_AXI_ARPROT(s00_axi_arprot),
        .S_AXI_ARVALID(s00_axi_arvalid),
        .S_AXI_ARREADY(s00_axi_arready),
        .S_AXI_RDATA(s00_axi_rdata),
        .S_AXI_RRESP(s00_axi_rresp),
        .S_AXI_RVALID(s00_axi_rvalid),
        .S_AXI_RREADY(s00_axi_rready)
    );

    // -------------------------------------------------------------------
    // Reference source select -> freq_meas mode + which raw pin feeds it
    // -------------------------------------------------------------------
    // dac_ref_sel keeps the same encoding as the earlier b205_ref_pll.v
    // design: 00=CLKIN_10MHz, 01=PPS_IN, 10=PPS_GPS, 11=none. Unlike that
    // design, this one doesn't auto-classify which physical signal looks
    // like a 10 MHz reference vs. a PPS - the mode is derived directly
    // from which pin is selected, since PPS_IN and PPS_GPS are both
    // 1PPS-style signals from freq_meas's point of view.
    wire [1:0] meas_mode = (dac_ref_sel == 2'b00) ? 2'b10 :  // mhz10
                           (dac_ref_sel == 2'b01) ? 2'b01 :  // pps (PPS_IN)
                           (dac_ref_sel == 2'b10) ? 2'b01 :  // pps (PPS_GPS)
                                                    2'b00;   // none

    wire ref_10mhz_sig = (dac_ref_sel == 2'b00) ? CLKIN_10MHz : 1'b0;
    wire ref_1pps_sig  = (dac_ref_sel == 2'b01) ? PPS_IN :
                          (dac_ref_sel == 2'b10) ? PPS_GPS : 1'b0;

    assign PPS_LED = PPS_GPS;

    // -------------------------------------------------------------------
    // Frequency measurement (independent clock - see freq_meas.v)
    // -------------------------------------------------------------------
    // MEAS_CYCLES=10_000_000 (1 s window in 10 MHz mode) rather than the
    // faithful-port default of 1_000_000 (100 ms): at 100 ms, each
    // freq_error count already represents 0.25 ppm (EXP_10MHZ=4,000,000
    // expected edges per window) - too coarse a measurement resolution
    // to see, let alone hold, sub-0.1 ppm error. At 1 s, resolution is
    // 0.025 ppm/count (EXP_10MHZ=40,000,000), well under that target,
    // at the cost of a 10x slower correction rate (once/second instead
    // of once/100ms - acceptable, this loop was already tuned to be
    // gentle over many windows, see vctcxo_lock.md).
    wire signed [31:0] meas_error;
    wire                meas_error_valid;

    freq_meas #(
        .CLK_HZ(40_000_000),
        .MEAS_CYCLES(10_000_000),
        .COUNT_W(32)
    ) u_freq_meas (
        .clk(clk),
        .init(init),
        .mode(meas_mode),
        .vctcxo_40mhz(CLK_40MHz_FPGA),
        .ref_10mhz(ref_10mhz_sig),
        .ref_1pps(ref_1pps_sig),
        .ref_present(ref_present),
        .error_out(meas_error),
        .error_valid(meas_error_valid)
    );

    // -------------------------------------------------------------------
    // PI controller
    // -------------------------------------------------------------------
    // Freeze (hold last correction, don't reset to center_dac) whenever
    // there's no reference selected or the selected reference's edges
    // have stopped arriving - see freq_meas.v's ref_present. This avoids
    // the physical frequency glitch the earlier b205_ref_pll.v design
    // had on every reference dropout (forced reset to a coarse default).
    wire freeze = (meas_mode == 2'b00) || ~ref_present;

    wire signed [15:0] correction;
    wire                corr_valid;

    pi_ctrl #(
        .ERROR_W(32),
        .ACC_W(48),
        .SHIFT_W(8),
        .SHIFT_MID(128),
        .OUTPUT_W(16)
    ) u_pi_ctrl (
        .clk(clk),
        .init(init),
        .freeze(freeze),
        .error_in(meas_error),
        .valid(meas_error_valid),
        .p_shift(p_shift),
        .i_shift(i_shift),
        .ctrl_out(correction),
        .valid_out(corr_valid)
    );

    // -------------------------------------------------------------------
    // DAC value: center_dac - correction, clamped to [0, 65535]
    //
    // pi_ctrl.v produces correction with the same sign as error_in (a
    // faithful port of the reference, which assumes dErr/dDac < 0 on its
    // own hardware). Measured on this board via an open-loop DAC sweep
    // (dac_mode=1, PI output disconnected): error_out is monotonically
    // INCREASING in dac across the whole usable range (dac=0x1000 ->
    // err=-26, 0x2800 -> err=-3, 0x8000 -> err=+27), i.e. dErr/dDac > 0
    // here - the opposite polarity. Adding correction directly therefore
    // gives positive feedback (diverges, or relies on saturation to
    // produce a limit cycle) instead of closed-loop convergence. The
    // polarity is a board integration property (DAC/VCTCXO wiring), not
    // a pi_ctrl bug, so the inversion belongs here rather than in
    // pi_ctrl.v's error path (which would also need re-verifying its
    // anti-windup sign-flip logic against the testbench).
    // -------------------------------------------------------------------
    wire signed [16:0] dac_raw = {1'b0, center_dac} - {{1{correction[15]}}, correction};
    wire [15:0] dac_value = dac_raw[16]           ? (dac_raw[15] ? 16'h0000 : 16'hFFFF) :
                             (dac_raw > 17'sd65535) ? 16'hFFFF :
                                                       dac_raw[15:0];

    wire [15:0] dac_final = dac_mode ? dac_user_set_value : dac_value;
    assign dac_dyn_value = dac_final;

    // -------------------------------------------------------------------
    // Lock detection: reference present and last measured error within
    // lock_thresh. Continuously re-evaluated against the latest
    // meas_error/ref_present rather than a separate shift-register-based
    // history - each window's measurement is already an average over
    // MEAS_CYCLES periods (100 ms for the 10 MHz path), unlike the
    // earlier design's single-PFD-comparison-per-check approach.
    // -------------------------------------------------------------------
    wire [31:0] error_abs = meas_error[31] ? (~meas_error + 1'b1) : meas_error;
    assign locked = ref_present & (error_abs <= lock_thresh);
    assign freq_error = meas_error;

    assign REF_10M_LOCKED = locked & (meas_mode == 2'b10);
    assign PPS_LOCKED     = locked & (meas_mode == 2'b01);

    // -------------------------------------------------------------------
    // DACx311 dither (DAC5311/DAC6311/DAC7311 - same design as the
    // earlier b205_ref_pll.v: split dac_final at the DAC's native
    // resolution, first-order delta-sigma dither the remaining low bits.
    // Dither tick divider is unchanged (12 bits) but clk is now 100 MHz
    // (s00_axi_aclk) instead of 200 MHz, so the tick rate is ~24.4 kHz
    // instead of ~48.8 kHz - still well above typical tune-line RC
    // filter corner frequencies.
    // -------------------------------------------------------------------
    localparam integer DAC311_BITS = (DEVICE=="DAC7311") ? 12 :
                                      (DEVICE=="DAC6311") ? 10 : 8; // DAC5311 default
    localparam integer DAC311_FRAC_BITS = 16 - DAC311_BITS;
    localparam DITHER_DIV_BITS = 12;

    reg [DITHER_DIV_BITS-1:0] dither_div_cnt;
    wire dither_tick = &dither_div_cnt;
    reg [DAC311_FRAC_BITS-1:0] dither_acc;
    reg       dither_bit;
    reg [DAC311_BITS-1:0] dac311_base;

    always @(posedge clk) begin
        if (init) begin
            dither_div_cnt <= {DITHER_DIV_BITS{1'b0}};
            dither_acc     <= {DAC311_FRAC_BITS{1'b0}};
            dither_bit     <= 1'b0;
            dac311_base    <= {DAC311_BITS{1'b0}};
        end
        else begin
            dither_div_cnt <= dither_div_cnt + 1'b1;
            if (dither_tick) begin
                {dither_bit, dither_acc} <= {1'b0, dither_acc} + {1'b0, dac_final[DAC311_FRAC_BITS-1:0]};
                dac311_base <= dac_final[15:DAC311_FRAC_BITS];
            end
        end
    end

    wire [DAC311_BITS:0]   dac311_sum  = {1'b0, dac311_base} + (dither_bit & ~dac_dither_dis);
    wire [DAC311_BITS-1:0] dac311_code = dac311_sum[DAC311_BITS] ? {DAC311_BITS{1'b1}} : dac311_sum[DAC311_BITS-1:0];

    dacxx11_spi u_dacxx11_spi (
        .clk    (clk),
        .rst    (init),
        .data   ({dac311_code, {(12-DAC311_BITS){1'b0}}}),
        .sclk   (CLK_40M_DAC_SCLK),
        .mosi   (CLK_40M_DAC_DIN),
        .sync_n (CLK_40M_DAC_nSYNC)
    );

endmodule
