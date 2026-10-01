# PlutoSky-R2  —  XC7Z020-2CLG484I
# Fully corrected from CLG400 reference design.
# Every PL pin assignment derived from PlutoSky-R2-schematic.pdf page 7 (ZYNQ_PL_BANK)
# cross-referenced against pages 5 (ETH), 11 (AD936X digital), 14 (CLOCK), 15 (EXT_IO).
#
# Bank voltages (schematic sheet 3, ZYNQ_PWR_BANK):
#   Bank 13 VCCO = VCC3V3  → LVCMOS33 (single-ended), LVDS_25 (differential, HR bank)
#   Bank 33 VCCO = VCC1V8  → LVCMOS25
#   Bank 34 VCCO = VCC1V8  → LVCMOS25
#   Bank 35 VCCO = VCC1V8  → LVCMOS25
#
# PS-domain signals (MIO: QSPI, UART, SD, USB/OTG) are configured inside the
# PS7 IP block and need no XDC entries.  Dedicated config/JTAG pins
# (TCK, TDI, TDO, TMS, DONE, PROG_B, INIT_B) also need no XDC entries.

# ═══════════════════════════════════════════════════════════════════════════════
# AD9361 LVDS interface — Bank 13 (VCCO = VCC3V3)
# Use LVDS_25 on Bank 13: it is a High Range (HR) bank which supports LVDS_25 but NOT LVDS.
# (LVDS requires a High Performance bank. LVDS_25 works at VCCO=2.5V or 3.3V on HR.)
# DIFF_TERM TRUE on all RX pairs; omit on TX outputs.
# ═══════════════════════════════════════════════════════════════════════════════

# DATA_CLK → rx_clk_in  (IO_L14P/N_T2_SRCC_13 — SRCC-capable, dedicated route OK)
set_property  -dict {PACKAGE_PIN  AA7   IOSTANDARD LVDS_25  DIFF_TERM TRUE} [get_ports rx_clk_in_p]
set_property  -dict {PACKAGE_PIN  AA6   IOSTANDARD LVDS_25  DIFF_TERM TRUE} [get_ports rx_clk_in_n]

# RX_FRAME  (IO_L11P/N_T1_SRCC_13)
set_property  -dict {PACKAGE_PIN  AA9   IOSTANDARD LVDS_25  DIFF_TERM TRUE} [get_ports rx_frame_in_p]
set_property  -dict {PACKAGE_PIN  AA8   IOSTANDARD LVDS_25  DIFF_TERM TRUE} [get_ports rx_frame_in_n]

# RX_D[0..5]
set_property  -dict {PACKAGE_PIN  AB10  IOSTANDARD LVDS_25  DIFF_TERM TRUE} [get_ports {rx_data_in_p[0]}]
set_property  -dict {PACKAGE_PIN  AB9   IOSTANDARD LVDS_25  DIFF_TERM TRUE} [get_ports {rx_data_in_n[0]}]
set_property  -dict {PACKAGE_PIN  Y11   IOSTANDARD LVDS_25  DIFF_TERM TRUE} [get_ports {rx_data_in_p[1]}]
set_property  -dict {PACKAGE_PIN  Y10   IOSTANDARD LVDS_25  DIFF_TERM TRUE} [get_ports {rx_data_in_n[1]}]
set_property  -dict {PACKAGE_PIN  AA11  IOSTANDARD LVDS_25  DIFF_TERM TRUE} [get_ports {rx_data_in_p[2]}]
set_property  -dict {PACKAGE_PIN  AB11  IOSTANDARD LVDS_25  DIFF_TERM TRUE} [get_ports {rx_data_in_n[2]}]
set_property  -dict {PACKAGE_PIN  V12   IOSTANDARD LVDS_25  DIFF_TERM TRUE} [get_ports {rx_data_in_p[3]}]
set_property  -dict {PACKAGE_PIN  W12   IOSTANDARD LVDS_25  DIFF_TERM TRUE} [get_ports {rx_data_in_n[3]}]
set_property  -dict {PACKAGE_PIN  AA12  IOSTANDARD LVDS_25  DIFF_TERM TRUE} [get_ports {rx_data_in_p[4]}]
set_property  -dict {PACKAGE_PIN  AB12  IOSTANDARD LVDS_25  DIFF_TERM TRUE} [get_ports {rx_data_in_n[4]}]
set_property  -dict {PACKAGE_PIN  W11   IOSTANDARD LVDS_25  DIFF_TERM TRUE} [get_ports {rx_data_in_p[5]}]
set_property  -dict {PACKAGE_PIN  W10   IOSTANDARD LVDS_25  DIFF_TERM TRUE} [get_ports {rx_data_in_n[5]}]

# FB_CLK → tx_clk_out  (IO_L13P/N_T2_MRCC_13 — MRCC-capable)
set_property  -dict {PACKAGE_PIN  Y6    IOSTANDARD LVDS_25} [get_ports tx_clk_out_p]
set_property  -dict {PACKAGE_PIN  Y5    IOSTANDARD LVDS_25} [get_ports tx_clk_out_n]

# TX_FRAME  (IO_L12P/N_T1_MRCC_13)
set_property  -dict {PACKAGE_PIN  Y9    IOSTANDARD LVDS_25} [get_ports tx_frame_out_p]
set_property  -dict {PACKAGE_PIN  Y8    IOSTANDARD LVDS_25} [get_ports tx_frame_out_n]

# TX_D[0..5]
set_property  -dict {PACKAGE_PIN  Y4    IOSTANDARD LVDS_25} [get_ports {tx_data_out_p[0]}]
set_property  -dict {PACKAGE_PIN  AA4   IOSTANDARD LVDS_25} [get_ports {tx_data_out_n[0]}]
set_property  -dict {PACKAGE_PIN  AB2   IOSTANDARD LVDS_25} [get_ports {tx_data_out_p[1]}]
set_property  -dict {PACKAGE_PIN  AB1   IOSTANDARD LVDS_25} [get_ports {tx_data_out_n[1]}]
set_property  -dict {PACKAGE_PIN  W6    IOSTANDARD LVDS_25} [get_ports {tx_data_out_p[2]}]
set_property  -dict {PACKAGE_PIN  W5    IOSTANDARD LVDS_25} [get_ports {tx_data_out_n[2]}]
set_property  -dict {PACKAGE_PIN  V5    IOSTANDARD LVDS_25} [get_ports {tx_data_out_p[3]}]
set_property  -dict {PACKAGE_PIN  V4    IOSTANDARD LVDS_25} [get_ports {tx_data_out_n[3]}]
# TX_D[4]: corrected from V5/U5 (V5 is TX_D3_N; U5 carries CTRL_OUT5)
set_property  -dict {PACKAGE_PIN  T4    IOSTANDARD LVDS_25} [get_ports {tx_data_out_p[4]}]
set_property  -dict {PACKAGE_PIN  U4    IOSTANDARD LVDS_25} [get_ports {tx_data_out_n[4]}]
set_property  -dict {PACKAGE_PIN  AB5   IOSTANDARD LVDS_25} [get_ports {tx_data_out_p[5]}]
set_property  -dict {PACKAGE_PIN  AB4   IOSTANDARD LVDS_25} [get_ports {tx_data_out_n[5]}]

# ═══════════════════════════════════════════════════════════════════════════════
# AD9361 single-ended control — Bank 13 (LVCMOS33)
# Corrected: CLG400 had these scattered across Banks 33/34.
# ═══════════════════════════════════════════════════════════════════════════════

# CTRL_IN[0..3]  (FPGA → AD936X)
set_property  -dict {PACKAGE_PIN  R7    IOSTANDARD LVCMOS25} [get_ports {gpio_ctl[0]}]
set_property  -dict {PACKAGE_PIN  V7    IOSTANDARD LVCMOS25} [get_ports {gpio_ctl[1]}]
set_property  -dict {PACKAGE_PIN  W7    IOSTANDARD LVCMOS25} [get_ports {gpio_ctl[2]}]
set_property  -dict {PACKAGE_PIN  V9    IOSTANDARD LVCMOS25} [get_ports {gpio_ctl[3]}]

# CTRL_OUT[0..7]  (AD936X → FPGA)
set_property  -dict {PACKAGE_PIN  U6    IOSTANDARD LVCMOS25} [get_ports {gpio_status[0]}]
set_property  -dict {PACKAGE_PIN  T6    IOSTANDARD LVCMOS25} [get_ports {gpio_status[1]}]
set_property  -dict {PACKAGE_PIN  AB6   IOSTANDARD LVCMOS25} [get_ports {gpio_status[2]}]
set_property  -dict {PACKAGE_PIN  U7    IOSTANDARD LVCMOS25} [get_ports {gpio_status[3]}]
set_property  -dict {PACKAGE_PIN  AB7   IOSTANDARD LVCMOS25} [get_ports {gpio_status[4]}]
set_property  -dict {PACKAGE_PIN  U5    IOSTANDARD LVCMOS25} [get_ports {gpio_status[5]}]
set_property  -dict {PACKAGE_PIN  R6    IOSTANDARD LVCMOS25} [get_ports {gpio_status[6]}]
set_property  -dict {PACKAGE_PIN  P16   IOSTANDARD LVCMOS25} [get_ports {gpio_status[7]}]

set_property -dict {PACKAGE_PIN R15 IOSTANDARD LVCMOS25} [get_ports gpio_sync]

# EN_AGC  (Bank 34, LVCMOS25 — net routes to Bank 34 ball T18)
set_property  -dict {PACKAGE_PIN  T18   IOSTANDARD LVCMOS25} [get_ports gpio_en_agc]

# RF_RESET  (Bank 13, LVCMOS33)
set_property  -dict {PACKAGE_PIN  U11   IOSTANDARD LVCMOS25} [get_ports gpio_resetb]

# ENABLE  (Bank 13, LVCMOS33)
set_property  -dict {PACKAGE_PIN  W8    IOSTANDARD LVCMOS25} [get_ports enable]

# TXNRX  (Bank 34, LVCMOS25)
set_property  -dict {PACKAGE_PIN  R16   IOSTANDARD LVCMOS25} [get_ports txnrx]

# SPI bus — Bank 13 (LVCMOS33)
# V10/U9/U10/U12 carry SPI on this board; pad_7/9/11 entries removed (conflicts).
set_property  -dict {PACKAGE_PIN  V10  IOSTANDARD LVCMOS25  PULLTYPE PULLUP} [get_ports spi_csn]
set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS25} [get_ports spi_clk]
set_property -dict {PACKAGE_PIN U10 IOSTANDARD LVCMOS25} [get_ports spi_mosi]
set_property -dict {PACKAGE_PIN U9 IOSTANDARD LVCMOS25} [get_ports spi_miso]

# CLK_OUT from AD936X (V8 = IO_L2N_T0_13 — not clock-capable; use BUFG in RTL)
#set_property  -dict {PACKAGE_PIN  V8    IOSTANDARD LVCMOS25} [get_ports clk_out]

# ═══════════════════════════════════════════════════════════════════════════════
# RGMII — RTL8211F Ethernet PHY → Bank 35 (VCCO = VCC1V8, LVCMOS25)
# Port names follow reference board convention.
# ═══════════════════════════════════════════════════════════════════════════════

# RX path (PHY → FPGA)
set_property  -dict {PACKAGE_PIN  B19   IOSTANDARD LVCMOS25} [get_ports RGMII_rxc]
set_property  -dict {PACKAGE_PIN  C18   IOSTANDARD LVCMOS25} [get_ports RGMII_rx_ctl]
set_property  -dict {PACKAGE_PIN  A21   IOSTANDARD LVCMOS25} [get_ports {RGMII_rd[0]}]
set_property  -dict {PACKAGE_PIN  A19   IOSTANDARD LVCMOS25} [get_ports {RGMII_rd[1]}]
set_property  -dict {PACKAGE_PIN  A18   IOSTANDARD LVCMOS25} [get_ports {RGMII_rd[2]}]
set_property  -dict {PACKAGE_PIN  A22   IOSTANDARD LVCMOS25} [get_ports {RGMII_rd[3]}]

# TX path (FPGA → PHY)
set_property  -dict {PACKAGE_PIN  D18   IOSTANDARD LVCMOS25} [get_ports RGMII_txc]
set_property  -dict {PACKAGE_PIN  C17   IOSTANDARD LVCMOS25} [get_ports RGMII_tx_ctl]
set_property  -dict {PACKAGE_PIN  A17   IOSTANDARD LVCMOS25} [get_ports {RGMII_td[0]}]
set_property  -dict {PACKAGE_PIN  B17   IOSTANDARD LVCMOS25} [get_ports {RGMII_td[1]}]
set_property  -dict {PACKAGE_PIN  A16   IOSTANDARD LVCMOS25} [get_ports {RGMII_td[2]}]
set_property  -dict {PACKAGE_PIN  B16   IOSTANDARD LVCMOS25} [get_ports {RGMII_td[3]}]

# MDIO management interface
set_property  -dict {PACKAGE_PIN  C15   IOSTANDARD LVCMOS25} [get_ports MDIO_PHY_mdc]
set_property  -dict {PACKAGE_PIN  B15   IOSTANDARD LVCMOS25} [get_ports MDIO_PHY_mdio_io]

# ═══════════════════════════════════════════════════════════════════════════════
# ADF4001 PLL — Bank 33 (VCCO = VCC1V8)
# Modified by Christos Nikolaou (SV1EIA) 2026.
# Christos Nikolaou can be reached by email at : sv1eia@gmail.com
# ═══════════════════════════════════════════════════════════════════════════════
set_property -dict {PACKAGE_PIN AB22 IOSTANDARD LVCMOS33} [get_ports pll_le]
set_property -dict {PACKAGE_PIN AB21 IOSTANDARD LVCMOS33} [get_ports pll_clk]
set_property -dict {PACKAGE_PIN AA21 IOSTANDARD LVCMOS33} [get_ports pll_mosi]
set_property -dict {PACKAGE_PIN AA22 IOSTANDARD LVCMOS33} [get_ports pll_muxout]
set_property -dict {PACKAGE_PIN Y19  IOSTANDARD LVCMOS33} [get_ports i_clk]


# ═══════════════════════════════════════════════════════════════════════════════
# EXT_IO connector JP5 — Banks 33/34 (VCCO = VCC1V8)
# ═══════════════════════════════════════════════════════════════════════════════
set_property  -dict {PACKAGE_PIN  Y18   IOSTANDARD LVCMOS25} [get_ports ext_io0]

set_property  -dict {PACKAGE_PIN  K19   IOSTANDARD LVCMOS25} [get_ports {ext_io1_p}]
set_property  -dict {PACKAGE_PIN  K20   IOSTANDARD LVCMOS25} [get_ports {ext_io1_n}]
set_property  -dict {PACKAGE_PIN  L18   IOSTANDARD LVCMOS25} [get_ports {ext_io2_p}]
set_property  -dict {PACKAGE_PIN  L19   IOSTANDARD LVCMOS25} [get_ports {ext_io2_n}]
set_property  -dict {PACKAGE_PIN  M19   IOSTANDARD LVCMOS25} [get_ports {ext_io3_p}]
set_property  -dict {PACKAGE_PIN  M20   IOSTANDARD LVCMOS25} [get_ports {ext_io3_n}]
set_property  -dict {PACKAGE_PIN  N19   IOSTANDARD LVCMOS25} [get_ports {ext_io4_p}]
set_property  -dict {PACKAGE_PIN  N20   IOSTANDARD LVCMOS25} [get_ports {ext_io4_n}]
set_property  -dict {PACKAGE_PIN  M21   IOSTANDARD LVCMOS25} [get_ports {ext_io5_p}]
set_property  -dict {PACKAGE_PIN  M22   IOSTANDARD LVCMOS25} [get_ports {ext_io5_n}]
set_property  -dict {PACKAGE_PIN  N22   IOSTANDARD LVCMOS25} [get_ports {ext_io6_p}]
set_property  -dict {PACKAGE_PIN  P22   IOSTANDARD LVCMOS25} [get_ports {ext_io6_n}]
set_property  -dict {PACKAGE_PIN  R20   IOSTANDARD LVCMOS25} [get_ports {ext_io7_p}]
set_property  -dict {PACKAGE_PIN  R21   IOSTANDARD LVCMOS25} [get_ports {ext_io7_n}]
set_property  -dict {PACKAGE_PIN  P20   IOSTANDARD LVCMOS25} [get_ports {ext_io8_p}]
set_property  -dict {PACKAGE_PIN  P21   IOSTANDARD LVCMOS25} [get_ports {ext_io8_n}]
set_property  -dict {PACKAGE_PIN  N15   IOSTANDARD LVCMOS25} [get_ports {ext_io9_p}]
set_property  -dict {PACKAGE_PIN  P15   IOSTANDARD LVCMOS25} [get_ports {ext_io9_n}]

set_property  -dict {PACKAGE_PIN  H17  IOSTANDARD LVCMOS25 PULLTYPE PULLUP} [get_ports iic_scl]
set_property  -dict {PACKAGE_PIN  F16  IOSTANDARD LVCMOS25 PULLTYPE PULLUP} [get_ports iic_sda]

set_property  -dict {PACKAGE_PIN  E16  IOSTANDARD LVCMOS25} [get_ports pl_spi_clk_o]
set_property  -dict {PACKAGE_PIN  D16  IOSTANDARD LVCMOS25} [get_ports pl_spi_miso]
set_property  -dict {PACKAGE_PIN  D17  IOSTANDARD LVCMOS25} [get_ports pl_spi_mosi]


# ═══════════════════════════════════════════════════════════════════════════════
# Clock definitions
# ═══════════════════════════════════════════════════════════════════════════════
create_clock -name clk_fpga_0    -period 10   [get_pins "i_system_wrapper/system_i/sys_ps7/inst/PS7_i/FCLKCLK[0]"]
create_clock -name clk_fpga_1    -period  5   [get_pins "i_system_wrapper/system_i/sys_ps7/inst/PS7_i/FCLKCLK[1]"]
create_clock -name spi0_clk      -period 40   [get_pins -hier */EMIOSPI0SCLKO]

# AD9361 DATA_CLK on AA7 (IO_L14P_T2_SRCC_13) — SRCC, dedicated route valid
create_clock -name rx_clk        -period  4   [get_ports rx_clk_in_p]

# CLK_40M_FPGA from the VCTCXO (Y19 = IO_L11P_T1_SRCC_33)
create_clock -name clk_40m       -period 25   [get_ports i_clk]

# ADF4001 MUXOUT = R divider output (10 MHz with the reference present),
# counted by ADF4001_refdet. AA22 is not clock capable; at 10 MHz the
# general routing to the BUFG is fine.
create_clock -name pll_muxout    -period 50   [get_ports pll_muxout]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -of_objects [get_ports pll_muxout]]
set_clock_groups -asynchronous -group [get_clocks clk_40m] -group [get_clocks pll_muxout]
# While MUXOUT is programmed as lock detect it is a level, sampled by the
# two-flop synchroniser in ADF4001_refctl: no timing relation to clk_40m.
set_false_path -from [get_ports pll_muxout] -to [get_cells -hier -filter {NAME =~ *i_adf4001_refctl/mux_s_reg*}]

# RGMII recovered clock from RTL8211F (125 MHz at 1 Gbps)
# B19 = IO_L13N_T2_MRCC_35 — MRCC-capable, dedicated route valid
create_clock -period 8.000 [get_ports RGMII_rxc]


set_input_jitter clk_fpga_0    0.3
set_input_jitter clk_fpga_1    0.15

# ═══════════════════════════════════════════════════════════════════════════════
# False paths / CDC
# ═══════════════════════════════════════════════════════════════════════════════
set_false_path -from [get_pins {i_system_wrapper/system_i/axi_ad9361/inst/i_rx/i_up_adc_common/up_adc_gpio_out_int_reg[0]/C}]
set_false_path -from [get_pins {i_system_wrapper/system_i/axi_ad9361/inst/i_tx/i_up_dac_common/up_dac_gpio_out_int_reg[0]/C}]
set_false_path -from [get_pins {i_system_wrapper/system_i/axi_ad9361/inst/i_rx/i_up_adc_common/up_adc_gpio_out_int_reg[1]/C}]
set_false_path -from [get_pins {i_system_wrapper/system_i/axi_ad9361/inst/i_tx/i_up_dac_common/up_dac_gpio_out_int_reg[1]/C}]
set_false_path -from [get_pins {i_system_wrapper/system_i/axi_ad9361/inst/i_rx/i_up_adc_common/up_adc_gpio_out_int_reg[2]/C}]
set_false_path -from [get_pins {i_system_wrapper/system_i/axi_ad9361/inst/i_tx/i_up_dac_common/up_dac_gpio_out_int_reg[2]/C}]

set_false_path -from [get_pins {i_system_wrapper/system_i/manual_decim/U0/gpio_core_1/Not_Dual.gpio_Data_Out_reg[0]/C}]

set_false_path -from [get_pins {i_system_wrapper/system_i/axi_ad9361/inst/i_rx/i_up_adc_common/i_xfer_cntrl/d_data_cntrl_int_reg[0]/C}]
set_false_path -from [get_pins {i_system_wrapper/system_i/axi_ad9361/inst/i_rx/i_up_adc_common/i_xfer_cntrl/d_data_cntrl_int_reg[1]/C}]
set_false_path -from [get_pins {i_system_wrapper/system_i/axi_ad9361/inst/i_tx/i_up_dac_common/i_xfer_cntrl/d_data_cntrl_int_reg[0]/C}]
set_false_path -from [get_pins {i_system_wrapper/system_i/axi_ad9361/inst/i_tx/i_up_dac_common/i_xfer_cntrl/d_data_cntrl_int_reg[1]/C}]

# iqburst CDC — data protected by PulseSynchronizer
set_max_delay -datapath_only \
    -from [get_cells {i_system_wrapper/system_i/myiqburst/inst/reg_cdc/cdc_request_data_src_reg[*]}] \
    -to   [get_cells {i_system_wrapper/system_i/myiqburst/inst/reg_cdc/cdc_request_data_dest_reg[*]}] \
    10.0
set_max_delay -datapath_only \
    -from [get_cells {i_system_wrapper/system_i/myiqburst/inst/reg_cdc/cdc_response_data_src_reg[*]}] \
    -to   [get_cells {i_system_wrapper/system_i/myiqburst/inst/reg_cdc/cdc_response_data_dest_reg[*]}] \
    10.0
set_false_path -to \
    [get_cells {i_system_wrapper/system_i/myiqburst/inst/reg_cdc/request_sync/ff_sync/stage0_reg}]
set_false_path -to \
    [get_cells {i_system_wrapper/system_i/myiqburst/inst/reg_cdc/response_sync/ff_sync/stage0_reg}]
