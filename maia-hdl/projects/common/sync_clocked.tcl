# Clocked sync gate (common/sync_gate.v) instead of the combinational common/mux_enable.v of sync.tcl.
# DRAFT, not built in Vivado. Same external behaviour as sync.tcl: ports sync_out (O) / sync_in (I), register
# 0x800000BC of cf-ad9361-lpc (up_adc_gpio_out) bit 1 = is_slave, bit 2 = sync_out; the cell keeps the name
# muxer_enable (iqburst.tcl connects muxer_enable/out_i0 to myiqburst/sync_in).
# New register bits (up_adc_gpio_out is 32 bits wide, reset 0, bits 3 and up were unused):
#   bit 3     phase_sel     0 = sample sync_in on the rising sample-clock edge, 1 = on the falling edge
#   bits 8:4  master_delay  extra sample-clock cycles on the master's own gate (0 = aligned with the slave)
# ASSUMING CS12MUX is implemented before (cs12_cs8.tcl), as sync.tcl does.
# To go back to the combinational gate, source sync.tcl instead (see tezuka_sync/system_bd.tcl).

create_bd_port -dir O sync_out
create_bd_port -dir I sync_in

ad_disconnect cs12_8mux_chan0/Enable_O1 util_ad9361_adc_pack/enable_0
ad_disconnect cs12_8mux_chan0/Enable_O2 util_ad9361_adc_pack/enable_1
ad_disconnect cs12_8mux_chan1/Enable_O1 util_ad9361_adc_pack/enable_2
ad_disconnect cs12_8mux_chan1/Enable_O2 util_ad9361_adc_pack/enable_3

add_files -norecurse $::tezuka_hdl_dir/common/sync_gate.v
create_bd_cell -type module -reference sync_gate muxer_enable

ad_connect util_ad9361_adc_pack/enable_0 muxer_enable/out_i0
ad_connect util_ad9361_adc_pack/enable_1 muxer_enable/out_q0
ad_connect util_ad9361_adc_pack/enable_2 muxer_enable/out_i1
ad_connect util_ad9361_adc_pack/enable_3 muxer_enable/out_q1

# the gate runs on the sample clock, like util_ad9361_adc_pack and IQBurst
ad_connect muxer_enable/clk util_ad9361_divclk/clk_out

ad_ip_instance xlslice sync_slice_in
ad_ip_parameter sync_slice_in CONFIG.DIN_FROM 1
ad_ip_parameter sync_slice_in CONFIG.DIN_TO 1
ad_connect axi_ad9361/up_adc_gpio_out sync_slice_in/Din
ad_connect muxer_enable/is_slave sync_slice_in/Dout

ad_ip_instance xlslice sync_slice_out
ad_ip_parameter sync_slice_out CONFIG.DIN_FROM 2
ad_ip_parameter sync_slice_out CONFIG.DIN_TO 2
ad_connect axi_ad9361/up_adc_gpio_out sync_slice_out/Din
ad_connect sync_slice_out/Dout muxer_enable/arm_master

ad_ip_instance xlslice sync_slice_phase
ad_ip_parameter sync_slice_phase CONFIG.DIN_FROM 3
ad_ip_parameter sync_slice_phase CONFIG.DIN_TO 3
ad_connect axi_ad9361/up_adc_gpio_out sync_slice_phase/Din
ad_connect sync_slice_phase/Dout muxer_enable/phase_sel

ad_ip_instance xlslice sync_slice_delay
ad_ip_parameter sync_slice_delay CONFIG.DIN_FROM 8
ad_ip_parameter sync_slice_delay CONFIG.DIN_TO 4
ad_ip_parameter sync_slice_delay CONFIG.DOUT_WIDTH 5
ad_connect axi_ad9361/up_adc_gpio_out sync_slice_delay/Din
ad_connect sync_slice_delay/Dout muxer_enable/master_delay

# pads: sync_out is now launched from a sample-clock flop inside sync_gate
ad_connect muxer_enable/sync_in_pad sync_in
ad_connect muxer_enable/sync_out sync_out

ad_connect cs12_8mux_chan0/Enable_O1 muxer_enable/ps_i0
ad_connect cs12_8mux_chan0/Enable_O2 muxer_enable/ps_q0
ad_connect cs12_8mux_chan1/Enable_O1 muxer_enable/ps_i1
ad_connect cs12_8mux_chan1/Enable_O2 muxer_enable/ps_q1
