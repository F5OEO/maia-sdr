# constraints
# ad9361 (SWAP == 0x1)
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
#set_property  -dict {PACKAGE_PIN  L17 IOSTANDARD LVCMOS25} [get_ports gpio_ctl[2]]                     
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
# Even on 7010
set_property  -dict {PACKAGE_PIN  T19  IOSTANDARD LVCMOS25} [get_ports pad_5]

######################## BANK35 1V8 ##########################

set_property  -dict {PACKAGE_PIN  H16  IOSTANDARD LVCMOS25} [get_ports pad_12]
set_property  -dict {PACKAGE_PIN  H17  IOSTANDARD LVCMOS25} [get_ports pad_14]
set_property  -dict {PACKAGE_PIN  J18  IOSTANDARD LVCMOS25} [get_ports pad_8]
set_property  -dict {PACKAGE_PIN  H18  IOSTANDARD LVCMOS25} [get_ports pad_10]
set_property  -dict {PACKAGE_PIN  G19  IOSTANDARD LVCMOS25} [get_ports pad_4]
# set_property  -dict {PACKAGE_PIN  G20  IOSTANDARD LVCMOS25 PULLTYPE PULLDOWN} [get_ports pad_6]
# Fixme : maybe pulldown used for sync
set_property  -dict {PACKAGE_PIN  G20  IOSTANDARD LVCMOS25 } [get_ports pad_6]
set_property  -dict {PACKAGE_PIN  L14  IOSTANDARD LVCMOS25} [get_ports pad_16]
set_property  -dict {PACKAGE_PIN  L15  IOSTANDARD LVCMOS25} [get_ports pad_18]

# GPIO ONLY 7020
# BANK 13 3V3
set_property  -dict {PACKAGE_PIN  V10  IOSTANDARD LVCMOS33} [get_ports pad_7]
set_property  -dict {PACKAGE_PIN  U9  IOSTANDARD LVCMOS33} [get_ports pad_9]
set_property  -dict {PACKAGE_PIN  U10  IOSTANDARD LVCMOS33} [get_ports pad_11]
set_property  -dict {PACKAGE_PIN  T9  IOSTANDARD LVCMOS33} [get_ports pad_13]

create_clock -name clk_fpga_0 -period 10 [get_pins "i_system_wrapper/system_i/sys_ps7/inst/PS7_i/FCLKCLK[0]"]
create_clock -name clk_fpga_1 -period  5 [get_pins "i_system_wrapper/system_i/sys_ps7/inst/PS7_i/FCLKCLK[1]"]

create_clock -name spi0_clk      -period 40   [get_pins -hier */EMIOSPI0SCLKO]

set_input_jitter clk_fpga_0 0.3
set_input_jitter clk_fpga_1 0.15

#set_false_path -to [get_pins i_system_wrapper/system_i/lvds_clck2/inst/clk_out_reg/CLR]

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

# FIXME !
#Important Rules to Follow
#1. Avoid High-Speed Clocks on the N-side
#While you can use the _N pin as an input, never use it for a high-speed clock.
#The _P side of a "Clock Capable" pair has a dedicated hardware "expressway" to the FPGA's clock network.
#The _N side does not have this dedicated path. If you put a clock on the N-pin, Vivado will give you the error you saw earlier because it has to route the clock through the "slow" general logic fabric, which causes jitter and timing issues.

set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets {pad_7_IBUF}]
