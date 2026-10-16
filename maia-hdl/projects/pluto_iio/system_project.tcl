set IGNORE_VERSION_CHECK 1
source ../../adi-hdl/scripts/adi_env.tcl
source $ad_hdl_dir/projects/scripts/adi_project_xilinx.tcl
source $ad_hdl_dir/projects/scripts/adi_board.tcl

adi_project_create pluto 0 {} "xc7z010clg225-1"

adi_project_files pluto [list \
  "../pluto/system_top.v" \
  "../pluto/system_constr.xdc" \
  "$ad_hdl_dir/library/common/ad_iobuf.v"]

# reset_timing.xdc needs the synthesized netlist to resolve cell names
add_files -fileset constrs_1 -norecurse [file normalize [file join [file dirname [info script]] ../pluto/reset_timing.xdc]]
set_property used_in_synthesis false [get_files reset_timing.xdc]

# use improved implementation strategy for best timing results
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]

set_property is_enabled false [get_files  *system_sys_ps7_0.xdc]
adi_project_run pluto
source $ad_hdl_dir/library/axi_ad9361/axi_ad9361_delay.tcl
