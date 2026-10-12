
set_property -dict {PACKAGE_PIN V6 IOSTANDARD LVCMOS33} [get_ports CLK_40M_DAC_nSYNC];
set_property -dict {PACKAGE_PIN W6 IOSTANDARD LVCMOS33} [get_ports CLK_40M_DAC_SCLK];
set_property -dict {PACKAGE_PIN V10 IOSTANDARD LVCMOS33} [get_ports CLK_40M_DAC_DIN];
set_property -dict {PACKAGE_PIN V11 IOSTANDARD LVCMOS33} [get_ports PPS_IN];
set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVCMOS18} [get_ports CLK_40MHz_FPGA];
set_property -dict {PACKAGE_PIN J18 IOSTANDARD LVCMOS18} [get_ports CLKIN_10MHz];
set_property -dict {PACKAGE_PIN M20 IOSTANDARD LVCMOS18} [get_ports CLKIN_10MHz_REQ];


set_property -dict {PACKAGE_PIN C20 IOSTANDARD LVCMOS18} [get_ports {RGMII_td[3]}];
set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS18} [get_ports {RGMII_td[2]}];
set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS18} [get_ports {RGMII_td[1]}];
set_property -dict {PACKAGE_PIN F19 IOSTANDARD LVCMOS18} [get_ports {RGMII_td[0]}];
set_property -dict {PACKAGE_PIN E18 IOSTANDARD LVCMOS18} [get_ports {RGMII_rd[3]}];
set_property -dict {PACKAGE_PIN E19 IOSTANDARD LVCMOS18} [get_ports {RGMII_rd[2]}];
set_property -dict {PACKAGE_PIN E17 IOSTANDARD LVCMOS18} [get_ports {RGMII_rd[1]}];
set_property -dict {PACKAGE_PIN F16 IOSTANDARD LVCMOS18} [get_ports {RGMII_rd[0]}];

set_property -dict {PACKAGE_PIN F20 IOSTANDARD LVCMOS18} [get_ports RGMII_tx_ctl];
set_property -dict {PACKAGE_PIN D18 IOSTANDARD LVCMOS18} [get_ports RGMII_txc];
set_property -dict {PACKAGE_PIN G17 IOSTANDARD LVCMOS18} [get_ports RGMII_rx_ctl];
set_property -dict {PACKAGE_PIN H16 IOSTANDARD LVCMOS18} [get_ports RGMII_rxc];
set_property -dict {PACKAGE_PIN B19 IOSTANDARD LVCMOS18} [get_ports eth_rst_n];
set_property -dict {PACKAGE_PIN A20 IOSTANDARD LVCMOS18} [get_ports MDIO_PHY_mdio_io];
set_property -dict {PACKAGE_PIN B20 IOSTANDARD LVCMOS18} [get_ports MDIO_PHY_mdc];

set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVCMOS18} [get_ports tx_amp_en];

create_clock -period 8.000 [get_ports RGMII_rxc];

set_property -dict {PACKAGE_PIN T15 IOSTANDARD LVCMOS18} [get_ports {gpio_status[7]}];
set_property -dict {PACKAGE_PIN K16 IOSTANDARD LVCMOS18} [get_ports {gpio_status[6]}];
set_property -dict {PACKAGE_PIN P14 IOSTANDARD LVCMOS18} [get_ports {gpio_status[5]}];
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS18} [get_ports {gpio_status[4]}];
set_property -dict {PACKAGE_PIN R14 IOSTANDARD LVCMOS18} [get_ports {gpio_status[3]}];
set_property -dict {PACKAGE_PIN J16 IOSTANDARD LVCMOS18} [get_ports {gpio_status[2]}];
set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS18} [get_ports {gpio_status[1]}];
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS18} [get_ports {gpio_status[0]}];
set_property -dict {PACKAGE_PIN T11 IOSTANDARD LVCMOS18} [get_ports {gpio_ctl[3]}];
set_property -dict {PACKAGE_PIN V13 IOSTANDARD LVCMOS18} [get_ports {gpio_ctl[2]}];
set_property -dict {PACKAGE_PIN T14 IOSTANDARD LVCMOS18} [get_ports {gpio_ctl[1]}];
set_property -dict {PACKAGE_PIN U13 IOSTANDARD LVCMOS18} [get_ports {gpio_ctl[0]}];
set_property -dict {PACKAGE_PIN P16 IOSTANDARD LVCMOS18} [get_ports gpio_en_agc];
set_property -dict {PACKAGE_PIN T17 IOSTANDARD LVCMOS18} [get_ports gpio_resetb];
set_property -dict {PACKAGE_PIN R18 IOSTANDARD LVCMOS18} [get_ports enable];
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS18} [get_ports txnrx];

set_property PACKAGE_PIN T20 [get_ports spi_csn];
set_property IOSTANDARD LVCMOS18 [get_ports spi_csn];
set_property PULLUP true [get_ports spi_csn];
set_property -dict {PACKAGE_PIN R19 IOSTANDARD LVCMOS18} [get_ports spi_clk];
set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVCMOS18} [get_ports spi_mosi];
set_property -dict {PACKAGE_PIN T19 IOSTANDARD LVCMOS18} [get_ports spi_miso];


set_property -dict {PACKAGE_PIN N20 IOSTANDARD LVCMOS18} [get_ports rx_clk_in];
set_property -dict {PACKAGE_PIN Y16 IOSTANDARD LVCMOS18} [get_ports rx_frame_in];
set_property -dict {PACKAGE_PIN W14 IOSTANDARD LVCMOS18} [get_ports {rx_data_in[11]}];
set_property -dict {PACKAGE_PIN Y14 IOSTANDARD LVCMOS18} [get_ports {rx_data_in[10]}];
set_property -dict {PACKAGE_PIN V20 IOSTANDARD LVCMOS18} [get_ports {rx_data_in[9]}];
set_property -dict {PACKAGE_PIN W20 IOSTANDARD LVCMOS18} [get_ports {rx_data_in[8]}];
set_property -dict {PACKAGE_PIN R16 IOSTANDARD LVCMOS18} [get_ports {rx_data_in[7]}];
set_property -dict {PACKAGE_PIN R17 IOSTANDARD LVCMOS18} [get_ports {rx_data_in[6]}];
set_property -dict {PACKAGE_PIN W18 IOSTANDARD LVCMOS18} [get_ports {rx_data_in[5]}];
set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS18} [get_ports {rx_data_in[4]}];
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS18} [get_ports {rx_data_in[3]}];
set_property -dict {PACKAGE_PIN V18 IOSTANDARD LVCMOS18} [get_ports {rx_data_in[2]}];
set_property -dict {PACKAGE_PIN Y18 IOSTANDARD LVCMOS18} [get_ports {rx_data_in[1]}];
set_property -dict {PACKAGE_PIN Y19 IOSTANDARD LVCMOS18} [get_ports {rx_data_in[0]}];
set_property -dict {PACKAGE_PIN N18 IOSTANDARD LVCMOS18} [get_ports tx_clk_out];
set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVCMOS18} [get_ports tx_frame_out];
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS18} [get_ports {tx_data_out[11]}];
set_property -dict {PACKAGE_PIN W15 IOSTANDARD LVCMOS18} [get_ports {tx_data_out[10]}];
set_property -dict {PACKAGE_PIN T12 IOSTANDARD LVCMOS18} [get_ports {tx_data_out[9]}];
set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS18} [get_ports {tx_data_out[8]}];
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS18} [get_ports {tx_data_out[7]}];
set_property -dict {PACKAGE_PIN W13 IOSTANDARD LVCMOS18} [get_ports {tx_data_out[6]}];
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS18} [get_ports {tx_data_out[5]}];
set_property -dict {PACKAGE_PIN U15 IOSTANDARD LVCMOS18} [get_ports {tx_data_out[4]}];
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS18} [get_ports {tx_data_out[3]}];
set_property -dict {PACKAGE_PIN U19 IOSTANDARD LVCMOS18} [get_ports {tx_data_out[2]}];
set_property -dict {PACKAGE_PIN T16 IOSTANDARD LVCMOS18} [get_ports {tx_data_out[1]}];
set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS18} [get_ports {tx_data_out[0]}];

set_property -dict {PACKAGE_PIN Y9 IOSTANDARD LVCMOS33} [get_ports {GPIOB[7]}];
set_property -dict {PACKAGE_PIN Y6 IOSTANDARD LVCMOS33} [get_ports {GPIOB[6]}];
set_property -dict {PACKAGE_PIN Y7 IOSTANDARD LVCMOS33} [get_ports {GPIOB[5]}];
set_property -dict {PACKAGE_PIN U10 IOSTANDARD LVCMOS33} [get_ports {GPIOB[4]}];
set_property -dict {PACKAGE_PIN T9 IOSTANDARD LVCMOS33} [get_ports {GPIOB[3]}];
set_property -dict {PACKAGE_PIN V7 IOSTANDARD LVCMOS33} [get_ports {GPIOB[2]}];
set_property -dict {PACKAGE_PIN U7 IOSTANDARD LVCMOS33} [get_ports {GPIOB[1]}];
set_property -dict {PACKAGE_PIN V5 IOSTANDARD LVCMOS33} [get_ports {GPIOB[0]}];


#create_clock -name rx_clk -period  16.27 [get_ports rx_clk_in];
create_clock -name rx_clk       -period  8 [get_ports rx_clk_in]

create_clock -name clk_fpga_0 -period 10 [get_pins "i_system_wrapper/system_i/sys_ps7/inst/PS7_i/FCLKCLK[0]"];
create_clock -name clk_fpga_1 -period  5 [get_pins "i_system_wrapper/system_i/sys_ps7/inst/PS7_i/FCLKCLK[1]"];

create_clock -name spi0_clk      -period 40   [get_pins -hier */EMIOSPI0SCLKO];

set_input_jitter clk_fpga_0 0.3;
set_input_jitter clk_fpga_1 0.15;


set_false_path -from [get_pins {i_system_wrapper/system_i/axi_ad9361/inst/i_rx/i_up_adc_common/up_adc_gpio_out_int_reg[0]/C}]
set_false_path -from [get_pins {i_system_wrapper/system_i/axi_ad9361/inst/i_tx/i_up_dac_common/up_dac_gpio_out_int_reg[0]/C}]

