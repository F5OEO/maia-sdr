# create board design

# Add IP repo path for Maia SDR
#
# We need to do this here because adi_project_create overwrites whatever we had
# set beforehand.
set_property ip_repo_paths {../../antsdr-hdl ../../ip ../../adi-hdl/library} [current_fileset]
update_ip_catalog
source ../../adi-hdl/projects/common/xilinx/adi_fir_filter_bd.tcl
					 
# default ports

create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddrx_rtl:1.0 ddr
create_bd_intf_port -mode Master -vlnv xilinx.com:display_processing_system7:fixedio_rtl:1.0 fixed_io

if {[info exists e200]} {
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:mdio_rtl:1.0 MDIO_PHY
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:rgmii_rtl:1.0 RGMII
create_bd_port -dir O eth_rst_n
}

create_bd_port -dir O spi0_csn_2_o
create_bd_port -dir O spi0_csn_1_o
create_bd_port -dir O spi0_csn_0_o
create_bd_port -dir I spi0_csn_i
create_bd_port -dir I spi0_clk_i
create_bd_port -dir O spi0_clk_o
create_bd_port -dir I spi0_sdo_i
create_bd_port -dir O spi0_sdo_o
create_bd_port -dir I spi0_sdi_i

if {[info exists fishball]} {
create_bd_port -dir I -from 17 -to 0 gpio_i
create_bd_port -dir O -from 17 -to 0 gpio_o
create_bd_port -dir O -from 17 -to 0 gpio_t
} else {
create_bd_port -dir I -from 16 -to 0 gpio_i
create_bd_port -dir O -from 16 -to 0 gpio_o
create_bd_port -dir O -from 16 -to 0 gpio_t
}

if {[info exists e200]} {
create_bd_port -dir I CLKIN_10MHz
create_bd_port -dir I CLK_40MHz_FPGA
create_bd_port -dir O CLK_40M_DAC_DIN
create_bd_port -dir O CLK_40M_DAC_SCLK
create_bd_port -dir O CLK_40M_DAC_nSYNC
create_bd_port -dir I PPS_GPS
create_bd_port -dir I PPS_IN
create_bd_port -dir O PPS_LED
create_bd_port -dir O PPS_LOCKED
create_bd_port -dir O REF_10M_LOCKED
}

if {[info exists libre]} {
create_bd_port -dir I CLKIN_10MHz
create_bd_port -dir I CLK_40MHz_FPGA
create_bd_port -dir O CLK_40M_DAC_DIN
create_bd_port -dir O CLK_40M_DAC_SCLK
create_bd_port -dir O CLK_40M_DAC_nSYNC
create_bd_port -dir I PPS_GPS
create_bd_port -dir I PPS_IN
create_bd_port -dir O PPS_LED
create_bd_port -dir O PPS_LOCKED
create_bd_port -dir O REF_10M_LOCKED
}


# instance: sys_ps7

ad_ip_instance processing_system7 sys_ps7

# ps7 settings
ad_ip_parameter sys_ps7 CONFIG.PCW_PRESET_BANK0_VOLTAGE {LVCMOS 1.8V}
ad_ip_parameter sys_ps7 CONFIG.PCW_PRESET_BANK1_VOLTAGE {LVCMOS 1.8V}
ad_ip_parameter sys_ps7 CONFIG.PCW_PACKAGE_NAME clg225

if {[info exists e200]} {
ad_ip_parameter sys_ps7 CONFIG.PCW_PRESET_BANK0_VOLTAGE {LVCMOS 3.3V}
ad_ip_parameter sys_ps7 CONFIG.PCW_PRESET_BANK1_VOLTAGE {LVCMOS 3.3V}
ad_ip_parameter sys_ps7 CONFIG.PCW_PACKAGE_NAME clg400
ad_ip_parameter sys_ps7 CONFIG.PCW_GPIO_MIO_GPIO_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_ENET0_PERIPHERAL_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_ENET0_ENET0_IO "EMIO"
ad_ip_parameter sys_ps7 CONFIG.PCW_ENET0_GRP_MDIO_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_ENET0_GRP_MDIO_IO "EMIO"
}

if {[info exists libre]} {
		ad_ip_parameter sys_ps7 CONFIG.PCW_PRESET_BANK0_VOLTAGE {LVCMOS 3.3V}
		ad_ip_parameter sys_ps7 CONFIG.PCW_PRESET_BANK1_VOLTAGE {LVCMOS 2.5V}
		ad_ip_parameter sys_ps7 CONFIG.PCW_PACKAGE_NAME clg400
		ad_ip_parameter sys_ps7 CONFIG.PCW_GPIO_MIO_GPIO_ENABLE 1
		ad_ip_parameter sys_ps7 CONFIG.PCW_ENET0_PERIPHERAL_ENABLE 1
		ad_ip_parameter sys_ps7 CONFIG.PCW_ENET0_ENET0_IO "MIO 16 .. 27"
		ad_ip_parameter sys_ps7 CONFIG.PCW_ENET0_GRP_MDIO_ENABLE 1
		ad_ip_parameter sys_ps7 CONFIG.PCW_ENET0_GRP_MDIO_IO "MIO 52 .. 53"
		ad_ip_parameter sys_ps7 CONFIG.PCW_ENET_RESET_SELECT "Separate reset pins"
		ad_ip_parameter sys_ps7 CONFIG.PCW_ENET0_RESET_ENABLE 1
		ad_ip_parameter sys_ps7 CONFIG.PCW_ENET0_RESET_IO "MIO 46"

}

ad_ip_parameter sys_ps7 CONFIG.PCW_USE_S_AXI_HP1 1
ad_ip_parameter sys_ps7 CONFIG.PCW_USE_S_AXI_HP2 1
ad_ip_parameter sys_ps7 CONFIG.PCW_EN_CLK1_PORT 1
ad_ip_parameter sys_ps7 CONFIG.PCW_EN_RST1_PORT 1
ad_ip_parameter sys_ps7 CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ 100.0
ad_ip_parameter sys_ps7 CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ 200.0
ad_ip_parameter sys_ps7 CONFIG.PCW_GPIO_EMIO_GPIO_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_GPIO_EMIO_GPIO_IO 17

if {[info exists fishball]} {
ad_ip_parameter sys_ps7 CONFIG.PCW_PRESET_BANK0_VOLTAGE {LVCMOS 3.3V}
ad_ip_parameter sys_ps7 CONFIG.PCW_PRESET_BANK1_VOLTAGE {LVCMOS 1.8V}
ad_ip_parameter sys_ps7 CONFIG.PCW_PACKAGE_NAME clg400
ad_ip_parameter sys_ps7 CONFIG.PCW_GPIO_MIO_GPIO_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_ENET0_PERIPHERAL_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_ENET0_ENET0_IO "MIO 16 .. 27"
ad_ip_parameter sys_ps7 CONFIG.PCW_ENET0_GRP_MDIO_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_ENET0_GRP_MDIO_IO "MIO 52 .. 53"
ad_ip_parameter sys_ps7 CONFIG.PCW_GPIO_EMIO_GPIO_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_GPIO_EMIO_GPIO_IO 18
ad_ip_parameter sys_ps7 CONFIG.PCW_SD0_PERIPHERAL_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_SDIO_PERIPHERAL_FREQMHZ 50
}

if {[info exists plutoplus]} {
    # Pluto+ Ethernet (not available in ADALM Pluto)
    ad_ip_parameter sys_ps7 CONFIG.PCW_EN_ENET0 1
    ad_ip_parameter sys_ps7 CONFIG.PCW_ENET0_PERIPHERAL_ENABLE 1
    ad_ip_parameter sys_ps7 CONFIG.PCW_ENET0_ENET0_IO {MIO 16 .. 27}
    ad_ip_parameter sys_ps7 CONFIG.PCW_ENET0_GRP_MDIO_ENABLE 1
    ad_ip_parameter sys_ps7 CONFIG.PCW_ENET0_GRP_MDIO_IO {MIO 52 .. 53}
}

ad_ip_parameter sys_ps7 CONFIG.PCW_SPI1_PERIPHERAL_ENABLE 0
ad_ip_parameter sys_ps7 CONFIG.PCW_I2C0_PERIPHERAL_ENABLE 0
ad_ip_parameter sys_ps7 CONFIG.PCW_UART1_PERIPHERAL_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_UART1_UART1_IO {MIO 12 .. 13}

if {[info exists fishball]} {
ad_ip_parameter sys_ps7 CONFIG.PCW_UART1_UART1_IO {MIO 8 .. 9}
}

ad_ip_parameter sys_ps7 CONFIG.PCW_I2C1_PERIPHERAL_ENABLE 0
ad_ip_parameter sys_ps7 CONFIG.PCW_QSPI_PERIPHERAL_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_QSPI_GRP_SINGLE_SS_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_SPI0_PERIPHERAL_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_SPI0_SPI0_IO EMIO
ad_ip_parameter sys_ps7 CONFIG.PCW_USB0_PERIPHERAL_ENABLE 1

ad_ip_parameter sys_ps7 CONFIG.PCW_TTC0_PERIPHERAL_ENABLE 0
ad_ip_parameter sys_ps7 CONFIG.PCW_USE_FABRIC_INTERRUPT 1

ad_ip_parameter sys_ps7 CONFIG.PCW_GPIO_MIO_GPIO_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_GPIO_MIO_GPIO_IO MIO


if {[info exists pluto]} {
ad_ip_parameter sys_ps7 CONFIG.PCW_SD0_PERIPHERAL_ENABLE 0
ad_ip_parameter sys_ps7 CONFIG.PCW_USB0_RESET_IO {MIO 52}
}

if {[info exists plutoplus]} {
    # Pluto+ SD card (not available in ADALM Pluto)
    ad_ip_parameter sys_ps7 CONFIG.PCW_USB0_RESET_IO {MIO 46}
    ad_ip_parameter sys_ps7 CONFIG.PCW_MIO_46_SLEW {slow}
    ad_ip_parameter sys_ps7 CONFIG.PCW_MIO_46_PULLUP {enabled}	
    ad_ip_parameter sys_ps7 CONFIG.PCW_SD0_PERIPHERAL_ENABLE 1
    ad_ip_parameter sys_ps7 CONFIG.PCW_SD0_SD0_IO "MIO 40 .. 45"
    ad_ip_parameter sys_ps7 CONFIG.PCW_SD0_GRP_CD_ENABLE 1
    ad_ip_parameter sys_ps7 CONFIG.PCW_SD0_GRP_CD_IO "MIO 47"
    ad_ip_parameter sys_ps7 CONFIG.PCW_MIO_47_PULLUP {enabled}
    ad_ip_parameter sys_ps7 CONFIG.PCW_MIO_47_SLEW {slow}
    ad_ip_parameter sys_ps7 CONFIG.PCW_SD0_GRP_POW_ENABLE    0
    ad_ip_parameter sys_ps7 CONFIG.PCW_SD0_GRP_WP_ENABLE     0
}

if {[info exists e200]} {
	ad_ip_parameter sys_ps7 CONFIG.PCW_USB0_RESET_IO {MIO 47}
	ad_ip_parameter sys_ps7 CONFIG.PCW_I2C0_PERIPHERAL_ENABLE 1
	ad_ip_parameter sys_ps7 CONFIG.PCW_I2C0_I2C0_IO {MIO 10 .. 11}

	ad_ip_parameter sys_ps7 CONFIG.PCW_SD0_PERIPHERAL_ENABLE 1
	ad_ip_parameter sys_ps7 CONFIG.PCW_SDIO_PERIPHERAL_FREQMHZ 50
	ad_ip_parameter sys_ps7 CONFIG.PCW_UART0_PERIPHERAL_ENABLE 1
	ad_ip_parameter sys_ps7 CONFIG.PCW_UART0_UART0_IO {MIO 14 .. 15}
}

if {[info exists libre]} {
		ad_ip_parameter sys_ps7 CONFIG.PCW_USB0_RESET_IO {MIO 47}	
		ad_ip_parameter sys_ps7 CONFIG.PCW_CRYSTAL_PERIPHERAL_FREQMHZ 50
		ad_ip_parameter sys_ps7 CONFIG.PCW_SD0_PERIPHERAL_ENABLE 1
		ad_ip_parameter sys_ps7 CONFIG.PCW_SDIO_PERIPHERAL_FREQMHZ 50
		ad_ip_parameter sys_ps7 CONFIG.PCW_UART0_PERIPHERAL_ENABLE 1
		ad_ip_parameter sys_ps7 CONFIG.PCW_UART0_UART0_IO {MIO 14 .. 15}
}

if {[info exists fishball]} {	
	ad_ip_parameter sys_ps7 CONFIG.PCW_USB0_RESET_IO {MIO 46}	
}

ad_ip_parameter sys_ps7 CONFIG.PCW_USB0_RESET_ENABLE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_IRQ_F2P_INTR 1
ad_ip_parameter sys_ps7 CONFIG.PCW_IRQ_F2P_MODE REVERSE
ad_ip_parameter sys_ps7 CONFIG.PCW_MIO_0_PULLUP {enabled}
ad_ip_parameter sys_ps7 CONFIG.PCW_MIO_9_PULLUP {enabled}
ad_ip_parameter sys_ps7 CONFIG.PCW_MIO_10_PULLUP {enabled}
ad_ip_parameter sys_ps7 CONFIG.PCW_MIO_11_PULLUP {enabled}
ad_ip_parameter sys_ps7 CONFIG.PCW_MIO_48_PULLUP {enabled}
ad_ip_parameter sys_ps7 CONFIG.PCW_MIO_49_PULLUP {disabled}
ad_ip_parameter sys_ps7 CONFIG.PCW_MIO_53_PULLUP {enabled}


# DDR MT41K256M16 HA-125 (32M, 16bit, 8banks)
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_PARTNO {MT41K256M16 RE-125}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_BUS_WIDTH {16 Bit}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_USE_INTERNAL_VREF 0
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_TRAIN_WRITE_LEVEL 1
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_TRAIN_READ_GATE 1
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_TRAIN_DATA_EYE 1
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_0 0.048
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_1 0.050
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY0 0.241
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY1 0.240

if {[info exists libre]} {
	ad_ip_parameter sys_ps7 CONFIG.PCW_APU_PERIPHERAL_FREQMHZ 750	
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_PARTNO {Custom}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_BANK_ADDR_COUNT {3}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_ROW_ADDR_COUNT {15}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_COL_ADDR_COUNT {10}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_CL {9}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_CWL {7}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_T_RCD {9}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_T_RP {9}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_T_RC {48.91}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_T_RAS_MIN {35.0}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_T_FAW {40.0}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_0 {0.048}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_1 {0.050}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY0 {0.241}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY1 {0.240}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_ECC {Disabled}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_BUS_WIDTH {32 Bit}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_DRAM_WIDTH {16 Bits}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_DEVICE_CAPACITY {4096 MBits}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_SPEED_BIN {DDR3_1066F}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_TRAIN_WRITE_LEVEL {1}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_TRAIN_READ_GATE {1}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_TRAIN_DATA_EYE {1}
	ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_USE_INTERNAL_VREF {0}
}
if {[info exists fishball]} {
# DDR MT41K256M16 HA-125 (32M, 32bit, 8banks)
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_ACT_DDR_FREQ_MHZ 600	
#ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_PARTNO {MT41K256M16 RE-125}
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_PARTNO {Custom}
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_BANK_ADDR_COUNT {3}
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_ROW_ADDR_COUNT {15}
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_COL_ADDR_COUNT {10}
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_CL {11}
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_CWL {8}
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_T_RCD {11}
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_T_RP {11}
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_T_RC {48.91}
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_T_RAS_MIN {35.0}
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_T_FAW {40.0}
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_0 0.048
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_1 0.050
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY0 0.241
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY1 0.240
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_ECC {Disabled}
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_DEVICE_CAPACITY {4096 MBits}
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_SPEED_BIN {DDR3_1066F}
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_BUS_WIDTH {32 Bit}
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_DRAM_WIDTH {16 Bits}
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_USE_INTERNAL_VREF 0
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_TRAIN_WRITE_LEVEL 1
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_TRAIN_READ_GATE 1
ad_ip_parameter sys_ps7 CONFIG.PCW_UIPARAM_DDR_TRAIN_DATA_EYE 1

}


ad_ip_instance xlconcat sys_concat_intc
ad_ip_parameter sys_concat_intc CONFIG.NUM_PORTS 16

ad_ip_instance proc_sys_reset sys_rstgen
ad_ip_parameter sys_rstgen CONFIG.C_EXT_RST_WIDTH 1

# system reset/clock definitions
ad_connect  sys_cpu_clk sys_ps7/FCLK_CLK0
ad_connect  sys_200m_clk sys_ps7/FCLK_CLK1
ad_connect  sys_cpu_reset sys_rstgen/peripheral_reset
ad_connect  sys_cpu_resetn sys_rstgen/peripheral_aresetn
ad_connect  sys_cpu_clk sys_rstgen/slowest_sync_clk
ad_connect  sys_rstgen/ext_reset_in sys_ps7/FCLK_RESET0_N

if {[info exists e200]} {
	# add external ethernet phy
	ad_ip_instance gmii_to_rgmii sys_rgmii
	ad_ip_parameter sys_rgmii CONFIG.SupportLevel Include_Shared_Logic_in_Core

	set axi_vcxo_ctrl [ create_bd_cell -type ip -vlnv user.org:user:axi_vcxo_ctrl:1.0 axi_vcxo_ctrl ]
	ad_connect axi_vcxo_ctrl/CLK_40M_DAC_DIN CLK_40M_DAC_DIN
	ad_connect axi_vcxo_ctrl/CLK_40M_DAC_SCLK CLK_40M_DAC_SCLK
	ad_connect axi_vcxo_ctrl/CLK_40M_DAC_nSYNC CLK_40M_DAC_nSYNC
	ad_connect axi_vcxo_ctrl/CLKIN_10MHz CLKIN_10MHz
	ad_connect axi_vcxo_ctrl/CLK_40MHz_FPGA CLK_40MHz_FPGA
	ad_connect axi_vcxo_ctrl/PPS_GPS PPS_GPS
	ad_connect axi_vcxo_ctrl/PPS_IN PPS_IN
	ad_connect axi_vcxo_ctrl/PPS_LED PPS_LED
	ad_connect axi_vcxo_ctrl/PPS_LOCKED PPS_LOCKED
	ad_connect axi_vcxo_ctrl/REF_10M_LOCKED REF_10M_LOCKED

	ad_connect  eth_rst_n sys_rstgen/peripheral_aresetn
	ad_connect  sys_rgmii/tx_reset sys_rstgen/peripheral_reset
	ad_connect  sys_rgmii/rx_reset sys_rstgen/peripheral_reset
	ad_connect  sys_rgmii/clkin sys_ps7/FCLK_CLK1 
	ad_connect  sys_ps7/MDIO_ETHERNET_0 sys_rgmii/MDIO_GEM
	ad_connect  sys_ps7/GMII_ETHERNET_0 sys_rgmii/GMII
	ad_connect  sys_rgmii/MDIO_PHY MDIO_PHY
	ad_connect  sys_rgmii/RGMII RGMII
}

if {[info exists libre-200style]} {
	add_files -norecurse  ../../antsdr-hdl/axi_vcxo_ctrl/src/axi_vcxo_ctrl_v1_0.v
	add_files -norecurse  ../../antsdr-hdl/axi_vcxo_ctrl/src/axi_vcxo_ctrl_v1_0_S00_AXI.v
	add_files -norecurse  ../../antsdr-hdl/axi_vcxo_ctrl/src/b205_ref_pll.v
	add_files -norecurse  ../../antsdr-hdl/axi_vcxo_ctrl/src/ltc2630_spi.v
	add_files -norecurse  ../../antsdr-hdl/axi_vcxo_ctrl/src/ad5662_auto_spi.v
	add_files -norecurse  ../../antsdr-hdl/axi_vcxo_ctrl/src/dacxx11_spi.v
	create_bd_cell -type module -reference axi_vcxo_ctrl axi_vcxo_ctrl
	#set axi_vcxo_ctrl [ create_bd_cell -type ip -vlnv user.org:user:axi_vcxo_ctrl:1.0 axi_vcxo_ctrl ]
	ad_ip_parameter axi_vcxo_ctrl CONFIG.DEVICE DAC5311
	ad_connect axi_vcxo_ctrl/CLK_40M_DAC_DIN CLK_40M_DAC_DIN
	ad_connect axi_vcxo_ctrl/CLK_40M_DAC_SCLK CLK_40M_DAC_SCLK
	ad_connect axi_vcxo_ctrl/CLK_40M_DAC_nSYNC CLK_40M_DAC_nSYNC
	ad_connect axi_vcxo_ctrl/CLKIN_10MHz CLKIN_10MHz
	ad_connect axi_vcxo_ctrl/CLK_40MHz_FPGA CLK_40MHz_FPGA
	ad_connect axi_vcxo_ctrl/PPS_GPS PPS_GPS
	ad_connect axi_vcxo_ctrl/PPS_IN PPS_IN
	ad_connect axi_vcxo_ctrl/PPS_LED PPS_LED
	ad_connect axi_vcxo_ctrl/PPS_LOCKED PPS_LOCKED
	ad_connect axi_vcxo_ctrl/REF_10M_LOCKED REF_10M_LOCKED
}

if {[info exists libre]} {
add_files -norecurse  ../../libresdr-hdl/dacxx11.v
add_files -norecurse  ../../libresdr-hdl/b205_ref_pll.v
create_bd_cell -type module -reference b205_ref_pll b205_ref_pll_0
connect_bd_net [get_bd_ports CLK_40M_DAC_SCLK] [get_bd_pins b205_ref_pll_0/sclk]
connect_bd_net [get_bd_ports CLK_40M_DAC_DIN] [get_bd_pins b205_ref_pll_0/mosi]
connect_bd_net [get_bd_ports CLK_40M_DAC_nSYNC] [get_bd_pins b205_ref_pll_0/sync_n]

create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0
set_property CONFIG.C_ALL_OUTPUTS {1} [get_bd_cells axi_gpio_0]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_0
connect_bd_net [get_bd_pins xlslice_0/Din] [get_bd_pins axi_gpio_0/gpio_io_o]
connect_bd_net [get_bd_pins xlslice_0/Dout] [get_bd_pins b205_ref_pll_0/reset]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_1
set_property -dict [list \
  CONFIG.DIN_FROM {1} \
  CONFIG.DIN_TO {1} \
] [get_bd_cells xlslice_1]
connect_bd_net [get_bd_pins xlslice_1/Din] [get_bd_pins axi_gpio_0/gpio_io_o]
connect_bd_net [get_bd_pins xlslice_1/Dout] [get_bd_pins b205_ref_pll_0/dac_mode]

connect_bd_net [get_bd_ports CLK_40MHz_FPGA] [get_bd_pins b205_ref_pll_0/clk_40M_FPGA]
connect_bd_net [get_bd_ports CLKIN_10MHz] [get_bd_pins b205_ref_pll_0/ref_x] 
# You could instead connect ref_x to the PPS port

startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0
endgroup
set_property -dict [list \
  CONFIG.CONST_VAL {0} \
  CONFIG.CONST_WIDTH {16} \
] [get_bd_cells xlconstant_0]
connect_bd_net [get_bd_pins xlconstant_0/dout] [get_bd_pins b205_ref_pll_0/dac_dft]

startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0
endgroup
set_property CONFIG.NUM_PORTS {5} [get_bd_cells xlconcat_0]
connect_bd_net [get_bd_pins xlconcat_0/In0] [get_bd_pins b205_ref_pll_0/locked]
connect_bd_net [get_bd_pins xlconcat_0/In1] [get_bd_pins b205_ref_pll_0/ref_is_10M]
connect_bd_net [get_bd_pins xlconcat_0/In2] [get_bd_pins b205_ref_pll_0/ref_is_pps]
connect_bd_net [get_bd_pins xlconcat_0/In3] [get_bd_pins b205_ref_pll_0/plllck]
startgroup
set_property -dict [list CONFIG.IN4_WIDTH.VALUE_SRC USER] [get_bd_cells xlconcat_0]
set_property CONFIG.IN4_WIDTH {28} [get_bd_cells xlconcat_0]
endgroup
connect_bd_net [get_bd_pins xlconcat_0/In4] [get_bd_pins b205_ref_pll_0/dyn_dac]

startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_1
endgroup
set_property CONFIG.C_ALL_INPUTS {1} [get_bd_cells axi_gpio_1]
connect_bd_net [get_bd_pins axi_gpio_1/gpio_io_i] [get_bd_pins xlconcat_0/dout]


create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_2
set_property CONFIG.C_ALL_OUTPUTS {1} [get_bd_cells axi_gpio_2]
connect_bd_net [get_bd_pins axi_gpio_2/gpio_io_o] [get_bd_pins b205_ref_pll_0/dac_user_set_value]

ad_cpu_interconnect 0x41200000 axi_gpio_0
ad_cpu_interconnect 0x41210000 axi_gpio_1
ad_cpu_interconnect 0x41220000 axi_gpio_2



create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_led
set_property -dict [list \
  CONFIG.DIN_FROM {0} \
  CONFIG.DIN_TO {0} \
] [get_bd_cells xlslice_led]
connect_bd_net [get_bd_pins xlslice_led/Din] [get_bd_pins gpio_o]
ad_connect xlslice_led/Dout PPS_LOCKED

ad_connect b205_ref_pll_0/ref_is_10M PPS_LED
# apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/sys_ps7/FCLK_CLK0 (100 MHz)} Clk_slave {Auto} Clk_xbar {/sys_ps7/FCLK_CLK0 (100 MHz)} Master {/sys_ps7/M_AXI_GP0} Slave {/axi_gpio_0/S_AXI} ddr_seg {Auto} intc_ip {/axi_cpu_interconnect} master_apm {0}}  [get_bd_intf_pins axi_gpio_0/S_AXI]
# apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/sys_ps7/FCLK_CLK0 (100 MHz)} Clk_slave {Auto} Clk_xbar {/sys_ps7/FCLK_CLK0 (100 MHz)} Master {/sys_ps7/M_AXI_GP0} Slave {/axi_gpio_1/S_AXI} ddr_seg {Auto} intc_ip {/axi_cpu_interconnect} master_apm {0}}  [get_bd_intf_pins axi_gpio_1/S_AXI]

}
# interface connections

ad_connect  ddr sys_ps7/DDR
ad_connect  gpio_i sys_ps7/GPIO_I
#ad_connect  gpio_o sys_ps7/GPIO_O
ad_connect  gpio_t sys_ps7/GPIO_T
ad_connect  fixed_io sys_ps7/FIXED_IO

# ps7 spi connections

ad_connect  spi0_csn_2_o sys_ps7/SPI0_SS2_O
ad_connect  spi0_csn_1_o sys_ps7/SPI0_SS1_O
ad_connect  spi0_csn_0_o sys_ps7/SPI0_SS_O
ad_connect  spi0_csn_i sys_ps7/SPI0_SS_I
ad_connect  spi0_clk_i sys_ps7/SPI0_SCLK_I
ad_connect  spi0_clk_o sys_ps7/SPI0_SCLK_O
ad_connect  spi0_sdo_i sys_ps7/SPI0_MOSI_I
ad_connect  spi0_sdo_o sys_ps7/SPI0_MOSI_O
ad_connect  spi0_sdi_i sys_ps7/SPI0_MISO_I

# interrupts

ad_connect  sys_concat_intc/dout sys_ps7/IRQ_F2P
ad_connect  sys_concat_intc/In15 GND
ad_connect  sys_concat_intc/In14 GND
ad_connect  sys_concat_intc/In13 GND
ad_connect  sys_concat_intc/In12 GND
ad_connect  sys_concat_intc/In11 GND
ad_connect  sys_concat_intc/In10 GND
ad_connect  sys_concat_intc/In9 GND
ad_connect  sys_concat_intc/In8 GND
ad_connect  sys_concat_intc/In7 GND
ad_connect  sys_concat_intc/In6 GND
ad_connect  sys_concat_intc/In5 GND
ad_connect  sys_concat_intc/In4 GND
ad_connect  sys_concat_intc/In3 GND
ad_connect  sys_concat_intc/In2 GND
ad_connect  sys_concat_intc/In1 GND
ad_connect  sys_concat_intc/In0 GND

# ad9361
if {[info exists libre] || [info exists fishball]} {
create_bd_port -dir I rx_clk_in_p
create_bd_port -dir I rx_clk_in_n
create_bd_port -dir I rx_frame_in_p
create_bd_port -dir I rx_frame_in_n
create_bd_port -dir I -from 5 -to 0 rx_data_in_p
create_bd_port -dir I -from 5 -to 0 rx_data_in_n

create_bd_port -dir O tx_clk_out_p
create_bd_port -dir O tx_clk_out_n
create_bd_port -dir O tx_frame_out_p
create_bd_port -dir O tx_frame_out_n
create_bd_port -dir O -from 5 -to 0 tx_data_out_p
create_bd_port -dir O -from 5 -to 0 tx_data_out_n

} else {
create_bd_port -dir I rx_clk_in
create_bd_port -dir I rx_frame_in
create_bd_port -dir I -from 11 -to 0 rx_data_in

create_bd_port -dir O tx_clk_out
create_bd_port -dir O tx_frame_out
create_bd_port -dir O -from 11 -to 0 tx_data_out
}
create_bd_port -dir O enable
create_bd_port -dir O txnrx
create_bd_port -dir I up_enable
create_bd_port -dir I up_txnrx

# ad9361 core(s)

ad_ip_instance axi_ad9361 axi_ad9361
ad_ip_parameter axi_ad9361 CONFIG.ID 0
#LVDS OR CMOS
if { [info exists fishball]} {
ad_ip_parameter axi_ad9361 CONFIG.CMOS_OR_LVDS_N 0
ad_ip_parameter axi_ad9361 CONFIG.MODE_1R1T 0
ad_ip_parameter axi_ad9361 CONFIG.ADC_INIT_DELAY 30
} else {
ad_ip_parameter axi_ad9361 CONFIG.CMOS_OR_LVDS_N 1
ad_ip_parameter axi_ad9361 CONFIG.MODE_1R1T 0
ad_ip_parameter axi_ad9361 CONFIG.ADC_INIT_DELAY 21
}

if {[info exists libre] } {
ad_ip_parameter axi_ad9361 CONFIG.CMOS_OR_LVDS_N 0
ad_ip_parameter axi_ad9361 CONFIG.MODE_1R1T 0
ad_ip_parameter axi_ad9361 CONFIG.ADC_INIT_DELAY 21
}



# parameters to reduce size
ad_ip_parameter axi_ad9361 CONFIG.TDD_DISABLE 1
ad_ip_parameter axi_ad9361 CONFIG.DAC_DDS_DISABLE 1
	
if {![info exists maia_iio]} {
	ad_ip_parameter axi_ad9361 CONFIG.ADC_USERPORTS_DISABLE 0
	ad_ip_parameter axi_ad9361 CONFIG.ADC_DCFILTER_DISABLE 0
	ad_ip_parameter axi_ad9361 CONFIG.ADC_IQCORRECTION_DISABLE 0
	ad_ip_parameter axi_ad9361 CONFIG.DAC_USERPORTS_DISABLE 0
	ad_ip_parameter axi_ad9361 CONFIG.DAC_IQCORRECTION_DISABLE 0
}
# Maia SDR core

if {[info exists maia_iio]} {
	if { [info exists fishball]} {
	ad_ip_instance maia_sdr_maia_iio maia_sdr
	} else {
		ad_ip_instance maia_sdr_maia_iio_lite maia_sdr
	}
} else {
	ad_ip_instance maia_sdr_default maia_sdr
}

ad_ip_instance xlslice adc_i_slice
ad_ip_parameter adc_i_slice CONFIG.DIN_WIDTH 16
ad_ip_parameter adc_i_slice CONFIG.DOUT_WIDTH 12
ad_ip_parameter adc_i_slice CONFIG.DIN_FROM 11

ad_ip_instance xlslice adc_q_slice
ad_ip_parameter adc_q_slice CONFIG.DIN_TO 0
ad_ip_parameter adc_q_slice CONFIG.DIN_WIDTH 16
ad_ip_parameter adc_q_slice CONFIG.DOUT_WIDTH 12
ad_ip_parameter adc_q_slice CONFIG.DIN_FROM 11

# Maia SDR clocking
# https://analogdevicesinc.github.io/hdl/projects/fmcomms2/index.html
# FixMe : surely need a FIFO for DAC and ADC
# https://analogdevicesinc.github.io/hdl/library/util_rfifo/index.html#util-rfifo
# interface clock divider to generate sampling clock
# interface runs at 4x in 2r2t mode, and 2x in 1r1t mode

ad_ip_instance xlconcat util_ad9361_divclk_sel_concat
ad_ip_parameter util_ad9361_divclk_sel_concat CONFIG.NUM_PORTS 2
ad_connect axi_ad9361/adc_r1_mode util_ad9361_divclk_sel_concat/In0
ad_connect axi_ad9361/dac_r1_mode util_ad9361_divclk_sel_concat/In1

ad_ip_instance util_reduced_logic util_ad9361_divclk_sel
ad_ip_parameter util_ad9361_divclk_sel CONFIG.C_SIZE 2

ad_connect util_ad9361_divclk_sel_concat/dout util_ad9361_divclk_sel/Op1

ad_ip_instance util_clkdiv util_ad9361_divclk
if {[info exists LVDS_ENABLE]} {
ad_ip_parameter util_ad9361_divclk CONFIG.SEL_0_DIV 4
ad_ip_parameter util_ad9361_divclk CONFIG.SEL_1_DIV 2
} else {
ad_ip_parameter util_ad9361_divclk CONFIG.SEL_0_DIV 2
ad_ip_parameter util_ad9361_divclk CONFIG.SEL_1_DIV 1
}

ad_connect util_ad9361_divclk_sel/Res util_ad9361_divclk/clk_sel
ad_connect axi_ad9361/l_clk util_ad9361_divclk/clk

# resets at divided clock

ad_ip_instance proc_sys_reset util_ad9361_divclk_reset
ad_connect sys_rstgen/peripheral_aresetn util_ad9361_divclk_reset/ext_reset_in
ad_connect util_ad9361_divclk/clk_out util_ad9361_divclk_reset/slowest_sync_clk

# adc-path wfifo

ad_ip_instance util_wfifo util_ad9361_adc_fifo
ad_ip_parameter util_ad9361_adc_fifo CONFIG.NUM_OF_CHANNELS 4
ad_ip_parameter util_ad9361_adc_fifo CONFIG.DIN_ADDRESS_WIDTH 4
ad_ip_parameter util_ad9361_adc_fifo CONFIG.DIN_DATA_WIDTH 16
ad_ip_parameter util_ad9361_adc_fifo CONFIG.DOUT_DATA_WIDTH 16
ad_connect axi_ad9361/l_clk util_ad9361_adc_fifo/din_clk
ad_connect axi_ad9361/rst util_ad9361_adc_fifo/din_rst
ad_connect util_ad9361_divclk/clk_out util_ad9361_adc_fifo/dout_clk
ad_connect util_ad9361_divclk_reset/peripheral_aresetn util_ad9361_adc_fifo/dout_rstn
ad_connect axi_ad9361/adc_enable_i0 util_ad9361_adc_fifo/din_enable_0
ad_connect axi_ad9361/adc_valid_i0 util_ad9361_adc_fifo/din_valid_0
ad_connect axi_ad9361/adc_data_i0 util_ad9361_adc_fifo/din_data_0
ad_connect axi_ad9361/adc_enable_q0 util_ad9361_adc_fifo/din_enable_1
ad_connect axi_ad9361/adc_valid_q0 util_ad9361_adc_fifo/din_valid_1
ad_connect axi_ad9361/adc_data_q0 util_ad9361_adc_fifo/din_data_1
ad_connect axi_ad9361/adc_enable_i1 util_ad9361_adc_fifo/din_enable_2
ad_connect axi_ad9361/adc_valid_i1 util_ad9361_adc_fifo/din_valid_2
ad_connect axi_ad9361/adc_data_i1 util_ad9361_adc_fifo/din_data_2
ad_connect axi_ad9361/adc_enable_q1 util_ad9361_adc_fifo/din_enable_3
ad_connect axi_ad9361/adc_valid_q1 util_ad9361_adc_fifo/din_valid_3
ad_connect axi_ad9361/adc_data_q1 util_ad9361_adc_fifo/din_data_3
ad_connect util_ad9361_adc_fifo/din_ovf axi_ad9361/adc_dovf

# dac-path rfifo

ad_ip_instance util_rfifo axi_ad9361_dac_fifo
ad_ip_parameter axi_ad9361_dac_fifo CONFIG.DIN_DATA_WIDTH 16
ad_ip_parameter axi_ad9361_dac_fifo CONFIG.DOUT_DATA_WIDTH 16
ad_ip_parameter axi_ad9361_dac_fifo CONFIG.DIN_ADDRESS_WIDTH 4
ad_connect axi_ad9361/l_clk axi_ad9361_dac_fifo/dout_clk
ad_connect axi_ad9361/rst axi_ad9361_dac_fifo/dout_rst
ad_connect util_ad9361_divclk/clk_out axi_ad9361_dac_fifo/din_clk
ad_connect util_ad9361_divclk_reset/peripheral_aresetn axi_ad9361_dac_fifo/din_rstn
ad_connect axi_ad9361_dac_fifo/dout_enable_0 axi_ad9361/dac_enable_i0
ad_connect axi_ad9361_dac_fifo/dout_valid_0 axi_ad9361/dac_valid_i0
ad_connect axi_ad9361_dac_fifo/dout_data_0 axi_ad9361/dac_data_i0
ad_connect axi_ad9361_dac_fifo/dout_enable_1 axi_ad9361/dac_enable_q0
ad_connect axi_ad9361_dac_fifo/dout_valid_1 axi_ad9361/dac_valid_q0
ad_connect axi_ad9361_dac_fifo/dout_data_1 axi_ad9361/dac_data_q0
ad_connect axi_ad9361_dac_fifo/dout_enable_2 axi_ad9361/dac_enable_i1
ad_connect axi_ad9361_dac_fifo/dout_valid_2 axi_ad9361/dac_valid_i1
ad_connect axi_ad9361_dac_fifo/dout_data_2 axi_ad9361/dac_data_i1
ad_connect axi_ad9361_dac_fifo/dout_enable_3 axi_ad9361/dac_enable_q1
ad_connect axi_ad9361_dac_fifo/dout_valid_3 axi_ad9361/dac_valid_q1
ad_connect axi_ad9361_dac_fifo/dout_data_3 axi_ad9361/dac_data_q1
ad_connect axi_ad9361_dac_fifo/dout_unf axi_ad9361/dac_dunf



if {[info exists 122_Experiment]} {
	create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 maia_sdr_clk
set_property -dict [list CONFIG.USE_PHASE_ALIGNMENT {false} CONFIG.ENABLE_CLOCK_MONITOR {false} CONFIG.PRIM_SOURCE {Global_buffer} \
CONFIG.CLKOUT2_USED {true} CONFIG.CLKOUT3_USED {true} CONFIG.NUM_OUT_CLKS {3} \
   CONFIG.CLKOUT1_JITTER {260.522} \
  CONFIG.CLKOUT1_PHASE_ERROR {301.601} \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {80} \
  CONFIG.CLKOUT2_JITTER {235.916} \
  CONFIG.CLKOUT2_PHASE_ERROR {301.601} \
  CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {160} \
  CONFIG.CLKOUT3_JITTER {222.688} \
  CONFIG.CLKOUT3_PHASE_ERROR {301.601} \
  CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {240} \
  CONFIG.MMCM_CLKFBOUT_MULT_F {48.000} \
  CONFIG.MMCM_CLKOUT0_DIVIDE_F {12.000} \
  CONFIG.MMCM_CLKOUT1_DIVIDE {6}] [get_bd_cells maia_sdr_clk]
} else {
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 maia_sdr_clk
set_property -dict [list CONFIG.USE_PHASE_ALIGNMENT {false} CONFIG.ENABLE_CLOCK_MONITOR {false} CONFIG.PRIM_SOURCE {Global_buffer} \
                        CONFIG.CLKOUT2_USED {true} CONFIG.CLKOUT3_USED {true} CONFIG.NUM_OUT_CLKS {3} \
                        CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {62.500} CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {125.000} \
                        CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {187.5} \
                        CONFIG.PRIMITIVE {MMCM} CONFIG.MMCM_DIVCLK_DIVIDE {1} CONFIG.MMCM_CLKFBOUT_MULT_F {11.250} \
                        CONFIG.MMCM_CLKOUT0_DIVIDE_F {18.000} CONFIG.MMCM_CLKOUT1_DIVIDE {9} \
                        CONFIG.MMCM_CLKOUT3_DIVIDE {6} \
                        CONFIG.CLKOUT1_JITTER {133.663} CONFIG.CLKOUT1_PHASE_ERROR {91.100} \
                        CONFIG.CLKOUT2_JITTER {116.571} CONFIG.CLKOUT2_PHASE_ERROR {91.100} \
                        CONFIG.CLKOUT3_JITTER {108.217} CONFIG.CLKOUT3_PHASE_ERROR {91.100}] [get_bd_cells maia_sdr_clk]
}



# connections
if {[info exists libre] || [info exists fishball]} {
ad_connect  rx_clk_in_p axi_ad9361/rx_clk_in_p
ad_connect  rx_clk_in_n axi_ad9361/rx_clk_in_n
ad_connect  rx_frame_in_p axi_ad9361/rx_frame_in_p
ad_connect  rx_frame_in_n axi_ad9361/rx_frame_in_n
ad_connect  rx_data_in_p axi_ad9361/rx_data_in_p
ad_connect  rx_data_in_n axi_ad9361/rx_data_in_n
ad_connect  tx_clk_out_p axi_ad9361/tx_clk_out_p
ad_connect  tx_clk_out_n axi_ad9361/tx_clk_out_n
ad_connect  tx_frame_out_p axi_ad9361/tx_frame_out_p
ad_connect  tx_frame_out_n axi_ad9361/tx_frame_out_n
ad_connect  tx_data_out_p axi_ad9361/tx_data_out_p
ad_connect  tx_data_out_n axi_ad9361/tx_data_out_n
} else {
ad_connect  rx_clk_in axi_ad9361/rx_clk_in
ad_connect  rx_frame_in axi_ad9361/rx_frame_in
ad_connect  rx_data_in axi_ad9361/rx_data_in
ad_connect  tx_clk_out axi_ad9361/tx_clk_out
ad_connect  tx_frame_out axi_ad9361/tx_frame_out
ad_connect  tx_data_out axi_ad9361/tx_data_out
}
ad_connect  enable axi_ad9361/enable
ad_connect  txnrx axi_ad9361/txnrx
ad_connect  up_enable axi_ad9361/up_enable
ad_connect  up_txnrx axi_ad9361/up_txnrx

ad_connect  axi_ad9361/tdd_sync GND
ad_connect  sys_200m_clk axi_ad9361/delay_clk
ad_connect  axi_ad9361/l_clk axi_ad9361/clk

#ad_connect  axi_ad9361/adc_data_i0 adc_i_slice/Din
#ad_connect  axi_ad9361/adc_data_q0 adc_q_slice/Din
ad_connect  adc_i_slice/Dout maia_sdr/re_in
ad_connect  adc_q_slice/Dout maia_sdr/im_in

# https://github.com/analogdevicesinc/hdl/commit/bad4eb51a9397aab2a9a01b771b3cd181422e6f6
# https://wiki.analog.com/resources/eval/user-guides/ad-fmcomms2-ebz/interface_timing_validation
ad_connect maia_sdr/sampling_clk  util_ad9361_divclk/clk_out

ad_connect  sys_cpu_clk maia_sdr/s_axi_lite_clk
ad_connect  sys_cpu_reset maia_sdr/s_axi_lite_rst
ad_connect  maia_sdr_clk/clk_out1 maia_sdr/clk
ad_connect  maia_sdr_clk/clk_out2 maia_sdr/clk2x_clk
ad_connect  maia_sdr_clk/clk_out3 maia_sdr/clk3x_clk

ad_connect  sys_cpu_clk maia_sdr_clk/clk_in1
ad_connect  sys_cpu_reset maia_sdr_clk/reset

if {[info exists maia_iio]} {

	

	ad_ip_instance axi_dmac axi_ad9361_dac_dma
	ad_ip_parameter axi_ad9361_dac_dma CONFIG.DMA_TYPE_SRC 0
	ad_ip_parameter axi_ad9361_dac_dma CONFIG.DMA_TYPE_DEST 1
	ad_ip_parameter axi_ad9361_dac_dma CONFIG.CYCLIC 1
	ad_ip_parameter axi_ad9361_dac_dma CONFIG.AXI_SLICE_SRC 0
	ad_ip_parameter axi_ad9361_dac_dma CONFIG.AXI_SLICE_DEST 0
	ad_ip_parameter axi_ad9361_dac_dma CONFIG.DMA_2D_TRANSFER 0
	ad_ip_parameter axi_ad9361_dac_dma CONFIG.DMA_DATA_WIDTH_DEST 64

	ad_ip_instance util_upack2 util_ad9361_dac_upack { \
  		NUM_OF_CHANNELS 4 \
  		SAMPLE_DATA_WIDTH 16 \
	}

	for {set i 0} {$i < 4} {incr i} {
  #ad_connect util_ad9361_dac_upack/enable_$i axi_ad9361_dac_fifo/din_enable_$i
  ad_connect util_ad9361_dac_upack/fifo_rd_valid axi_ad9361_dac_fifo/din_valid_in_$i
  #ad_connect util_ad9361_dac_upack/fifo_rd_data_$i axi_ad9361_dac_fifo/din_data_$i
}

	ad_ip_instance axi_dmac axi_ad9361_adc_dma
	ad_ip_parameter axi_ad9361_adc_dma CONFIG.DMA_TYPE_SRC 2
	ad_ip_parameter axi_ad9361_adc_dma CONFIG.DMA_TYPE_DEST 0
	ad_ip_parameter axi_ad9361_adc_dma CONFIG.CYCLIC 0
	ad_ip_parameter axi_ad9361_adc_dma CONFIG.SYNC_TRANSFER_START 0
	ad_ip_parameter axi_ad9361_adc_dma CONFIG.AXI_SLICE_SRC 0
	ad_ip_parameter axi_ad9361_adc_dma CONFIG.AXI_SLICE_DEST 0
	ad_ip_parameter axi_ad9361_adc_dma CONFIG.DMA_2D_TRANSFER 0
	ad_ip_parameter axi_ad9361_adc_dma CONFIG.DMA_DATA_WIDTH_SRC 64

	ad_ip_instance util_cpack2 util_ad9361_adc_pack { \
  NUM_OF_CHANNELS 4 \
  SAMPLE_DATA_WIDTH 16 \
}
ad_connect util_ad9361_divclk/clk_out util_ad9361_adc_pack/clk
ad_connect util_ad9361_divclk_reset/peripheral_reset util_ad9361_adc_pack/reset

#Go through FIR -> remove this link
#ad_connect util_ad9361_adc_fifo/dout_valid_0 util_ad9361_adc_pack/fifo_wr_en

ad_connect util_ad9361_adc_pack/fifo_wr_overflow util_ad9361_adc_fifo/dout_ovf

# for {set i 0} {$i < 4} {incr i} {
#  ad_connect util_ad9361_adc_fifo/dout_enable_$i util_ad9361_adc_pack/enable_$i
#  ad_connect util_ad9361_adc_fifo/dout_data_$i util_ad9361_adc_pack/fifo_wr_data_$i
# }

	
ad_connect util_ad9361_adc_fifo/dout_data_0 adc_i_slice/Din
ad_connect util_ad9361_adc_fifo/dout_data_1 adc_q_slice/Din

ad_connect util_ad9361_adc_fifo/dout_enable_0 util_ad9361_adc_pack/enable_0
ad_connect util_ad9361_adc_fifo/dout_enable_2 util_ad9361_adc_pack/enable_2
	

ad_connect axi_ad9361_adc_dma/fifo_wr util_ad9361_adc_pack/packed_fifo_wr	
	
	ad_connect util_ad9361_divclk/clk_out util_ad9361_dac_upack/clk
	ad_connect util_ad9361_divclk_reset/peripheral_reset util_ad9361_dac_upack/reset
	
	ad_connect util_ad9361_divclk/clk_out axi_ad9361_dac_dma/m_axis_aclk
	ad_connect util_ad9361_dac_upack/s_axis  axi_ad9361_dac_dma/m_axis

	ad_ip_instance util_vector_logic logic_or [list \
	  C_OPERATION {or} \
	  C_SIZE 1]

	
	#ad_connect  logic_or/Op1  axi_ad9361/dac_valid_i0
	#ad_connect  logic_or/Op2  axi_ad9361/dac_valid_i1
	#ad_connect  logic_or/Res  util_ad9361_dac_upack/fifo_rd_en
	ad_connect axi_ad9361_dac_fifo/dout_valid_out_0 util_ad9361_dac_upack/fifo_rd_en

	ad_connect util_ad9361_dac_upack/fifo_rd_underflow axi_ad9361_dac_fifo/din_unf

	ad_connect  util_ad9361_divclk/clk_out axi_ad9361_adc_dma/fifo_wr_clk
	
	

	#ad_connect util_ad9361_divclk/clk_out axi_ad9361_adc_dma/fifo_wr_clk
	#ad_connect util_ad9361_divclk/clk_out axi_ad9361_dac_dma/m_axis_aclk

	

	ad_connect sys_cpu_resetn axi_ad9361_adc_dma/m_dest_axi_aresetn
	ad_connect sys_cpu_resetn axi_ad9361_dac_dma/m_src_axi_aresetn
}
# interconnects

ad_cpu_interconnect 0x79020000 axi_ad9361
if {[info exists maia_iio]} {
	ad_cpu_interconnect 0x7C460000 maia_sdr
	ad_cpu_interconnect 0x7C400000 axi_ad9361_adc_dma
	ad_cpu_interconnect 0x7C420000 axi_ad9361_dac_dma
} else {
	ad_cpu_interconnect 0x7C400000 maia_sdr
}
if {[info exists e200]} {
	ad_cpu_interconnect 0x43C00000 axi_vcxo_ctrl
}
if {[info exists libre-e200style]} {
	ad_cpu_interconnect 0x43C00000 axi_vcxo_ctrl
}
ad_ip_parameter sys_ps7 CONFIG.PCW_USE_S_AXI_HP1 {1}
ad_connect maia_sdr_clk/clk_out1 sys_ps7/S_AXI_HP1_ACLK
ad_connect maia_sdr/m_axi_spectrometer sys_ps7/S_AXI_HP1

ad_ip_parameter sys_ps7 CONFIG.PCW_USE_S_AXI_HP2 {1}
if {[info exists maia_iio]} {
	ad_mem_hp2_interconnect sys_cpu_clk sys_ps7/S_AXI_HP2
	ad_mem_hp2_interconnect sys_cpu_clk maia_sdr/m_axi_recorder
	ad_mem_hp2_interconnect sys_cpu_clk axi_ad9361_adc_dma/m_dest_axi
	ad_mem_hp2_interconnect sys_cpu_clk axi_ad9361_dac_dma/m_src_axi
} else {
	ad_connect sys_cpu_clk sys_ps7/S_AXI_HP2_ACLK
	ad_connect maia_sdr/m_axi_recorder sys_ps7/S_AXI_HP2
	create_bd_addr_seg -range 0x20000000 -offset 0x00000000 \
		            [get_bd_addr_spaces maia_sdr/m_axi_recorder] \
		            [get_bd_addr_segs sys_ps7/S_AXI_HP2/HP2_DDR_LOWOCM] \
		            SEG_sys_ps7_HP2_DDR_LOWOCM
}

# Raw complex capture and continuous I/Q waterfall DMA masters (maia_iio
# builds). The I/Q master runs on the maia_sdr clock (HP0, with its own reset
# generator so the 62.5 MHz domain does not take the CPU-clock reset
# unsynchronized); the raw capture master runs in the s_axi_lite (CPU) clock
# domain (HP3). The ad_mem_hpx_interconnect helper only attaches a master when
# its HP interconnect already exists, so the first call for each port names
# the PS port itself. Its reset net is derived from the clock net name
# (clk -> resetn), hence the net name maia_clk. The other builds leave the
# two masters unconnected.
if {[info exists maia_iio]} {
	set maia_clk_net [get_bd_nets -of_objects [get_bd_pins maia_sdr/clk]]
	set_property NAME maia_clk $maia_clk_net
	ad_ip_instance proc_sys_reset maia_clk_rstgen
	ad_connect maia_clk maia_clk_rstgen/slowest_sync_clk
	ad_connect maia_sdr_clk/locked maia_clk_rstgen/dcm_locked
	connect_bd_net [get_bd_pins sys_ps7/FCLK_RESET0_N] [get_bd_pins maia_clk_rstgen/ext_reset_in]
	create_bd_net maia_resetn
	connect_bd_net -net maia_resetn [get_bd_pins maia_clk_rstgen/peripheral_aresetn]
	ad_mem_hpx_interconnect "HP0" maia_clk sys_ps7/S_AXI_HP0
	ad_mem_hpx_interconnect "HP0" maia_clk maia_sdr/m_axi_spectrometer_iq
	ad_mem_hpx_interconnect "HP3" sys_cpu_clk sys_ps7/S_AXI_HP3
	ad_mem_hpx_interconnect "HP3" sys_cpu_clk maia_sdr/m_axi_spectrometer_raw
}

create_bd_addr_seg -range 0x20000000 -offset 0x00000000 \
                    [get_bd_addr_spaces maia_sdr/m_axi_spectrometer] \
                    [get_bd_addr_segs sys_ps7/S_AXI_HP1/HP1_DDR_LOWOCM] \
                    SEG_sys_ps7_HP1_DDR_LOWOCM


# interrupts
if {[info exists maia_iio]} {
	ad_cpu_interrupt ps-13 mb-13 axi_ad9361_adc_dma/irq
	ad_cpu_interrupt ps-12 mb-12 axi_ad9361_dac_dma/irq
	ad_cpu_interrupt ps-11 mb-11 maia_sdr/interrupt_out
} else {
	ad_cpu_interrupt ps-13 mb-13 maia_sdr/interrupt_out
}




if {[info exists maia_iio]} {

	# ======================= 8BITS RX OUT  ============================
	add_files -norecurse  ../pluto/cs12_cs8.v
	create_bd_cell -type module -reference cs12_cs8 rxcs12_cs8
	#ad_connect axi_ad9361/adc_data_i0 rxcs12_cs8/sample_in1
	#ad_connect axi_ad9361/adc_data_q0 rxcs12_cs8/sample_in2
	
	#Mux select CS8
	#Select input depending on qo_enable
	ad_ip_instance util_vector_logic logic_no_q0 [list \
	  C_OPERATION {not} \
	  C_SIZE 1]
	ad_connect util_ad9361_adc_fifo/dout_enable_1 logic_no_q0/Op1
	#ad_ip_instance ad_bus_mux muxcs8 -> DOESNT WORK , USE create_bd_cell instead
	add_files -norecurse  ../../adi-hdl/library/common/ad_bus_mux.v
	create_bd_cell -type module -reference ad_bus_mux muxcs8
	ad_connect muxcs8/select_path logic_no_q0/Res

	#First input CS16 - > I0 -> I0
	ad_connect util_ad9361_adc_fifo/dout_enable_0 muxcs8/enable_in_0

	#Second input CS8 - > I0+Q0
	ad_connect GND muxcs8/enable_in_1

	#OUT
	ad_connect muxcs8/valid_out util_ad9361_adc_pack/fifo_wr_en
	ad_connect muxcs8/data_out util_ad9361_adc_pack/fifo_wr_data_0
	ad_connect muxcs8/enable_out util_ad9361_adc_pack/enable_1

	# ======================= 8BITS TX OUT  ============================
	# I PART
	ad_ip_instance xlslice shiftsliceitx
	ad_ip_parameter shiftsliceitx CONFIG.DIN_WIDTH 16
	ad_ip_parameter shiftsliceitx CONFIG.DIN_FROM 15
	ad_ip_parameter shiftsliceitx CONFIG.DIN_TO 8
	ad_ip_parameter shiftsliceitx CONFIG.DOUT_WIDTH 8
	ad_connect util_ad9361_dac_upack/fifo_rd_data_0 shiftsliceitx/Din
	
	ad_ip_instance xlconcat concatslicetx_i

	
	ad_ip_parameter concatslicetx_i CONFIG.NUM_PORTS 2
	ad_ip_parameter concatslicetx_i CONFIG.IN0_WIDTH 8
	ad_ip_parameter concatslicetx_i CONFIG.IN1_WIDTH 8
	

	ad_connect shiftsliceitx/Dout concatslicetx_i/In1
	
	# Q PART
	ad_ip_instance xlslice shiftsliceqtx
	ad_ip_parameter shiftsliceqtx CONFIG.DIN_WIDTH 16
	ad_ip_parameter shiftsliceqtx CONFIG.DIN_FROM 7
	ad_ip_parameter shiftsliceqtx CONFIG.DIN_TO 0
	ad_ip_parameter shiftsliceqtx CONFIG.DOUT_WIDTH 8
	ad_connect util_ad9361_dac_upack/fifo_rd_data_0 shiftsliceqtx/Din

	ad_ip_instance xlconcat concatslicetx_q
	ad_ip_parameter concatslicetx_q CONFIG.NUM_PORTS 2
	ad_ip_parameter concatslicetx_q CONFIG.IN0_WIDTH 8
	ad_ip_parameter concatslicetx_q CONFIG.IN1_WIDTH 8

	ad_connect shiftsliceqtx/Dout concatslicetx_q/In1

	ad_ip_instance util_vector_logic logic_no_q0_tx [list \
	  C_OPERATION {not} \
	  C_SIZE 1]
	ad_connect axi_ad9361_dac_fifo/din_enable_0 logic_no_q0_tx/Op1

	#Select input depending on dac_qo_enable
	# *****  I PART **********

	create_bd_cell -type module -reference ad_bus_mux muxcs8_tx_i

	ad_connect muxcs8_tx_i/select_path logic_no_q0_tx/Res
	ad_connect muxcs8_tx_i/enable_in_0 axi_ad9361_dac_fifo/din_enable_0
	#First input CS16 - > I0 -> I0
	ad_connect util_ad9361_dac_upack/fifo_rd_data_0 muxcs8_tx_i/data_in_0
	#Second input C8 - > CS16 > I0
	ad_connect concatslicetx_i/Dout muxcs8_tx_i/data_in_1
	ad_connect muxcs8_tx_i/enable_in_1 axi_ad9361_dac_fifo/din_enable_0

	#OUT if not fir
	# ad_connect muxcs8_tx_i/data_out axi_ad9361_dac_fifo/din_data_0

	ad_connect muxcs8_tx_i/enable_out util_ad9361_dac_upack/enable_0

	#Select input depending on dac_qo_enable
	# *****  Q PART **********

	create_bd_cell -type module -reference ad_bus_mux muxcs8_tx_q

	ad_connect muxcs8_tx_q/select_path logic_no_q0_tx/Res
	ad_connect muxcs8_tx_q/enable_in_0 axi_ad9361_dac_fifo/din_enable_1
	#First input CS16 - > I0 -> I0
	ad_connect util_ad9361_dac_upack/fifo_rd_data_1 muxcs8_tx_q/data_in_0
	#Second input C8 - > CS16 > I0
	ad_connect concatslicetx_q/Dout muxcs8_tx_q/data_in_1
	#ad_connect muxcs8_tx_q/enable_in_1 axi_ad9361_dac_fifo/din_enable_0
	ad_connect muxcs8_tx_q/enable_in_1 axi_ad9361_dac_fifo/din_enable_1

	#OUT without fir
	#ad_connect muxcs8_tx_q/data_out axi_ad9361_dac_fifo/din_data_1
	ad_connect muxcs8_tx_q/enable_out util_ad9361_dac_upack/enable_1

	# ******************************************************************
	#                       2ND CHANNEL 
	#

	# ======================= 8BITS RX2 OUT  ============================
	
	
	create_bd_cell -type module -reference cs12_cs8 rxcs22_cs8
	ad_connect util_ad9361_adc_fifo/dout_data_2 rxcs22_cs8/sample_in1
	ad_connect util_ad9361_adc_fifo/dout_data_3 rxcs22_cs8/sample_in2
	
	#Mux select CS8
	#Select input depending on qo_enable
	ad_ip_instance util_vector_logic logic_no_q1 [list \
	  C_OPERATION {not} \
	  C_SIZE 1]
	ad_connect util_ad9361_adc_fifo/dout_enable_3 logic_no_q1/Op1

	create_bd_cell -type module -reference ad_bus_mux muxcs8_2
	ad_connect muxcs8_2/select_path logic_no_q1/Res

	#First input CS16 - > I0 -> I0
	ad_connect util_ad9361_adc_fifo/dout_data_2 muxcs8_2/data_in_0
	ad_connect util_ad9361_adc_fifo/dout_valid_2 muxcs8_2/valid_in_0
	ad_connect util_ad9361_adc_fifo/dout_enable_3 muxcs8_2/enable_in_0

	#Second input CS8 - > I0+Q0
	ad_connect rxcs22_cs8/combined_out muxcs8_2/data_in_1
	ad_connect util_ad9361_adc_fifo/dout_valid_2 muxcs8_2/valid_in_1
	ad_connect GND muxcs8_2/enable_in_1

	#OUT
	ad_connect util_ad9361_adc_fifo/dout_data_3 util_ad9361_adc_pack/fifo_wr_data_3
	ad_connect muxcs8_2/data_out util_ad9361_adc_pack/fifo_wr_data_2
	ad_connect muxcs8_2/enable_out util_ad9361_adc_pack/enable_3

	# ======================= 8BITS TX2 OUT  ============================
	# I PART
	ad_ip_instance xlslice shiftsliceitx2
	ad_ip_parameter shiftsliceitx2 CONFIG.DIN_WIDTH 16
	ad_ip_parameter shiftsliceitx2 CONFIG.DIN_FROM 15
	ad_ip_parameter shiftsliceitx2 CONFIG.DIN_TO 8
	ad_ip_parameter shiftsliceitx2 CONFIG.DOUT_WIDTH 8
	ad_connect util_ad9361_dac_upack/fifo_rd_data_2 shiftsliceitx2/Din

	ad_ip_instance xlconcat concatslicetx_i2

	ad_ip_parameter concatslicetx_i2 CONFIG.NUM_PORTS 3
	ad_ip_parameter concatslicetx_i2 CONFIG.IN0_WIDTH 4
	ad_ip_parameter concatslicetx_i2 CONFIG.IN1_WIDTH 8
	ad_ip_parameter concatslicetx_i2 CONFIG.IN2_WIDTH 4

	ad_connect shiftsliceitx2/Dout concatslicetx_i2/In1

	# Q PART
	ad_ip_instance xlslice shiftsliceqtx2
	ad_ip_parameter shiftsliceqtx2 CONFIG.DIN_WIDTH 16
	ad_ip_parameter shiftsliceqtx2 CONFIG.DIN_FROM 7
	ad_ip_parameter shiftsliceqtx2 CONFIG.DIN_TO 0
	ad_ip_parameter shiftsliceqtx2 CONFIG.DOUT_WIDTH 8
	ad_connect util_ad9361_dac_upack/fifo_rd_data_2 shiftsliceqtx2/Din

	ad_ip_instance xlconcat concatslicetx_q2
	ad_ip_parameter concatslicetx_q2 CONFIG.NUM_PORTS 3
	ad_ip_parameter concatslicetx_q2 CONFIG.IN0_WIDTH 4
	ad_ip_parameter concatslicetx_q2 CONFIG.IN1_WIDTH 8
	ad_ip_parameter concatslicetx_q2 CONFIG.IN2_WIDTH 4

	ad_connect shiftsliceqtx2/Dout concatslicetx_q2/In1

	ad_ip_instance util_vector_logic logic_no_q0_tx2 [list \
	  C_OPERATION {not} \
	  C_SIZE 1]
	ad_connect axi_ad9361_dac_fifo/din_enable_3 logic_no_q0_tx2/Op1


	#Select input depending on dac_qo_enable
	# *****  I PART **********
	create_bd_cell -type module -reference ad_bus_mux muxcs8_tx_i2

	ad_connect muxcs8_tx_i2/select_path logic_no_q0_tx2/Res
	ad_connect muxcs8_tx_i2/enable_in_0 axi_ad9361_dac_fifo/din_enable_2
	#First input CS16 - > I0 -> I0
	ad_connect util_ad9361_dac_upack/fifo_rd_data_2 muxcs8_tx_i2/data_in_0
	#Second input C8 - > CS16 > I0
	ad_connect concatslicetx_i2/Dout muxcs8_tx_i2/data_in_1
	ad_connect muxcs8_tx_i2/enable_in_1 axi_ad9361_dac_fifo/din_enable_3

	#OUT
	#ad_connect muxcs8_tx_i2/data_out axi_ad9361_dac_fifo/din_data_2
	ad_connect muxcs8_tx_i2/enable_out util_ad9361_dac_upack/enable_2

	#Select input depending on dac_qo_enable
	# *****  Q PART **********
	create_bd_cell -type module -reference ad_bus_mux muxcs8_tx_q2

	ad_connect muxcs8_tx_q2/select_path logic_no_q0_tx2/Res
	ad_connect muxcs8_tx_q2/enable_in_0 axi_ad9361_dac_fifo/din_enable_3
	#First input CS16 - > I0 -> I0	
	ad_connect util_ad9361_dac_upack/fifo_rd_data_3 muxcs8_tx_q2/data_in_0
	#Second input C8 - > CS16 > I0
	ad_connect concatslicetx_q2/Dout muxcs8_tx_q2/data_in_1
	ad_connect muxcs8_tx_q2/enable_in_1 axi_ad9361_dac_fifo/din_enable_2

	#OUT
	#ad_connect muxcs8_tx_q2/data_out axi_ad9361_dac_fifo/din_data_3
	ad_connect muxcs8_tx_q2/enable_out util_ad9361_dac_upack/enable_3


	###### SWEEPER ###########
	#add_files -norecurse  ../pluto/sweeper.v
	add_files -norecurse  ../pluto/sweeper_it.v
	create_bd_cell -type module -reference sweeper_it sweeper_io
	ad_connect sweeper_io/clk maia_sdr/clk_fastlock_out
	#ad_connect sweeper_io/clk axi_ad9361/l_clk
	ad_connect sweeper_io/reset axi_ad9361/rst
	ad_connect sweeper_io/profile_o maia_sdr/fastlock_profile_in
	ad_ip_instance util_vector_logic logic_orgpio [list \
	  C_OPERATION {or} \
	  C_SIZE 14 ]
	ad_connect logic_orgpio/Res gpio_o
	ad_connect sweeper_io/gpio_o logic_orgpio/Op1
	ad_connect sys_ps7/GPIO_O logic_orgpio/Op2


	### TX FIR INTERPOLATOR ######
	
	if {[info exists with_tx_fir]} {
		#delete_bd_objs [get_bd_nets -of_objects [find_bd_objs -relation connected_to [get_bd_pins axi_ad9361_dac_fifo/din_data_0]]]	
		#delete_bd_objs [get_bd_nets -of_objects [find_bd_objs -relation connected_to [get_bd_pins axi_ad9361_dac_fifo/din_data_1]]]	   
		delete_bd_objs [get_bd_nets -of_objects [find_bd_objs -relation connected_to [get_bd_pins logic_or/Op1]]]
		delete_bd_objs [get_bd_nets -of_objects [find_bd_objs -relation connected_to [get_bd_pins logic_or/Op2]]]	   	   
		delete_bd_objs [get_bd_nets -of_objects [find_bd_objs -relation connected_to [get_bd_pins util_ad9361_dac_upack/fifo_rd_en]]]	   
		#ad_add_interpolation_filter "tx_fir_interpolator" 8 2 1 {61.44} {7.68} \
		#							"$ad_hdl_dir/library/util_fir_int/coefile_int.coe"

		ad_add_interpolation_filter "tx_fir_interpolator" 32 2 1 {61.44} {1.92} \
                             "$ad_hdl_dir/../projects/pluto/firinterp32.coe"

		ad_ip_instance xlslice interp_slice
		
		ad_connect util_ad9361_divclk/clk_out tx_fir_interpolator/aclk

		ad_connect muxcs8_tx_i/enable_out tx_fir_interpolator/dac_enable_0
		#ad_connect axi_ad9361_dac_fifo/dout_valid_out_0 tx_fir_interpolator/dac_valid_0
		ad_connect axi_ad9361_dac_fifo/din_valid_0 tx_fir_interpolator/dac_valid_0
		ad_connect muxcs8_tx_i/data_out tx_fir_interpolator/data_in_0
		ad_connect muxcs8_tx_q/enable_out tx_fir_interpolator/dac_enable_1
		#ad_connect axi_ad9361_dac_fifo/dout_valid_out_1 tx_fir_interpolator/dac_valid_1
		ad_connect axi_ad9361_dac_fifo/din_valid_1 tx_fir_interpolator/dac_valid_1
		ad_connect muxcs8_tx_q/data_out tx_fir_interpolator/data_in_1

		ad_connect axi_ad9361/up_dac_gpio_out interp_slice/Din
		ad_connect  tx_fir_interpolator/active interp_slice/Dout
		#ad_connect  logic_or/Op1  tx_fir_interpolator/valid_out_0
		ad_connect  tx_fir_interpolator/valid_out_0 util_ad9361_dac_upack/fifo_rd_en
		ad_connect axi_ad9361_dac_fifo/din_data_0 tx_fir_interpolator/data_out_0
		ad_connect axi_ad9361_dac_fifo/din_data_1 tx_fir_interpolator/data_out_1
	}
	if {[info exists with_tx_fir_custom]} {
		delete_bd_objs [get_bd_nets -of_objects [find_bd_objs -relation connected_to [get_bd_pins axi_ad9361/dac_data_i0]]]	
		delete_bd_objs [get_bd_nets -of_objects [find_bd_objs -relation connected_to [get_bd_pins axi_ad9361/dac_data_q0]]]	   
		delete_bd_objs [get_bd_nets -of_objects [find_bd_objs -relation connected_to [get_bd_pins logic_or/Op1]]]
		delete_bd_objs [get_bd_nets -of_objects [find_bd_objs -relation connected_to [get_bd_pins logic_or/Op2]]]	   	   
		delete_bd_objs [get_bd_nets -of_objects [find_bd_objs -relation connected_to [get_bd_pins util_ad9361_dac_upack/fifo_rd_en]]]


		set rrc_2interpol [ create_bd_cell -type ip -vlnv xilinx.com:ip:fir_compiler:7.2 rrc_2interpol ]
set_property -dict [ list \
   CONFIG.Clock_Frequency {61.44} \
   CONFIG.CoefficientSource {COE_File} \
   CONFIG.Coefficient_File {../../../../../../../pluto/coefile_int.coe} \
   CONFIG.Coefficient_Fractional_Bits {0} \
   CONFIG.Coefficient_Sets {1} \
   CONFIG.Coefficient_Sign {Signed} \
   CONFIG.Coefficient_Structure {Inferred} \
   CONFIG.Coefficient_Width {19} \
   CONFIG.ColumnConfig {8} \
   CONFIG.DATA_Has_TLAST {Not_Required} \
   CONFIG.Data_Fractional_Bits {0} \
   CONFIG.Decimation_Rate {1} \
   CONFIG.Filter_Architecture {Systolic_Multiply_Accumulate} \
   CONFIG.Filter_Type {Interpolation} \
   CONFIG.Interpolation_Rate {8} \
   CONFIG.M_DATA_Has_TREADY {true} \
   CONFIG.Number_Channels {1} \
   CONFIG.Number_Paths {2} \
   CONFIG.Output_Rounding_Mode {Symmetric_Rounding_to_Zero} \
   CONFIG.Output_Width {16} \
   CONFIG.Quantization {Integer_Coefficients} \
   CONFIG.RateSpecification {Frequency_Specification} \
   CONFIG.S_DATA_Has_FIFO {true} \
   CONFIG.Sample_Frequency {15.36} \
   CONFIG.Zero_Pack_Factor {1} \
 ] $rrc_2interpol
ad_connect  axi_ad9361/l_clk  rrc_2interpol/aclk 

		
	}
	#FIXME WITH FIFO
if {[info exists with_rx_fir]} {
			
	# TODO ; delete existing nodes
	#ad_connect axi_ad9361/adc_data_q0 util_ad9361_adc_pack/fifo_wr_data_1
	#ad_connect  logic_or/Op1  axi_ad9361/dac_valid_i0
	#ad_connect axi_ad9361/adc_data_i0 rxcs12_cs8/sample_in1
	#ad_connect axi_ad9361/adc_data_q0 rxcs12_cs8/sample_in2
	#ad_connect rxcs12_cs8/combined_out muxcs8/data_in_1
	#ad_connect axi_ad9361/adc_valid_i0 muxcs8/valid_in_1

	ad_add_decimation_filter "rx_fir_decimator" 8 2 1 {61.44} {61.44} \
                         "$ad_hdl_dir/library/util_fir_int/coefile_int.coe"
	ad_ip_instance xlslice decim_slice
	#ad_connect axi_ad9361/l_clk rx_fir_decimator/aclk
	ad_connect util_ad9361_divclk/clk_out rx_fir_decimator/aclk
	ad_connect axi_ad9361/up_adc_gpio_out decim_slice/Din
	ad_connect rx_fir_decimator/active decim_slice/Dout

	
	ad_connect util_ad9361_adc_fifo/dout_valid_0 rx_fir_decimator/valid_in_0
	ad_connect util_ad9361_adc_fifo/dout_enable_0 rx_fir_decimator/enable_in_0
	ad_connect util_ad9361_adc_fifo/dout_data_0 rx_fir_decimator/data_in_0
	ad_connect util_ad9361_adc_fifo/dout_valid_1 rx_fir_decimator/valid_in_1
	ad_connect util_ad9361_adc_fifo/dout_enable_1 rx_fir_decimator/enable_in_1
	ad_connect util_ad9361_adc_fifo/dout_data_1 rx_fir_decimator/data_in_1

	ad_connect rx_fir_decimator/data_out_0 muxcs8/data_in_0
	ad_connect rx_fir_decimator/valid_out_0 muxcs8/valid_in_0
	ad_connect rx_fir_decimator/valid_out_0 muxcs8/valid_in_1

	ad_connect rx_fir_decimator/data_out_0 rxcs12_cs8/sample_in1
	ad_connect rx_fir_decimator/data_out_1 rxcs12_cs8/sample_in2

	ad_connect rxcs12_cs8/combined_out muxcs8/data_in_1
	ad_connect rx_fir_decimator/data_out_1 util_ad9361_adc_pack/fifo_wr_data_1
	}	
}

if {[info exists with_rx_fir_maia]} {

	#In order to be controled by iio		
	ad_ip_instance xlslice decim_slice
	ad_connect axi_ad9361/up_adc_gpio_out decim_slice/Din

	
	

	
#I	
ad_ip_instance axis_data_fifo interclk_i
create_bd_cell -type module -reference ad_bus_mux mux_decim_i

ad_ip_parameter interclk_i CONFIG.FIFO_DEPTH 16
ad_ip_parameter interclk_i CONFIG.FIFO_MODE 1
ad_ip_parameter interclk_i CONFIG.IS_ACLK_ASYNC 1
ad_ip_parameter interclk_i CONFIG.HAS_TLAST.VALUE_SRC USER
ad_ip_parameter interclk_i CONFIG.HAS_TLAST 0
ad_ip_parameter interclk_i CONFIG.TDATA_NUM_BYTES 2
ad_ip_parameter interclk_i CONFIG.SYNCHRONIZATION_STAGES 4 

#ad_connect interclk_i/m_axis_aclk  axi_ad9361/l_clk 
ad_connect interclk_i/m_axis_aclk  util_ad9361_divclk/clk_out
ad_connect sys_cpu_resetn interclk_i/s_axis_aresetn 
ad_connect  maia_sdr/decim_re_out interclk_i/s_axis_tdata
ad_connect  maia_sdr_clk/clk_out1 interclk_i/s_axis_aclk
ad_connect  maia_sdr/decim_strobe_out interclk_i/s_axis_tvalid
ad_connect interclk_i/m_axis_tdata mux_decim_i/data_in_1
ad_connect interclk_i/m_axis_tvalid mux_decim_i/valid_in_1


	
	ad_connect mux_decim_i/select_path decim_slice/Dout
	ad_connect util_ad9361_adc_fifo/dout_valid_0 mux_decim_i/valid_in_0
	ad_connect util_ad9361_adc_fifo/dout_enable_0 mux_decim_i/enable_in_0
	ad_connect util_ad9361_adc_fifo/dout_data_0 mux_decim_i/data_in_0
	#ad_connect maia_sdr/decim_strobe_out mux_decim_i/valid_in_1
	ad_connect util_ad9361_adc_fifo/dout_enable_0 mux_decim_i/enable_in_1
	#ad_connect maia_sdr/decim_re_out mux_decim_i/data_in_1

#Q	
ad_ip_instance axis_data_fifo interclk_q
create_bd_cell -type module -reference ad_bus_mux mux_decim_q

ad_ip_parameter interclk_q CONFIG.FIFO_DEPTH 16
ad_ip_parameter interclk_q CONFIG.FIFO_MODE 1
ad_ip_parameter interclk_q CONFIG.IS_ACLK_ASYNC 1
ad_ip_parameter interclk_q CONFIG.HAS_TLAST.VALUE_SRC USER
ad_ip_parameter interclk_q CONFIG.HAS_TLAST 0
ad_ip_parameter interclk_q CONFIG.TDATA_NUM_BYTES 2
ad_ip_parameter interclk_q CONFIG.SYNCHRONIZATION_STAGES 4 

#ad_connect interclk_q/m_axis_aclk  axi_ad9361/l_clk 
ad_connect interclk_q/m_axis_aclk  util_ad9361_divclk/clk_out
ad_connect sys_cpu_resetn interclk_q/s_axis_aresetn 
ad_connect  maia_sdr/decim_im_out interclk_q/s_axis_tdata
ad_connect  maia_sdr_clk/clk_out1 interclk_q/s_axis_aclk
ad_connect  maia_sdr/decim_strobe_out interclk_q/s_axis_tvalid
ad_connect interclk_q/m_axis_tdata mux_decim_q/data_in_1
ad_connect interclk_q/m_axis_tvalid mux_decim_q/valid_in_1

	ad_connect mux_decim_q/select_path decim_slice/Dout
	ad_connect util_ad9361_adc_fifo/dout_valid_1 mux_decim_q/valid_in_0
	ad_connect util_ad9361_adc_fifo/dout_enable_1 mux_decim_q/enable_in_0
	ad_connect util_ad9361_adc_fifo/dout_data_1 mux_decim_q/data_in_0

	#ad_connect maia_sdr/decim_strobe_out mux_decim_q/valid_in_1
	ad_connect util_ad9361_adc_fifo/dout_enable_1 mux_decim_q/enable_in_1
	#ad_connect maia_sdr/decim_im_out mux_decim_q/data_in_1

	ad_connect mux_decim_i/data_out muxcs8/data_in_0
	ad_connect mux_decim_i/valid_out muxcs8/valid_in_0
	ad_connect mux_decim_i/valid_out muxcs8/valid_in_1

	ad_connect mux_decim_i/data_out rxcs12_cs8/sample_in1
	ad_connect mux_decim_q/data_out rxcs12_cs8/sample_in2

	ad_connect rxcs12_cs8/combined_out muxcs8/data_in_1
	ad_connect mux_decim_q/data_out util_ad9361_adc_pack/fifo_wr_data_1
		
}

