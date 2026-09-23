// ***************************************************************************
// ***************************************************************************
// Copyright (C) 2014-2023 Analog Devices, Inc. All rights reserved.
//
// In this HDL repository, there are many different and unique modules, consisting
// of various HDL (Verilog or VHDL) components. The individual modules are
// developed independently, and may be accompanied by separate and unique license
// terms.
//
// The user should read each of these license terms, and understand the
// freedoms and responsibilities that he or she has by using this source/core.
//
// This core is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE.
//
// Redistribution and use of source or resulting binaries, with or without modification
// of this file, are permitted under one of the following two license terms:
//
//   1. The GNU General Public License version 2 as published by the
//      Free Software Foundation, which can be found in the top level directory
//      of this repository (LICENSE_GPL2), and also online at:
//      <https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>
//
// OR
//
//   2. An ADI specific BSD license, which can be found in the top level directory
//      of this repository (LICENSE_ADIBSD), and also on-line at:
//      https://github.com/analogdevicesinc/hdl/blob/master/LICENSE_ADIBSD
//      This will allow to generate bit files and not release the source code,
//      as long as it attaches to an ADI device.
//
// ***************************************************************************
// ***************************************************************************

`timescale 1ns/100ps

module system_top (
  output          MDIO_PHY_mdc,
  inout           MDIO_PHY_mdio_io,
  input [3:0]     RGMII_rd,
  input           RGMII_rx_ctl,
  input           RGMII_rxc,
  output [3:0]    RGMII_td,
  output          RGMII_tx_ctl,
  output          RGMII_txc,

  inout   [14:0]  ddr_addr,
  inout   [ 2:0]  ddr_ba,
  inout           ddr_cas_n,
  inout           ddr_ck_n,
  inout           ddr_ck_p,
  inout           ddr_cke,
  inout           ddr_cs_n,
  inout   [ 3:0]  ddr_dm,
  inout   [31:0]  ddr_dq,
  inout   [ 3:0]  ddr_dqs_n,
  inout   [ 3:0]  ddr_dqs_p,
  inout           ddr_odt,
  inout           ddr_ras_n,
  inout           ddr_reset_n,
  inout           ddr_we_n,

  inout           fixed_io_ddr_vrn,
  inout           fixed_io_ddr_vrp,
  inout   [53:0]  fixed_io_mio,
  inout           fixed_io_ps_clk,
  inout           fixed_io_ps_porb,
  inout           fixed_io_ps_srstb,

  inout           iic_scl,
  inout           iic_sda,

  input           rx_clk_in_p,
  input           rx_clk_in_n,
  input           rx_frame_in_p,
  input           rx_frame_in_n,
  input   [ 5:0]  rx_data_in_p,
  input   [ 5:0]  rx_data_in_n,
  output          tx_clk_out_p,
  output          tx_clk_out_n,
  output          tx_frame_out_p,
  output          tx_frame_out_n,
  output  [ 5:0]  tx_data_out_p,
  output  [ 5:0]  tx_data_out_n,

  output          enable,
  output          txnrx,

  inout           gpio_resetb,
  inout           gpio_en_agc,
  inout   [ 3:0]  gpio_ctl,
  inout   [ 7:0]  gpio_status,

  output          spi_csn,
  output          spi_clk,
  output          spi_mosi,
  input           spi_miso,

  output          pl_spi_clk_o,
  output          pl_spi_mosi,
  input           pl_spi_miso,
  
  output   	  pll_le,
  output          pll_clk,
  output          pll_mosi,
  input           pll_muxout,
  input           i_clk
 
  

);

  // internal signals

  wire    [63:0]  gpio_i;
  wire    [63:0]  gpio_o;
  wire    [63:0]  gpio_t;

  // instantiations
  assign gpio_i[16:14] = gpio_o[16:14]; //Reserved
  // ADF4001 reference selection (EMIO, Linux gpio 54 + n):
  //   o[32] force external, o[34] force internal, neither: auto-detect
  //   i[33] 10 MHz present, i[35] charge pump active, i[51:36] edge count
  wire          ref_present;
  wire          pll_cp_active;
  wire  [15:0]  ref_count;
  wire          ref_use = gpio_o[34] ? 1'b0 :
                          gpio_o[32] ? 1'b1 : ref_present;

  assign gpio_i[63:52] = gpio_o[63:52];
  assign gpio_i[51:36] = ref_count;
  assign gpio_i[35]    = pll_cp_active;
  assign gpio_i[34]    = gpio_o[34];
  assign gpio_i[33]    = ref_present;
  assign gpio_i[32:31] = gpio_o[32:31];
  
 
ad_iobuf #(
    .DATA_WIDTH(26)
  ) i_iobuf (
    .dio_t ({gpio_t[26:22],gpio_t[13:0]}),
    .dio_i ({gpio_o[26:22],gpio_o[13:0]}),
    .dio_o ({gpio_i[26:22],gpio_i[13:0]}),
    .dio_p ({ 
              
              
              gpio_resetb,        // 13:13
              gpio_en_agc,        // 12:12
              gpio_ctl,           // 11: 8
              gpio_status}));     //  7: 0



  system_wrapper i_system_wrapper (
    .MDIO_PHY_mdc(MDIO_PHY_mdc),
    .MDIO_PHY_mdio_io(MDIO_PHY_mdio_io),
    .RGMII_rd(RGMII_rd),
    .RGMII_rx_ctl(RGMII_rx_ctl),
    .RGMII_rxc(RGMII_rxc),
    .RGMII_td(RGMII_td),
    .RGMII_tx_ctl(RGMII_tx_ctl),
    .RGMII_txc(RGMII_txc),

    .ddr_addr (ddr_addr),
    .ddr_ba (ddr_ba),
    .ddr_cas_n (ddr_cas_n),
    .ddr_ck_n (ddr_ck_n),
    .ddr_ck_p (ddr_ck_p),
    .ddr_cke (ddr_cke),
    .ddr_cs_n (ddr_cs_n),
    .ddr_dm (ddr_dm),
    .ddr_dq (ddr_dq),
    .ddr_dqs_n (ddr_dqs_n),
    .ddr_dqs_p (ddr_dqs_p),
    .ddr_odt (ddr_odt),
    .ddr_ras_n (ddr_ras_n),
    .ddr_reset_n (ddr_reset_n),
    .ddr_we_n (ddr_we_n),
    .enable (enable),
    .fixed_io_ddr_vrn (fixed_io_ddr_vrn),
    .fixed_io_ddr_vrp (fixed_io_ddr_vrp),
    .fixed_io_mio (fixed_io_mio),
    .fixed_io_ps_clk (fixed_io_ps_clk),
    .fixed_io_ps_porb (fixed_io_ps_porb),
    .fixed_io_ps_srstb (fixed_io_ps_srstb),
    .gpio_i (gpio_i),
    .gpio_o (gpio_o),
    .gpio_t (gpio_t),
    .rx_clk_in_p (rx_clk_in_p),
    .rx_clk_in_n (rx_clk_in_n),
    .rx_data_in_p (rx_data_in_p),
    .rx_data_in_n (rx_data_in_n),
    .rx_frame_in_p (rx_frame_in_p),
    .rx_frame_in_n (rx_frame_in_n),

    .spi0_clk_i (1'b0),
    .spi0_clk_o (spi_clk),
    .spi0_csn_0_o (spi_csn),
    .spi0_csn_1_o (),
    .spi0_csn_2_o (),
    .spi0_csn_i (1'b1),
    .spi0_sdi_i (spi_miso),
    .spi0_sdo_i (1'b0),
    .spi0_sdo_o (spi_mosi),
    
    .tx_clk_out_p (tx_clk_out_p),
    .tx_clk_out_n (tx_clk_out_n),
    .tx_data_out_p (tx_data_out_p),
    .tx_data_out_n (tx_data_out_n),
    .tx_frame_out_p (tx_frame_out_p),
    .tx_frame_out_n (tx_frame_out_n),
    .txnrx (txnrx),
    .up_enable (gpio_o[15]),
    .up_txnrx (gpio_o[16])
    
    
  );

  reg [2:0] cnt; 
reg adf4001_spi_clk;
always @(posedge i_clk) begin
    cnt <= cnt + 1'b1;          
    if(cnt == 3'd3) adf4001_spi_clk <= 1'b1;
    else if(cnt == 3'd7) begin 
        adf4001_spi_clk <= 1'b0;
        cnt <= 3'b0;
    end
end

ADF4001_init ADF4001_INIT_U(
//系统时钟复位
	.clk            (adf4001_spi_clk),
	.rst_n          (1'b1),
	.ext_ref_en     (ref_use),
	.cp_active      (pll_cp_active),

	.SPI_LE         (pll_le   ),
	.SPI_SCLK       (pll_clk  ),
	.SPI_MOSI       (pll_mosi )
);

ADF4001_refdet i_adf4001_refdet (
	.clk            (i_clk),
	.muxout         (pll_muxout),
	.present        (ref_present),
	.count          (ref_count)
);

endmodule
