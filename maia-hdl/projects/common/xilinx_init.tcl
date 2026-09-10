# Setup IP Repositories
save_bd_design
close_bd_design system
set_property ip_repo_paths [list \
  "$::tezuka_hdl_dir/common/antsdr-hdl" \
  "$::tezuka_hdl_dir/common/libresdr-hdl" \
  "$::tezuka_hdl_dir/common/libre-vctcxo-lock" \
  "$::tezuka_hdl_dir/../ip" \
  "$::tezuka_hdl_dir/../dvb_fpga" \
  "$ad_hdl_dir/library" \
] [current_fileset]
update_ip_catalog -rebuild
open_bd_design $project_name.srcs/sources_1/bd/system/system.bd
source $ad_hdl_dir/projects/common/xilinx/adi_fir_filter_bd.tcl

# Default Global Ports
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddrx_rtl:1.0 ddr
create_bd_intf_port -mode Master -vlnv xilinx.com:display_processing_system7:fixedio_rtl:1.0 fixed_io

add_files -norecurse  $ad_hdl_dir/library/common/ad_bus_mux.v
add_files -norecurse  $::tezuka_hdl_dir/common/sweeper_it.v
add_files -norecurse  $::tezuka_hdl_dir/common/cs12_cs8mux.v
add_files -norecurse  $::tezuka_hdl_dir/common/cs12_sync_frame.v
add_files -norecurse  $::tezuka_hdl_dir/boards/fishball7020/vcxo_ctrl.v
add_files -norecurse  $::tezuka_hdl_dir/common/mux_enable.v
add_files -norecurse  $::tezuka_hdl_dir/boards/plutoskyr2/ADF4001_init.v
add_files -norecurse  $::tezuka_hdl_dir/boards/plutoskyr2/ADF4001_spi_drive.v
if {[info exists xo_corrector]} {
  add_files -norecurse  $::tezuka_hdl_dir/common/iq_xo_corrector.v
  add_files -norecurse -fileset constrs_1 \
    $::tezuka_hdl_dir/common/iq_xo_corrector.xdc
  add_files -norecurse  $ad_hdl_dir/library/common/ad_dds_sine_cordic.v
  add_files -norecurse  $ad_hdl_dir/library/common/ad_dds_cordic_pipe.v
}

#ps_7.tcl should be called after that
