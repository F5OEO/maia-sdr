set IGNORE_VERSION_CHECK 1
source ../../adi-hdl/scripts/adi_env.tcl
source $ad_hdl_dir/projects/scripts/adi_project_xilinx.tcl
source $ad_hdl_dir/projects/scripts/adi_board.tcl
# !!!!!!!!!!!!!!!! THIS PATH IS WHHAT WE NEED TO CHANGE DEPENDING ON THE PROJECT !!!!!!!!!!!!!!!!!!
source ../tezuka_env.tcl

if { [info exists ::env(PROJECT_NAME)] } {
  set project_name $::env(PROJECT_NAME)
} else {
  set project_name "unknown"
}


switch -glob -- $project_name {
    "e310" 
    {
        set p_device "xc7z020clg400-2"
    }
    "e200" 
    {
        set p_device "xc7z020clg400-2"
    }
    "libre" {
        set p_device "xc7z020clg400-2"
        
    }
    "pluto" {
        set p_device "xc7z010clg225-1"
       
    }
    "plutoplus" {
        set p_device "xc7z010clg400-1"
    }
    "fishball7010" {
        set p_device "xc7z010clg400-1"
    }
    "fishball7020" {
        set p_device "xc7z020clg400-2"
    }
    "signalsdrpro" {
        set p_device "xc7z020clg400-2"
    }
    "nano" {
        set p_device "xc7z010clg400-1"
    }
    "plutoskyr2" {
        set p_device "xc7z020clg484-2"
    }
    "pciesdr7010" {
        set p_device "xc7z010clg400-1"
    }
    "opensdrlab7010mini" {
        set p_device "xc7z010clg400-1"
    }
    default {
        puts "CRITICAL WARNING: Project name '$project_name' not recognized."
        exit 1
    }
}

adi_project $project_name

adi_project_files $project_name [list \
  "$::tezuka_hdl_dir/boards/$project_name/system_top_sync.v" \
  "$::tezuka_hdl_dir/boards/$project_name/system_constr.xdc" \
  "$ad_hdl_dir/library/common/ad_iobuf.v"]


# use improved implementation strategy for best timing results
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
# Vivado 2025 : BUG 
# https://adaptivesupport.amd.com/s/question/0D5Pd0000153gqkKAA/persistent-hold-timing-violations-after-upgrading-to-vivado-2025x-physoptdesign-holdfix-ineffective?language=en_US
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.TCL.PRE \
  [file normalize [file join [file dirname [info script]] hold_fix.tcl]] \
  [get_runs impl_1]
set_property is_enabled false [get_files  *system_sys_ps7_0.xdc]
adi_project_run $project_name
source $ad_hdl_dir/library/axi_ad9361/axi_ad9361_delay.tcl
