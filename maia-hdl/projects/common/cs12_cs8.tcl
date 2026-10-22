# Instantiates and connects dual-channel cs12_8mux blocks for 8-bit/12-bit packed streaming.
# Slices ADC GPIO bit 0 to synchronously drive zero_count and prevent cross-channel buffer drift.

# First delete existing connections
# Fixme : assuming mux_decim is present 

ad_disconnect mux_decim_i/data_out util_ad9361_adc_pack/fifo_wr_data_0
ad_disconnect mux_decim_q/data_out util_ad9361_adc_pack/fifo_wr_data_1
ad_disconnect util_ad9361_adc_fifo/dout_data_2 util_ad9361_adc_pack/fifo_wr_data_2
ad_disconnect util_ad9361_adc_fifo/dout_data_3 util_ad9361_adc_pack/fifo_wr_data_3

ad_disconnect mux_decim_i/valid_out util_ad9361_adc_pack/fifo_wr_en

ad_disconnect mux_decim_i/enable_out util_ad9361_adc_pack/enable_0
ad_disconnect mux_decim_q/enable_out util_ad9361_adc_pack/enable_1

ad_disconnect util_ad9361_adc_fifo/dout_enable_2 util_ad9361_adc_pack/enable_2
ad_disconnect util_ad9361_adc_fifo/dout_enable_3 util_ad9361_adc_pack/enable_3

# Generate synchronous reset for zero_count from ADC GPIO 0
ad_ip_instance xlslice cs12_zero_count_slice
ad_ip_parameter cs12_zero_count_slice CONFIG.DIN_FROM 0
ad_ip_parameter cs12_zero_count_slice CONFIG.DIN_TO 0
ad_connect axi_ad9361/up_adc_gpio_out cs12_zero_count_slice/Din

### CHANNEL 0 ###

create_bd_cell -type module -reference cs12_8mux cs12_8mux_chan0

# Inputs
ad_connect util_ad9361_adc_fifo/dout_enable_0 cs12_8mux_chan0/Enable0
ad_connect util_ad9361_adc_fifo/dout_enable_1 cs12_8mux_chan0/Enable1
ad_connect mux_decim_i/data_out cs12_8mux_chan0/I0
ad_connect mux_decim_q/data_out cs12_8mux_chan0/Q0

ad_connect mux_decim_i/valid_out cs12_8mux_chan0/valid_in
ad_connect cs12_8mux_chan0/clk util_ad9361_adc_fifo/dout_clk
ad_connect cs12_8mux_chan0/rst_n util_ad9361_adc_fifo/dout_rstn
ad_connect cs12_zero_count_slice/Dout cs12_8mux_chan0/zero_count

# Outputs (data routed through cs12_sync_frame: inserts a CS12 sync burst every period)
create_bd_cell -type module -reference cs12_sync_frame cs12_sync_chan0
ad_connect cs12_sync_chan0/clk           util_ad9361_adc_fifo/dout_clk
ad_connect cs12_sync_chan0/rst_n         util_ad9361_adc_fifo/dout_rstn
ad_connect util_ad9361_adc_fifo/dout_enable_0 cs12_sync_chan0/Enable0
ad_connect util_ad9361_adc_fifo/dout_enable_1 cs12_sync_chan0/Enable1
ad_connect cs12_8mux_chan0/frame_start   cs12_sync_chan0/frame_start
ad_connect cs12_8mux_chan0/valid_out     cs12_sync_chan0/valid_in
ad_connect cs12_8mux_chan0/data_out0     cs12_sync_chan0/data_in0
ad_connect cs12_8mux_chan0/data_out1     cs12_sync_chan0/data_in1
ad_connect cs12_sync_chan0/data_out0     util_ad9361_adc_pack/fifo_wr_data_0
ad_connect cs12_sync_chan0/data_out1     util_ad9361_adc_pack/fifo_wr_data_1
ad_connect cs12_8mux_chan0/Enable_O1 util_ad9361_adc_pack/enable_0
ad_connect cs12_8mux_chan0/Enable_O2 util_ad9361_adc_pack/enable_1


### CHANNEL 1 ###

create_bd_cell -type module -reference cs12_8mux cs12_8mux_chan1

# Inputs
ad_connect util_ad9361_adc_fifo/dout_enable_2 cs12_8mux_chan1/Enable0
ad_connect util_ad9361_adc_fifo/dout_enable_3 cs12_8mux_chan1/Enable1
# RX2 shares RX1's valid_in. With DDC routing on that is the DDC strobe, so RX2
# would be picked every decimation-th sample with no filter and no mixer, and
# out-of-band signals would alias into it. There is only one DDC, so deliver
# zeros on RX2 while routing is on instead of aliased samples.
ad_ip_instance xlconstant rx2_zero [list CONST_WIDTH 16 CONST_VAL 0]
foreach {mux din dout} {mux_rx2_i dout_data_2 I0 mux_rx2_q dout_data_3 Q0} {
  create_bd_cell -type module -reference ad_bus_mux $mux
  ad_connect decim_slice/Dout $mux/select_path
  ad_connect util_ad9361_adc_fifo/$din $mux/data_in_0
  ad_connect rx2_zero/dout $mux/data_in_1
  ad_connect $mux/data_out cs12_8mux_chan1/$dout
  foreach pin {valid_in_0 valid_in_1 enable_in_0 enable_in_1} {
    ad_connect $mux/$pin GND
  }
}

ad_connect mux_decim_i/valid_out cs12_8mux_chan1/valid_in
ad_connect cs12_8mux_chan1/clk util_ad9361_adc_fifo/dout_clk
ad_connect cs12_8mux_chan1/rst_n util_ad9361_adc_fifo/dout_rstn
ad_connect cs12_zero_count_slice/Dout cs12_8mux_chan1/zero_count

# Outputs (data routed through cs12_sync_frame: inserts a CS12 sync burst every period)
create_bd_cell -type module -reference cs12_sync_frame cs12_sync_chan1
ad_connect cs12_sync_chan1/clk           util_ad9361_adc_fifo/dout_clk
ad_connect cs12_sync_chan1/rst_n         util_ad9361_adc_fifo/dout_rstn
ad_connect util_ad9361_adc_fifo/dout_enable_2 cs12_sync_chan1/Enable0
ad_connect util_ad9361_adc_fifo/dout_enable_3 cs12_sync_chan1/Enable1
ad_connect cs12_8mux_chan1/frame_start   cs12_sync_chan1/frame_start
ad_connect cs12_8mux_chan1/valid_out     cs12_sync_chan1/valid_in
ad_connect cs12_8mux_chan1/data_out0     cs12_sync_chan1/data_in0
ad_connect cs12_8mux_chan1/data_out1     cs12_sync_chan1/data_in1
ad_connect cs12_sync_chan1/data_out0     util_ad9361_adc_pack/fifo_wr_data_2
ad_connect cs12_sync_chan1/data_out1     util_ad9361_adc_pack/fifo_wr_data_3
ad_connect cs12_8mux_chan1/Enable_O1 util_ad9361_adc_pack/enable_2
ad_connect cs12_8mux_chan1/Enable_O2 util_ad9361_adc_pack/enable_3

# OR BETWEEN 2 CHANNELS
ad_ip_instance util_vector_logic channels_or [list \
	  C_OPERATION {or} \
	  C_SIZE 1]
ad_connect cs12_8mux_chan0/valid_out channels_or/Op1
ad_connect cs12_8mux_chan1/valid_out channels_or/Op2
ad_connect channels_or/Res util_ad9361_adc_pack/fifo_wr_en