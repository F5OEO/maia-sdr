`timescale 1 ns / 1 ps

// AXI-Lite register file for vctcxo_lock, adapted from the boilerplate
// used by projects/common/antsdr-hdl/axi_vcxo_ctrl (same AXI-Lite
// protocol logic, kept identical - only the user-logic register meanings
// at the bottom differ).
//
// Register map (32-bit words, offsets 0x00-0x28):
//   0x00 reg0: [0]=dac_mode, [1]=dac_dither_dis, [9:2]=p_shift,
//              [17:10]=i_shift, [31:18] unused
//   0x04 reg1: [15:0]=dac_user_set_value, [31:16]=center_dac
//   0x08      : RO dac_dyn_value[15:0] (live DAC setpoint)
//   0x0C reg3: [1:0]=dac_ref_sel (00=CLKIN_10MHz,01=PPS_IN,10=PPS_GPS,11=none)
//   0x10      : RO status: [0]=locked, [1]=ref_present
//   0x14 reg5: [31:0]=lock_thresh
//   0x18      : RO freq_error[31:0] (signed, live diagnostic)
//   0x1C      : reserved
//   0x20 reg8 : signed RX NCO frequency tuning word, turns/sample in Q0.32
//   0x24 reg9 : signed TX NCO frequency tuning word, turns/sample in Q0.32
//   0x28 reg10: [0]=RX enable, [1]=TX enable, [2]=apply toggle,
//               [3]=reset both phases on apply
//
// See vctcxo_lock.md for the full description and tuning notes.

module vctcxo_lock_v1_0_S00_AXI #
(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 6
)
(
    // User ports
    output  wire  [0:0]  dac_mode,
    output  wire  [15:0] dac_user_set_value,
    output  wire  [15:0] center_dac,
    input   wire  [15:0] dac_dyn_value,
    output  wire  [1:0]  dac_ref_sel,
    output  wire         dac_dither_dis,
    output  wire  [7:0]  p_shift,
    output  wire  [7:0]  i_shift,
    output  wire  [31:0] lock_thresh,
    input   wire         locked,
    input   wire         ref_present,
    input   wire  [31:0] freq_error,
    output  wire  [31:0] nco_rx_ftw,
    output  wire  [31:0] nco_tx_ftw,
    output  wire  [3:0]  nco_control,

    // Global Clock Signal
    input wire  S_AXI_ACLK,
    // Global Reset Signal. This Signal is Active LOW
    input wire  S_AXI_ARESETN,
    // Write address (issued by master, acceped by Slave)
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    input wire [2 : 0] S_AXI_AWPROT,
    input wire  S_AXI_AWVALID,
    output wire  S_AXI_AWREADY,
    input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
    input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    input wire  S_AXI_WVALID,
    output wire  S_AXI_WREADY,
    output wire [1 : 0] S_AXI_BRESP,
    output wire  S_AXI_BVALID,
    input wire  S_AXI_BREADY,
    input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    input wire [2 : 0] S_AXI_ARPROT,
    input wire  S_AXI_ARVALID,
    output wire  S_AXI_ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    output wire [1 : 0] S_AXI_RRESP,
    output wire  S_AXI_RVALID,
    input wire  S_AXI_RREADY
);

    // AXI4LITE signals
    reg [C_S_AXI_ADDR_WIDTH-1 : 0]  axi_awaddr;
    reg      axi_awready;
    reg      axi_wready;
    reg [1 : 0]  axi_bresp;
    reg      axi_bvalid;
    reg [C_S_AXI_ADDR_WIDTH-1 : 0]  axi_araddr;
    reg      axi_arready;
    reg [C_S_AXI_DATA_WIDTH-1 : 0]  axi_rdata;
    reg [1 : 0]  axi_rresp;
    reg      axi_rvalid;

    localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
    localparam integer OPT_MEM_ADDR_BITS = 3;

    // Eleven implemented registers in a 16-word decode window.
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg0;
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg1;
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg2;
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg3;
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg4;
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg5;
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg6;
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg7;
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg8;
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg9;
    reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg10;
    wire  slv_reg_rden;
    wire  slv_reg_wren;
    reg [C_S_AXI_DATA_WIDTH-1:0]  reg_data_out;
    integer  byte_index;
    reg  aw_en;

    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_awready <= 1'b0;
          aw_en <= 1'b1;
        end
      else
        begin
          if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
            begin
              axi_awready <= 1'b1;
              aw_en <= 1'b0;
            end
            else if (S_AXI_BREADY && axi_bvalid)
                begin
                  aw_en <= 1'b1;
                  axi_awready <= 1'b0;
                end
          else
            begin
              axi_awready <= 1'b0;
            end
        end
    end

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_awaddr <= 0;
        end
      else
        begin
          if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
            begin
              axi_awaddr <= S_AXI_AWADDR;
            end
        end
    end

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_wready <= 1'b0;
        end
      else
        begin
          if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en )
            begin
              axi_wready <= 1'b1;
            end
          else
            begin
              axi_wready <= 1'b0;
            end
        end
    end

    assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          // reg0: dac_mode=0, dac_dither_dis=0 (dithering enabled).
          // p_shift/i_shift derivation history (see vctcxo_lock.md for
          // the full account):
          //   1. ocpi.osp.libresdr's own validated values are p_shift=4,
          //      i_shift=20 (gains 1/2^4, 1/2^20), for their pi_ctrl at
          //      OUTPUT_W=12 (matching DAC7311 exactly, no dither
          //      headroom). This design keeps OUTPUT_W=16 for dithering
          //      across DAC5311/DAC6311/DAC7311, a 4-bit/16x wider
          //      range, so reproducing their actual physical gain here
          //      needs +4 fewer attenuation bits:
          //      p_shift field = SHIFT_MID-(4-4)=128 (unity),
          //      i_shift field = SHIFT_MID-(20-4)=112.
          //   2. An earlier version shipped both at 128 (unity, i.e.
          //      without step 1's rescaling at all) - i_shift=128 gave
          //      the integrator essentially no attenuation, producing
          //      correction saturating and swinging every window - seen
          //      on hardware as the output frequency toggling between
          //      two discrete spectrum-analyzer peaks.
          //   3. After applying step 1's correctly-rescaled values
          //      (p_shift=128, i_shift=112), the *same* toggling symptom
          //      persisted - confirmed via a live register write (no
          //      rebuild) that this board's specific DAC7311/VCTCXO
          //      pairing needs 4 MORE bits of attenuation than even
          //      OpenCPI's own correctly-rescaled gain: p_shift=124
          //      alone gave a fully static dac_value (90/90 samples over
          //      90s); shifting i_shift by the same 4 bits (108) to
          //      preserve the reference's P/I balance was equally
          //      stable. This mirrors a finding from the earlier
          //      b205_ref_pll.v design on this same hardware, which also
          //      needed far gentler correction than theory predicted.
          //   4. All of the above (steps 2-3) was tuned with a sign bug
          //      present in vctcxo_lock_v1_0.v (dac_raw added correction
          //      instead of subtracting it - see that file), and with
          //      center_dac at the naive-midscale 0x8000 point, which an
          //      open-loop DAC sweep later showed sits in a flat/
          //      saturated part of this board's actual VCTCXO pulling
          //      curve. With the sign fixed and center_dac corrected
          //      (below), those gains were re-validated: i_shift=108
          //      turned out inert at the widened 1s measurement window
          //      (see freq_meas.v's MEAS_CYCLES); i_shift=128 (full
          //      unity, no attenuation) caused a genuine accumulator
          //      runaway (dac jumped ~33k codes into a saturated region
          //      in one window, board needed a reboot to recover -
          //      i_shift=128's gain is 256x i_shift=120's, not a small
          //      step). i_shift=124 converges cleanly (freq_error walked
          //      from -27 to within a few counts of 0 over ~2 minutes,
          //      no overshoot, dac ramp smooth) and is the current
          //      default. See vctcxo_lock.md for the full account,
          //      including why the loop's absolute accuracy is ultimately
          //      bounded by the external CLKIN_10MHz reference's own
          //      accuracy, not by these gains.
          slv_reg0 <= {14'd0, 8'd124, 8'd124, 1'b0, 1'b0};
          // reg1[31:16]=center_dac: 0x2800 (10240), NOT the naive
          // mid-scale 0x8000 that matches the ocpi.osp.libresdr
          // reference's own default. An open-loop DAC sweep on this
          // board (dac_mode=1, PI output disconnected, so no loop-sign
          // confound) found error_out crosses zero right at 0x2800 and
          // is monotonic and reasonably sensitive there, while 0x8000
          // sits in a flat/saturated region where dac movement barely
          // affects frequency at all. This matches the empirically-swept
          // value the earlier b205_ref_pll.v design used on this same
          // board - that finding was real, and reverting to naive
          // mid-scale (done earlier this project to match the reference
          // exactly) was wrong for this hardware. See vctcxo_lock.md.
          // reg1[15:0]=dac_user_set_value=0.
          slv_reg1 <= {16'd10240, 16'd0};
          slv_reg2 <= 0;
          slv_reg3 <= 0;
          slv_reg4 <= 0;
          // reg5=lock_thresh: 100 counts (~2.5ppm in both 10 MHz mode and
          // PPS mode - freq_meas.v's MEAS_CYCLES=10_000_000 gives the
          // 10 MHz path the same 0.025ppm/count resolution as PPS - see
          // vctcxo_lock.md). Untested starting point.
          slv_reg5 <= 32'd100;
          slv_reg6 <= 0;
          slv_reg7 <= 0;
          // NCO correction is bypassed by default so the sample values remain
          // bit-exact on boards with a working VCTCXO.
          slv_reg8 <= 0;
          slv_reg9 <= 0;
          slv_reg10 <= 0;
        end
      else begin
        if (slv_reg_wren)
          begin
            case ( axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
              4'h0:
                for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    slv_reg0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end
              4'h1:
                for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    slv_reg1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end
              4'h2:
                for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    slv_reg2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end
              4'h3:
                for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    slv_reg3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end
              4'h4:
                for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    slv_reg4[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end
              4'h5:
                for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    slv_reg5[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end
              4'h6:
                for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    slv_reg6[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end
              4'h7:
                for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    slv_reg7[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end
              4'h8:
                for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    slv_reg8[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end
              4'h9:
                for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    slv_reg9[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end
              4'hA:
                for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
                  if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                    slv_reg10[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
                  end
              default : begin
                          slv_reg0 <= slv_reg0;
                          slv_reg1 <= slv_reg1;
                          slv_reg2 <= slv_reg2;
                          slv_reg3 <= slv_reg3;
                          slv_reg4 <= slv_reg4;
                          slv_reg5 <= slv_reg5;
                          slv_reg6 <= slv_reg6;
                          slv_reg7 <= slv_reg7;
                          slv_reg8 <= slv_reg8;
                          slv_reg9 <= slv_reg9;
                          slv_reg10 <= slv_reg10;
                        end
            endcase
          end
      end
    end

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_bvalid  <= 0;
          axi_bresp   <= 2'b0;
        end
      else
        begin
          if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
            begin
              axi_bvalid <= 1'b1;
              axi_bresp  <= 2'b0;
            end
          else
            begin
              if (S_AXI_BREADY && axi_bvalid)
                begin
                  axi_bvalid <= 1'b0;
                end
            end
        end
    end

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_arready <= 1'b0;
          axi_araddr  <= 32'b0;
        end
      else
        begin
          if (~axi_arready && S_AXI_ARVALID)
            begin
              axi_arready <= 1'b1;
              axi_araddr  <= S_AXI_ARADDR;
            end
          else
            begin
              axi_arready <= 1'b0;
            end
        end
    end

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_rvalid <= 0;
          axi_rresp  <= 0;
        end
      else
        begin
          if (axi_arready && S_AXI_ARVALID && ~axi_rvalid)
            begin
              axi_rvalid <= 1'b1;
              axi_rresp  <= 2'b0;
            end
          else if (axi_rvalid && S_AXI_RREADY)
            begin
              axi_rvalid <= 1'b0;
            end
        end
    end

    assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
    always @(*)
    begin
          case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
            4'h0   : reg_data_out <= slv_reg0;
            4'h1   : reg_data_out <= slv_reg1;
            4'h2   : reg_data_out <= {16'd0, dac_dyn_value};
            4'h3   : reg_data_out <= slv_reg3;
            4'h4   : reg_data_out <= {30'd0, ref_present, locked};
            4'h5   : reg_data_out <= slv_reg5;
            4'h6   : reg_data_out <= freq_error;
            4'h7   : reg_data_out <= slv_reg7;
            4'h8   : reg_data_out <= slv_reg8;
            4'h9   : reg_data_out <= slv_reg9;
            4'hA   : reg_data_out <= slv_reg10;
            default : reg_data_out <= 0;
          endcase
    end

    always @( posedge S_AXI_ACLK )
    begin
      if ( S_AXI_ARESETN == 1'b0 )
        begin
          axi_rdata  <= 0;
        end
      else
        begin
          if (slv_reg_rden)
            begin
              axi_rdata <= reg_data_out;
            end
        end
    end

    // User logic
    assign dac_mode           = slv_reg0[0];
    assign dac_dither_dis     = slv_reg0[1];
    assign p_shift             = slv_reg0[9:2];
    assign i_shift             = slv_reg0[17:10];
    assign dac_user_set_value = slv_reg1[15:0];
    assign center_dac         = slv_reg1[31:16];
    assign dac_ref_sel        = slv_reg3[1:0];
    assign lock_thresh        = slv_reg5;
    assign nco_rx_ftw         = slv_reg8;
    assign nco_tx_ftw         = slv_reg9;
    assign nco_control        = slv_reg10[3:0];

endmodule
