# constraints
# ad9361 (SWAP == 0x1)
# Pin LOCs below are identical to boards/fishball7010/system_constr.xdc --
# this board's schematic reuses the exact same AD9361/SPI/control pinout
# (verified pin-for-pin against doc/schematics/PCIE_7010_SDR-Schematic.pdf,
# sheet ZYNQ_PL_BANK.SchDoc, "PL端BANK34" column, U1B/XC7Z020CLG400 -- the
# 7010/7020 CLG400 package is pin-compatible).
#BANK34
set_property  -dict {PACKAGE_PIN  U18  IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports rx_clk_in_p]
set_property  -dict {PACKAGE_PIN  U19  IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports rx_clk_in_n]
set_property  -dict {PACKAGE_PIN  Y16  IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports rx_frame_in_p]
set_property  -dict {PACKAGE_PIN  Y17  IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports rx_frame_in_n]
set_property  -dict {PACKAGE_PIN  Y18  IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports rx_data_in_p[0]]
set_property  -dict {PACKAGE_PIN  Y19  IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports rx_data_in_n[0]]
set_property  -dict {PACKAGE_PIN  T16  IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports rx_data_in_p[1]]
set_property  -dict {PACKAGE_PIN  U17  IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports rx_data_in_n[1]]
set_property  -dict {PACKAGE_PIN  V20  IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports rx_data_in_p[2]]
set_property  -dict {PACKAGE_PIN  W20  IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports rx_data_in_n[2]]
set_property  -dict {PACKAGE_PIN  T17  IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports rx_data_in_p[3]]
set_property  -dict {PACKAGE_PIN  R18  IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports rx_data_in_n[3]]
set_property  -dict {PACKAGE_PIN  T20  IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports rx_data_in_p[4]]
set_property  -dict {PACKAGE_PIN  U20  IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports rx_data_in_n[4]]
set_property  -dict {PACKAGE_PIN  W18  IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports rx_data_in_p[5]]
set_property  -dict {PACKAGE_PIN  W19  IOSTANDARD LVDS_25 DIFF_TERM TRUE} [get_ports rx_data_in_n[5]]
set_property  -dict {PACKAGE_PIN  U14  IOSTANDARD LVDS_25} [get_ports tx_clk_out_p]
set_property  -dict {PACKAGE_PIN  U15  IOSTANDARD LVDS_25} [get_ports tx_clk_out_n]
set_property  -dict {PACKAGE_PIN  V16  IOSTANDARD LVDS_25} [get_ports tx_frame_out_p]
set_property  -dict {PACKAGE_PIN  W16  IOSTANDARD LVDS_25} [get_ports tx_frame_out_n]
set_property  -dict {PACKAGE_PIN  V15  IOSTANDARD LVDS_25} [get_ports tx_data_out_p[0]]
set_property  -dict {PACKAGE_PIN  W15  IOSTANDARD LVDS_25} [get_ports tx_data_out_n[0]]
set_property  -dict {PACKAGE_PIN  V12  IOSTANDARD LVDS_25} [get_ports tx_data_out_p[1]]
set_property  -dict {PACKAGE_PIN  W13  IOSTANDARD LVDS_25} [get_ports tx_data_out_n[1]]
set_property  -dict {PACKAGE_PIN  W14  IOSTANDARD LVDS_25} [get_ports tx_data_out_p[2]]
set_property  -dict {PACKAGE_PIN  Y14  IOSTANDARD LVDS_25} [get_ports tx_data_out_n[2]]
set_property  -dict {PACKAGE_PIN  T12  IOSTANDARD LVDS_25} [get_ports tx_data_out_p[3]]
set_property  -dict {PACKAGE_PIN  U12  IOSTANDARD LVDS_25} [get_ports tx_data_out_n[3]]
set_property  -dict {PACKAGE_PIN  T11  IOSTANDARD LVDS_25} [get_ports tx_data_out_p[4]]
set_property  -dict {PACKAGE_PIN  T10  IOSTANDARD LVDS_25} [get_ports tx_data_out_n[4]]
set_property  -dict {PACKAGE_PIN  U13  IOSTANDARD LVDS_25} [get_ports tx_data_out_p[5]]
set_property  -dict {PACKAGE_PIN  V13  IOSTANDARD LVDS_25} [get_ports tx_data_out_n[5]]

set_property  -dict {PACKAGE_PIN  L20 IOSTANDARD LVCMOS25} [get_ports gpio_status[0]]
set_property  -dict {PACKAGE_PIN  L19 IOSTANDARD LVCMOS25} [get_ports gpio_status[1]]
set_property  -dict {PACKAGE_PIN  K19 IOSTANDARD LVCMOS25} [get_ports gpio_status[2]]
set_property  -dict {PACKAGE_PIN  T14 IOSTANDARD LVCMOS25} [get_ports gpio_status[3]]
set_property  -dict {PACKAGE_PIN  P15 IOSTANDARD LVCMOS25} [get_ports gpio_status[4]]
set_property  -dict {PACKAGE_PIN  M20 IOSTANDARD LVCMOS25} [get_ports gpio_status[5]]
set_property  -dict {PACKAGE_PIN  M19 IOSTANDARD LVCMOS25} [get_ports gpio_status[6]]
set_property  -dict {PACKAGE_PIN  N20 IOSTANDARD LVCMOS25} [get_ports gpio_status[7]]

set_property  -dict {PACKAGE_PIN  J19 IOSTANDARD LVCMOS25} [get_ports gpio_ctl[0]]
set_property  -dict {PACKAGE_PIN  K14 IOSTANDARD LVCMOS25} [get_ports gpio_ctl[1]]
set_property  -dict {PACKAGE_PIN  R14 IOSTANDARD LVCMOS25} [get_ports gpio_ctl[2]]
set_property  -dict {PACKAGE_PIN  J20 IOSTANDARD LVCMOS25} [get_ports gpio_ctl[3]]
set_property  -dict {PACKAGE_PIN  P20  IOSTANDARD LVCMOS25} [get_ports gpio_en_agc]
set_property  -dict {PACKAGE_PIN  R19  IOSTANDARD LVCMOS25} [get_ports gpio_resetb]

set_property  -dict {PACKAGE_PIN  T15  IOSTANDARD LVCMOS25} [get_ports enable]
set_property  -dict {PACKAGE_PIN  P18  IOSTANDARD LVCMOS25} [get_ports txnrx]

set_property  -dict {PACKAGE_PIN  R17  IOSTANDARD LVCMOS25  PULLTYPE PULLUP} [get_ports spi_csn]
set_property  -dict {PACKAGE_PIN  V18  IOSTANDARD LVCMOS25} [get_ports spi_clk]
set_property  -dict {PACKAGE_PIN  P16  IOSTANDARD LVCMOS25} [get_ports spi_mosi]
set_property  -dict {PACKAGE_PIN  V17  IOSTANDARD LVCMOS25} [get_ports spi_miso]

set_property  -dict {PACKAGE_PIN  P14  IOSTANDARD LVCMOS25 PULLTYPE PULLDOWN} [get_ports ptt_io]

######################## RGMII (RTL8211F Ethernet PHY) ##########################
# Pin LOCs from doc/schematics/PCIE_7010_SDR-Schematic.pdf, sheet
# ZYNQ_PL_BANK.SchDoc, "PL端BANK13"/"PL端BANK35" columns (U1G/U1C), extracted
# via pdftotext for exact ball designators. The gmii_to_rgmii IP (Include_
# Shared_Logic_in_Core) provides its own IDDR/ODDR + delay primitives, so no
# separate set_input_delay/set_output_delay is needed beyond the RGMII_rxc
# clock below (same treatment as boards/plutoskyr2/system_constr.xdc).
#
# Bank voltage note: the schematic's sheet-column groupings ("PL端BANK13" vs
# "PL端BANK35") do NOT map 1:1 onto Xilinx's actual physical I/O banks for
# this pin set -- confirmed by two rounds of Vivado DRC (BIVC-1) failures:
# first between MDIO_PHY_mdc and gpio_status[0] (a proven-working pin reused
# verbatim from fishball7010, LVCMOS25), then between MDIO_PHY_mdc and
# RGMII_rd[0] -- meaning the RGMII data/ctrl/clk pins, the MDIO pins, AND the
# fishball7010-inherited gpio_status/gpio_ctl pins are all one physical bank.
# Since gpio_status/gpio_ctl are proven-working at LVCMOS25, and 2.5V is also
# the original RGMII spec voltage (matches plutoskyr2's own working RGMII
# constraints too), LVCMOS25 is used uniformly across the whole RGMII+MDIO
# bus below rather than the schematic's per-sheet VCC3V3/VCC1V8 net labels.

set_property  -dict {PACKAGE_PIN  A20  IOSTANDARD LVCMOS25} [get_ports RGMII_txc]
set_property  -dict {PACKAGE_PIN  C20  IOSTANDARD LVCMOS25} [get_ports RGMII_tx_ctl]
set_property  -dict {PACKAGE_PIN  B19  IOSTANDARD LVCMOS25} [get_ports {RGMII_td[0]}]
set_property  -dict {PACKAGE_PIN  B20  IOSTANDARD LVCMOS25} [get_ports {RGMII_td[1]}]
set_property  -dict {PACKAGE_PIN  D19  IOSTANDARD LVCMOS25} [get_ports {RGMII_td[2]}]
set_property  -dict {PACKAGE_PIN  D18  IOSTANDARD LVCMOS25} [get_ports {RGMII_td[3]}]
set_property  -dict {PACKAGE_PIN  F16  IOSTANDARD LVCMOS25} [get_ports RGMII_rx_ctl]
set_property  -dict {PACKAGE_PIN  E17  IOSTANDARD LVCMOS25} [get_ports {RGMII_rd[0]}]
set_property  -dict {PACKAGE_PIN  D20  IOSTANDARD LVCMOS25} [get_ports {RGMII_rd[1]}]
set_property  -dict {PACKAGE_PIN  E18  IOSTANDARD LVCMOS25} [get_ports {RGMII_rd[2]}]
set_property  -dict {PACKAGE_PIN  E19  IOSTANDARD LVCMOS25} [get_ports {RGMII_rd[3]}]
set_property  -dict {PACKAGE_PIN  H16  IOSTANDARD LVCMOS25} [get_ports RGMII_rxc]
set_property  -dict {PACKAGE_PIN  G18  IOSTANDARD LVCMOS25} [get_ports MDIO_PHY_mdc]
set_property  -dict {PACKAGE_PIN  G17  IOSTANDARD LVCMOS25} [get_ports MDIO_PHY_mdio_io]

# RGMII recovered clock from RTL8211F (125 MHz at 1 Gbps)
create_clock -name rgmii_rxc -period 8.000 [get_ports RGMII_rxc]

create_clock -name clk_fpga_0 -period 10 [get_pins "i_system_wrapper/system_i/sys_ps7/inst/PS7_i/FCLKCLK[0]"]
create_clock -name clk_fpga_1 -period  5 [get_pins "i_system_wrapper/system_i/sys_ps7/inst/PS7_i/FCLKCLK[1]"]

create_clock -name spi0_clk      -period 40   [get_pins -hier */EMIOSPI0SCLKO]

set_input_jitter clk_fpga_0 0.3
set_input_jitter clk_fpga_1 0.15

set_false_path -from [get_pins {i_system_wrapper/system_i/axi_ad9361/inst/i_rx/i_up_adc_common/up_adc_gpio_out_int_reg[0]/C}]
set_false_path -from [get_pins {i_system_wrapper/system_i/axi_ad9361/inst/i_tx/i_up_dac_common/up_dac_gpio_out_int_reg[0]/C}]
set_false_path -from [get_pins {i_system_wrapper/system_i/axi_ad9361/inst/i_rx/i_up_adc_common/up_adc_gpio_out_int_reg[1]/C}]
set_false_path -from [get_pins {i_system_wrapper/system_i/axi_ad9361/inst/i_tx/i_up_dac_common/up_dac_gpio_out_int_reg[1]/C}]
set_false_path -from [get_pins {i_system_wrapper/system_i/axi_ad9361/inst/i_rx/i_up_adc_common/up_adc_gpio_out_int_reg[2]/C}]
set_false_path -from [get_pins {i_system_wrapper/system_i/axi_ad9361/inst/i_tx/i_up_dac_common/up_dac_gpio_out_int_reg[2]/C}]


set_false_path -from [get_pins {i_system_wrapper/system_i/axi_ad9361/inst/i_rx/i_up_adc_common/i_xfer_cntrl/d_data_cntrl_int_reg[0]/C}]
set_false_path -from [get_pins {i_system_wrapper/system_i/axi_ad9361/inst/i_rx/i_up_adc_common/i_xfer_cntrl/d_data_cntrl_int_reg[1]/C}]
set_false_path -from [get_pins {i_system_wrapper/system_i/axi_ad9361/inst/i_tx/i_up_dac_common/i_xfer_cntrl/d_data_cntrl_int_reg[0]/C}]
set_false_path -from [get_pins {i_system_wrapper/system_i/axi_ad9361/inst/i_tx/i_up_dac_common/i_xfer_cntrl/d_data_cntrl_int_reg[1]/C}]

# iqburst RegisterCDC: multi-bit data buses are CDC paths protected by
# PulseSynchronizer. Data is stable for multiple cycles before/after the
# toggle fires, so these paths are safe to relax.
#
# Request path: s_axi_lite_clk (clk_fpga_0) -> iq_clk (clk_div_sel_0_s)
set_max_delay -datapath_only \
    -from [get_cells {i_system_wrapper/system_i/myiqburst/inst/reg_cdc/cdc_request_data_src_reg[*]}] \
    -to   [get_cells {i_system_wrapper/system_i/myiqburst/inst/reg_cdc/cdc_request_data_dest_reg[*]}] \
    10.0
# Response path: iq_clk (clk_div_sel_0_s) -> s_axi_lite_clk (clk_fpga_0)
set_max_delay -datapath_only \
    -from [get_cells {i_system_wrapper/system_i/myiqburst/inst/reg_cdc/cdc_response_data_src_reg[*]}] \
    -to   [get_cells {i_system_wrapper/system_i/myiqburst/inst/reg_cdc/cdc_response_data_dest_reg[*]}] \
    10.0
# Toggle synchronizer inputs: first stage of FFSynchronizer is by definition
# an asynchronous input — setup violations here are expected and handled by
# ASYNC_REG placement. Exclude from timing analysis.
set_false_path -to \
    [get_cells {i_system_wrapper/system_i/myiqburst/inst/reg_cdc/request_sync/ff_sync/stage0_reg}]
set_false_path -to \
    [get_cells {i_system_wrapper/system_i/myiqburst/inst/reg_cdc/response_sync/ff_sync/stage0_reg}]

# clocks

create_clock -name rx_clk       -period  4 [get_ports rx_clk_in_p]
