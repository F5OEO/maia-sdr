set_property PACKAGE_PIN p16 [get_ports gpio_en_agc]       
#
set_property PACKAGE_PIN n17 [get_ports gpio_resetb]       
#

set_property PACKAGE_PIN t10 [get_ports {gpio_ctl[0]}]        
#  
set_property PACKAGE_PIN j14 [get_ports {gpio_ctl[1]}]        
# 
set_property PACKAGE_PIN n15 [get_ports {gpio_ctl[2]}]        
#


set_property PACKAGE_PIN n16 [get_ports {gpio_ctl[3]}]        
#

set_property PACKAGE_PIN t11 [get_ports {gpio_status[0]}]      
#
set_property PACKAGE_PIN t14 [get_ports {gpio_status[1]}]      
#
set_property PACKAGE_PIN t15 [get_ports {gpio_status[2]}]     
#
set_property PACKAGE_PIN t17 [get_ports {gpio_status[3]}]    
#
set_property PACKAGE_PIN t19 [get_ports {gpio_status[4]}]    
#
set_property PACKAGE_PIN t20 [get_ports {gpio_status[5]}]   
 #
set_property PACKAGE_PIN u13 [get_ports {gpio_status[6]}]   
#
set_property PACKAGE_PIN v13 [get_ports {gpio_status[7]}]    
#

set_property PACKAGE_PIN n20 [get_ports rx_clk_in]           
#rx_clk_in_p        
set_property PACKAGE_PIN u18 [get_ports rx_frame_in]        
#rx_frame_in_p

set_property PACKAGE_PIN y19 [get_ports {rx_data_in[0]}]     
#rx_data_in_n[0]
set_property PACKAGE_PIN y18 [get_ports {rx_data_in[1]}]    
#rx_data_in_p[0]

set_property PACKAGE_PIN w20 [get_ports {rx_data_in[2]}]    
#rx_data_in_n[1]
set_property PACKAGE_PIN v20 [get_ports {rx_data_in[3]}]   
 #rx_data_in_p[1]

set_property PACKAGE_PIN w19 [get_ports {rx_data_in[4]}]    
#rx_data_in_n[2]
set_property PACKAGE_PIN w18 [get_ports {rx_data_in[5]}]    
#rx_data_in_p[2]

set_property PACKAGE_PIN r17 [get_ports {rx_data_in[6]}]     
#rx_data_in_n[3]
set_property PACKAGE_PIN r16 [get_ports {rx_data_in[7]}]   
#rx_data_in_p[3]

set_property PACKAGE_PIN v18 [get_ports {rx_data_in[8]}]    
#rx_data_in_n[4]
set_property PACKAGE_PIN v17 [get_ports {rx_data_in[9]}]    
#rx_data_in_p[4]

set_property PACKAGE_PIN w16 [get_ports {rx_data_in[10]}]   
#rx_data_in_n[5]
set_property PACKAGE_PIN v16 [get_ports {rx_data_in[11]}]   
#rx_data_in_p[5]

set_property PACKAGE_PIN y17 [get_ports {tx_data_out[0]}]    
#tx_data_out_n[0] 
set_property PACKAGE_PIN y16 [get_ports {tx_data_out[1]}]    
#tx_data_out_p[0] 

set_property PACKAGE_PIN u15 [get_ports {tx_data_out[2]}]   
#tx_data_out_n[1] 
set_property PACKAGE_PIN u14 [get_ports {tx_data_out[3]}]   
#tx_data_out_p[1] 

set_property PACKAGE_PIN w15 [get_ports {tx_data_out[4]}]   
#tx_data_out_n[2] 
set_property PACKAGE_PIN v15 [get_ports {tx_data_out[5]}]   
#tx_data_out_p[2] 

set_property PACKAGE_PIN y14 [get_ports {tx_data_out[6]}]     
#tx_data_out_n[3] 
set_property PACKAGE_PIN w14 [get_ports {tx_data_out[7]}]   
#tx_data_out_p[3] 

set_property PACKAGE_PIN w13 [get_ports {tx_data_out[8]}]    
#tx_data_out_n[4] 
set_property PACKAGE_PIN v12 [get_ports {tx_data_out[9]}]   
#tx_data_out_p[4] 

set_property PACKAGE_PIN u12 [get_ports {tx_data_out[10]}]  
#tx_data_out_n[5] 
set_property PACKAGE_PIN t12 [get_ports {tx_data_out[11]}] 
#tx_data_out_p[5]  

set_property PACKAGE_PIN n18 [get_ports tx_clk_out]       
#tx_clk_out_p
set_property PACKAGE_PIN t16 [get_ports tx_frame_out]     
#tx_frame_out_p



set_property PACKAGE_PIN p14 [get_ports txnrx]    
set_property PACKAGE_PIN r18 [get_ports enable] 
set_property PACKAGE_PIN m14 [get_ports iic_scl]           
set_property PACKAGE_PIN m15 [get_ports iic_sda]        
set_property PACKAGE_PIN p18 [get_ports spi_csn]        
set_property PACKAGE_PIN r14 [get_ports spi_clk]         
set_property PACKAGE_PIN p15 [get_ports spi_mosi]       
set_property PACKAGE_PIN r19 [get_ports spi_miso]        





set_property IOSTANDARD LVCMOS18 [get_ports gpio_en_agc]
set_property IOSTANDARD LVCMOS18 [get_ports gpio_resetb]
set_property IOSTANDARD LVCMOS18 [get_ports {gpio_ctl[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {gpio_ctl[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {gpio_ctl[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {gpio_ctl[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {gpio_status[7]}]
set_property IOSTANDARD LVCMOS18 [get_ports {gpio_status[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {gpio_status[5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {gpio_status[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {gpio_status[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {gpio_status[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {gpio_status[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {gpio_status[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports iic_scl]
set_property IOSTANDARD LVCMOS18 [get_ports iic_sda] 

set_property IOSTANDARD LVCMOS18 [get_ports spi_clk]
set_property IOSTANDARD LVCMOS18 [get_ports spi_csn]
set_property IOSTANDARD LVCMOS18 [get_ports spi_miso]
set_property IOSTANDARD LVCMOS18 [get_ports spi_mosi]
set_property IOSTANDARD LVCMOS18 [get_ports clk_out]
set_property IOSTANDARD LVCMOS18 [get_ports {rx_data_in[11]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rx_data_in[10]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rx_data_in[9]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rx_data_in[8]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rx_data_in[7]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rx_data_in[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rx_data_in[5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rx_data_in[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rx_data_in[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rx_data_in[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rx_data_in[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rx_data_in[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {tx_data_out[11]}]
set_property IOSTANDARD LVCMOS18 [get_ports {tx_data_out[10]}]
set_property IOSTANDARD LVCMOS18 [get_ports {tx_data_out[9]}]
set_property IOSTANDARD LVCMOS18 [get_ports {tx_data_out[8]}]
set_property IOSTANDARD LVCMOS18 [get_ports {tx_data_out[7]}]
set_property IOSTANDARD LVCMOS18 [get_ports {tx_data_out[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {tx_data_out[5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {tx_data_out[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {tx_data_out[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {tx_data_out[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {tx_data_out[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {tx_data_out[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports enable]
set_property IOSTANDARD LVCMOS18 [get_ports rx_clk_in]
set_property IOSTANDARD LVCMOS18 [get_ports rx_frame_in]
set_property IOSTANDARD LVCMOS18 [get_ports tx_clk_out]
set_property IOSTANDARD LVCMOS18 [get_ports tx_frame_out]
set_property IOSTANDARD LVCMOS18 [get_ports txnrx]

create_clock -name rx_clk -period  8 [get_ports rx_clk_in]
create_clock -name clk_fpga_0 -period 10 [get_pins "i_system_wrapper/system_i/sys_ps7/inst/PS7_i/FCLKCLK[0]"]
create_clock -name clk_fpga_1 -period  5 [get_pins "i_system_wrapper/system_i/sys_ps7/inst/PS7_i/FCLKCLK[1]"]

create_clock -name spi0_clk      -period 40   [get_pins -hier */EMIOSPI0SCLKO]

set_input_jitter clk_fpga_0 0.3
set_input_jitter clk_fpga_1 0.15


#set_property -dict {PACKAGE_PIN F19 IOSTANDARD LVCMOS18} [get_ports tx1_en]
#WRONG PORT
set_property -dict {PACKAGE_PIN B20 IOSTANDARD LVCMOS18} [get_ports tx1_en]
set_property -dict {PACKAGE_PIN C20 IOSTANDARD LVCMOS18} [get_ports tx2_en]
set_property -dict {PACKAGE_PIN E19 IOSTANDARD LVCMOS18} [get_ports sel_clk_src]

#set_property -dict {PACKAGE_PIN L17 IOSTANDARD LVCMOS18} [get_ports rx1_led ]
#WRONG PORT
set_property -dict {PACKAGE_PIN a20 IOSTANDARD LVCMOS18} [get_ports rx1_led ]
set_property -dict {PACKAGE_PIN b19 IOSTANDARD LVCMOS18} [get_ports rx2_led ]

set_false_path -from [get_pins {i_system_wrapper/system_i/axi_ad9361/inst/i_rx/i_up_adc_common/up_adc_gpio_out_int_reg[0]/C}]
set_false_path -from [get_pins {i_system_wrapper/system_i/axi_ad9361/inst/i_tx/i_up_dac_common/up_dac_gpio_out_int_reg[0]/C}]





 
