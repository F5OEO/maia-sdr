# DVB-S2 symbol front end (maia_hdl/symfront.py, ip/symfront)
#
# Inserted between the RX sample source (mux_decim_i/q) and the cs12/cs8
# packing (cs12_8mux_chan0/1): disabled it passes the samples through,
# enabled (register 0x00 bit 0) it replaces them by timing-recovered
# symbols, one strobe per symbol, unit power = 512 (zynqrx --symbols).
# Sourced after cs12_cs8.tcl. Registers at 0x43C20000.
#
#   mux_decim_i/q ──▶ symfront ──▶ cs12_8mux_chan0 (I0/Q0, valid_in)
#                         └───── strobe_out ──▶ cs12_8mux_chan1/valid_in

if {![info exists symfront_proc_clk]} { set symfront_proc_clk maia_sdr_clk/clk_out2 }

ad_disconnect mux_decim_i/data_out cs12_8mux_chan0/I0
ad_disconnect mux_decim_q/data_out cs12_8mux_chan0/Q0
ad_disconnect mux_decim_i/valid_out cs12_8mux_chan0/valid_in
ad_disconnect mux_decim_i/valid_out cs12_8mux_chan1/valid_in

ad_ip_instance symfront dvbs2_symfront

# processing clock and its reset
ad_ip_instance proc_sys_reset symfront_rstgen
ad_connect $symfront_proc_clk symfront_rstgen/slowest_sync_clk
ad_connect sys_rstgen/peripheral_aresetn symfront_rstgen/ext_reset_in
ad_connect $symfront_proc_clk dvbs2_symfront/proc_clk
ad_connect symfront_rstgen/peripheral_reset dvbs2_symfront/proc_rst

ad_connect util_ad9361_divclk/clk_out dvbs2_symfront/iq_clk
ad_connect util_ad9361_divclk_reset/peripheral_reset dvbs2_symfront/iq_rst

ad_connect sys_cpu_clk dvbs2_symfront/s_axi_lite_clk
ad_connect sys_cpu_reset dvbs2_symfront/s_axi_lite_rst
ad_cpu_interconnect 0x43C20000 dvbs2_symfront

ad_connect mux_decim_i/data_out dvbs2_symfront/re_in
ad_connect mux_decim_q/data_out dvbs2_symfront/im_in
ad_connect mux_decim_i/valid_out dvbs2_symfront/strobe_in

ad_connect dvbs2_symfront/re_out cs12_8mux_chan0/I0
ad_connect dvbs2_symfront/im_out cs12_8mux_chan0/Q0
ad_connect dvbs2_symfront/strobe_out cs12_8mux_chan0/valid_in
ad_connect dvbs2_symfront/strobe_out cs12_8mux_chan1/valid_in
