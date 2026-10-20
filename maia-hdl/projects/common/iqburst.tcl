
#ASSUME SYNC implemeneted : FixMe as it could be run without it
ad_ip_instance iqburst myiqburst

ad_connect myiqburst/iq_clk util_ad9361_divclk/clk_out
ad_connect util_ad9361_divclk_reset/peripheral_reset myiqburst/iq_rst

ad_connect  sys_cpu_clk myiqburst/s_axi_lite_clk
ad_connect  sys_cpu_reset myiqburst/s_axi_lite_rst

ad_cpu_interconnect 0x40000000 myiqburst

#we have now cs12_sync_chan in beetween, and channels_or now drives fifo_wr_en (OR of both channels)
ad_disconnect cs12_sync_chan0/data_out0 util_ad9361_adc_pack/fifo_wr_data_0
ad_disconnect cs12_sync_chan0/data_out1 util_ad9361_adc_pack/fifo_wr_data_1
ad_disconnect cs12_sync_chan1/data_out0 util_ad9361_adc_pack/fifo_wr_data_2
ad_disconnect cs12_sync_chan1/data_out1 util_ad9361_adc_pack/fifo_wr_data_3
ad_disconnect channels_or/Res util_ad9361_adc_pack/fifo_wr_en

ad_connect cs12_sync_chan0/data_out0 myiqburst/re_in_0
ad_connect cs12_sync_chan0/data_out1 myiqburst/im_in_0
ad_connect cs12_sync_chan1/data_out0 myiqburst/re_in_1
ad_connect cs12_sync_chan1/data_out1 myiqburst/im_in_1

ad_connect myiqburst/re_out_0 util_ad9361_adc_pack/fifo_wr_data_0
ad_connect myiqburst/im_out_0 util_ad9361_adc_pack/fifo_wr_data_1
ad_connect myiqburst/re_out_1 util_ad9361_adc_pack/fifo_wr_data_2
ad_connect myiqburst/im_out_1 util_ad9361_adc_pack/fifo_wr_data_3


ad_connect channels_or/Res myiqburst/strobe_in
ad_connect myiqburst/strobe_out util_ad9361_adc_pack/fifo_wr_en

if {[info exists sync] } {
    ad_connect muxer_enable/out_i0 myiqburst/sync_in
} else {
    ad_connect util_ad9361_adc_pack/enable_0 myiqburst/sync_in
}