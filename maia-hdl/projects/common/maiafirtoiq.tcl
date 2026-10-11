#disconnect existing
ad_disconnect util_ad9361_adc_fifo/dout_data_0 util_ad9361_adc_pack/fifo_wr_data_0
ad_disconnect util_ad9361_adc_fifo/dout_data_1 util_ad9361_adc_pack/fifo_wr_data_1
ad_disconnect util_ad9361_adc_pack/fifo_wr_en util_ad9361_adc_fifo/dout_valid_0
ad_disconnect util_ad9361_adc_fifo/dout_enable_0 util_ad9361_adc_pack/enable_0
ad_disconnect util_ad9361_adc_fifo/dout_enable_1 util_ad9361_adc_pack/enable_1


#In order to be controled by iio		
ad_ip_instance xlslice decim_slice
ad_connect axi_ad9361/up_adc_gpio_out decim_slice/Din
	
# Reset for the DDC CDC FIFO, synchronous to its write clock (maia_sdr clk)
ad_ip_instance proc_sys_reset maia_rstgen
ad_connect maia_sdr_clk/clk_out1 maia_rstgen/slowest_sync_clk
ad_connect sys_cpu_resetn maia_rstgen/ext_reset_in
ad_connect maia_sdr_clk/locked maia_rstgen/dcm_locked

# DDC I and Q cross into the ADC clock domain together in one 32-bit FIFO
# ({Q, I}), so both halves of a sample always appear in the same cycle.
ad_ip_instance xlconcat decim_iq_concat
ad_ip_parameter decim_iq_concat CONFIG.NUM_PORTS 2
ad_ip_parameter decim_iq_concat CONFIG.IN0_WIDTH 16
ad_ip_parameter decim_iq_concat CONFIG.IN1_WIDTH 16
ad_connect maia_sdr/decim_re_out decim_iq_concat/In0
ad_connect maia_sdr/decim_im_out decim_iq_concat/In1

ad_ip_instance axis_data_fifo interclk_iq
ad_ip_parameter interclk_iq CONFIG.FIFO_DEPTH 16
ad_ip_parameter interclk_iq CONFIG.FIFO_MODE 1
ad_ip_parameter interclk_iq CONFIG.IS_ACLK_ASYNC 1
ad_ip_parameter interclk_iq CONFIG.HAS_TLAST.VALUE_SRC USER
ad_ip_parameter interclk_iq CONFIG.HAS_TLAST 0
ad_ip_parameter interclk_iq CONFIG.TDATA_NUM_BYTES 4
ad_ip_parameter interclk_iq CONFIG.SYNCHRONIZATION_STAGES 4

ad_connect maia_sdr_clk/clk_out1 interclk_iq/s_axis_aclk
ad_connect maia_rstgen/peripheral_aresetn interclk_iq/s_axis_aresetn
ad_connect decim_iq_concat/dout interclk_iq/s_axis_tdata
ad_connect maia_sdr/decim_strobe_out interclk_iq/s_axis_tvalid
ad_connect util_ad9361_divclk/clk_out interclk_iq/m_axis_aclk

ad_ip_instance xlslice decim_i_slice
ad_ip_parameter decim_i_slice CONFIG.DIN_WIDTH 32
ad_ip_parameter decim_i_slice CONFIG.DIN_FROM 15
ad_ip_parameter decim_i_slice CONFIG.DIN_TO 0
ad_ip_instance xlslice decim_q_slice
ad_ip_parameter decim_q_slice CONFIG.DIN_WIDTH 32
ad_ip_parameter decim_q_slice CONFIG.DIN_FROM 31
ad_ip_parameter decim_q_slice CONFIG.DIN_TO 16
ad_connect interclk_iq/m_axis_tdata decim_i_slice/Din
ad_connect interclk_iq/m_axis_tdata decim_q_slice/Din

#I
create_bd_cell -type module -reference ad_bus_mux mux_decim_i
ad_connect decim_i_slice/Dout mux_decim_i/data_in_1
ad_connect interclk_iq/m_axis_tvalid mux_decim_i/valid_in_1
ad_connect mux_decim_i/select_path decim_slice/Dout
ad_connect util_ad9361_adc_fifo/dout_valid_0 mux_decim_i/valid_in_0
ad_connect util_ad9361_adc_fifo/dout_enable_0 mux_decim_i/enable_in_0
ad_connect util_ad9361_adc_fifo/dout_data_0 mux_decim_i/data_in_0
ad_connect util_ad9361_adc_fifo/dout_enable_0 mux_decim_i/enable_in_1

#Q
create_bd_cell -type module -reference ad_bus_mux mux_decim_q
ad_connect decim_q_slice/Dout mux_decim_q/data_in_1
ad_connect interclk_iq/m_axis_tvalid mux_decim_q/valid_in_1
ad_connect mux_decim_q/select_path decim_slice/Dout
ad_connect util_ad9361_adc_fifo/dout_valid_1 mux_decim_q/valid_in_0
ad_connect util_ad9361_adc_fifo/dout_enable_1 mux_decim_q/enable_in_0
ad_connect util_ad9361_adc_fifo/dout_data_1 mux_decim_q/data_in_0
ad_connect util_ad9361_adc_fifo/dout_enable_1 mux_decim_q/enable_in_1

ad_connect mux_decim_i/data_out util_ad9361_adc_pack/fifo_wr_data_0
ad_connect mux_decim_q/data_out util_ad9361_adc_pack/fifo_wr_data_1
ad_connect mux_decim_i/valid_out util_ad9361_adc_pack/fifo_wr_en
ad_connect mux_decim_i/enable_out util_ad9361_adc_pack/enable_0
ad_connect mux_decim_q/enable_out util_ad9361_adc_pack/enable_1

#SEEMS THE DISCONNECT HAVE DELETE ALSO EXISTING
ad_connect util_ad9361_adc_fifo/dout_data_0 adc_i_slice/Din
ad_connect util_ad9361_adc_fifo/dout_data_1 adc_q_slice/Din
