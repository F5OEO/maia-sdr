# Digital XO-error correction for LibreSDR variants fitted with a fixed TCXO.
#
# This script is sourced after the optional Maia, CS12, TX-FIR and DVB routing
# scripts, so it can insert one final correction point in each complete path:
#
#   RX: AD9361 ADC FIFO -> NCO -> Maia/raw pack/DMA
#   TX: DMA/DVB/TX FIR -> NCO -> AD9361 DAC FIFO
#
# The NCO is an exact latency-matched bypass after reset. Software enables it
# only for fixed-TCXO boards by writing the extra vctcxo_lock registers.

# Do not use ADI's ad_disconnect here. For a hierarchical module pin that
# helper can delete the pin together with its net. We only detach the selected
# sink pin and preserve the source, its net and all other fanout.
proc xo_disconnect_sink {pin_name} {
    set pin [get_bd_pins -quiet $pin_name]
    if {$pin eq ""} {
        error "XO corrector: block-design sink pin '$pin_name' not found"
    }
    set net [get_bd_nets -quiet -of_objects $pin]
    if {$net ne ""} {
        disconnect_bd_net $net $pin
    }
}

create_bd_cell -type module -reference iq_xo_corrector iq_xo_corrector

ad_connect util_ad9361_divclk/clk_out iq_xo_corrector/clk
ad_connect util_ad9361_divclk_reset/peripheral_aresetn iq_xo_corrector/rst_n
ad_connect vctcxo_lock/NCO_RX_FTW iq_xo_corrector/cfg_rx_ftw
ad_connect vctcxo_lock/NCO_TX_FTW iq_xo_corrector/cfg_tx_ftw
ad_connect vctcxo_lock/NCO_CONTROL iq_xo_corrector/cfg_control

# RX channel 0 currently fans out to both Maia and the raw/decimated IIO mux.
xo_disconnect_sink adc_i_slice/Din
xo_disconnect_sink adc_q_slice/Din
xo_disconnect_sink mux_decim_i/data_in_0
xo_disconnect_sink mux_decim_q/data_in_0
xo_disconnect_sink mux_decim_i/valid_in_0
xo_disconnect_sink mux_decim_q/valid_in_0

ad_connect util_ad9361_adc_fifo/dout_data_0 iq_xo_corrector/rx_i0_in
ad_connect util_ad9361_adc_fifo/dout_data_1 iq_xo_corrector/rx_q0_in
ad_connect util_ad9361_adc_fifo/dout_valid_0 iq_xo_corrector/rx_valid_in
ad_connect iq_xo_corrector/rx_i0_out adc_i_slice/Din
ad_connect iq_xo_corrector/rx_q0_out adc_q_slice/Din
ad_connect iq_xo_corrector/rx_i0_out mux_decim_i/data_in_0
ad_connect iq_xo_corrector/rx_q0_out mux_decim_q/data_in_0
ad_connect iq_xo_corrector/rx_valid_out mux_decim_i/valid_in_0
ad_connect iq_xo_corrector/rx_valid_out mux_decim_q/valid_in_0

# RX channel 1 feeds the second CS8/CS12 packer directly.
xo_disconnect_sink cs12_8mux_chan1/I0
xo_disconnect_sink cs12_8mux_chan1/Q0
ad_connect util_ad9361_adc_fifo/dout_data_2 iq_xo_corrector/rx_i1_in
ad_connect util_ad9361_adc_fifo/dout_data_3 iq_xo_corrector/rx_q1_in
ad_connect iq_xo_corrector/rx_i1_out cs12_8mux_chan1/I0
ad_connect iq_xo_corrector/rx_q1_out cs12_8mux_chan1/Q0

# TX channel 0 is taken after the optional/bypassable interpolation filter.
# Channel 1 has no interpolator and comes directly from the DMA unpacker.
xo_disconnect_sink axi_ad9361_dac_fifo/din_data_0
xo_disconnect_sink axi_ad9361_dac_fifo/din_data_1
xo_disconnect_sink axi_ad9361_dac_fifo/din_data_2
xo_disconnect_sink axi_ad9361_dac_fifo/din_data_3

ad_connect tx_fir_interpolator/data_out_0 iq_xo_corrector/tx_i0_in
ad_connect tx_fir_interpolator/data_out_1 iq_xo_corrector/tx_q0_in
ad_connect util_ad9361_dac_upack/fifo_rd_data_2 iq_xo_corrector/tx_i1_in
ad_connect util_ad9361_dac_upack/fifo_rd_data_3 iq_xo_corrector/tx_q1_in
ad_connect iq_xo_corrector/tx_i0_out axi_ad9361_dac_fifo/din_data_0
ad_connect iq_xo_corrector/tx_q0_out axi_ad9361_dac_fifo/din_data_1
ad_connect iq_xo_corrector/tx_i1_out axi_ad9361_dac_fifo/din_data_2
ad_connect iq_xo_corrector/tx_q1_out axi_ad9361_dac_fifo/din_data_3

# Delay the FIFO write-valid by the same amount as the NCO data. The FIR's
# valid OR is also the ordinary upack valid when interpolation is bypassed.
xo_disconnect_sink axi_ad9361_dac_fifo/din_valid_in_0
xo_disconnect_sink axi_ad9361_dac_fifo/din_valid_in_1
xo_disconnect_sink axi_ad9361_dac_fifo/din_valid_in_2
xo_disconnect_sink axi_ad9361_dac_fifo/din_valid_in_3
ad_connect dac_fifo_valid_or/Res iq_xo_corrector/tx_valid0_in
ad_connect util_ad9361_dac_upack/fifo_rd_valid iq_xo_corrector/tx_valid1_in
ad_connect iq_xo_corrector/tx_valid0_out axi_ad9361_dac_fifo/din_valid_in_0
ad_connect iq_xo_corrector/tx_valid0_out axi_ad9361_dac_fifo/din_valid_in_1
ad_connect iq_xo_corrector/tx_valid1_out axi_ad9361_dac_fifo/din_valid_in_2
ad_connect iq_xo_corrector/tx_valid1_out axi_ad9361_dac_fifo/din_valid_in_3

rename xo_disconnect_sink {}
