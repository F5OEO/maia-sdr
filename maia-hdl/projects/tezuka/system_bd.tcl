# Adresses uses
# E200/E300 Vcxoctrl 0x43C00000 
# DVB 0x43C03000 switchsrc
# DVB 0x43C01000 switchdest
# DVB 0x43C02000 switchfir
# Uartlite 0x42C00000 miniserial
# 0x40000000 myiqburst 
# 0x7C460000 maia_sdr
#LIBRE  0x41200000 axi_gpio_0
#LIBRE  0x41210000 axi_gpio_1
#LIBRE  0x41220000 axi_gpio_2

switch -glob -- $project_name {
    "e310" 
    {
        set vctcxo "vctcxo"
        set txfir "txfir"
        set dac_dds "dac_dds"
        set dvb "dvb"
    }
    "e200" 
    {
        set vctcxo "vctcxo"
        set txfir "txfir"
        set dac_dds "dac_dds"
        set dvb "dvb"
    }
    "libre" {
        set lvds "lvds"
        set vctcxo "vctcxo"
        set xo_corrector "xo_corrector"
        set txfir "txfir"
        set dac_dds "dac_dds"
        set dvb "dvb"
    }
    "pluto" {
        
       
    }
    "plutoplus" {
        
    }
    "fishball7010" {
        set lvds "lvds"
        #set uartlite "uartlite"
        
        
            }     
     
    "fishball7020" {
        set lvds "lvds"
        set uartlite "uartlite"
        #set dac_dds "dac_dds"
        set dvb "dvb"
        set vctcxo "vctcxo"
        set txfir "txfir"
        set i2c1emio "i2c1emio"
        #set sync "sync"
        #set iqburst "iqburst"

    }
    "signalsdrpro" {
        set dvb "dvb"
        set txfir "txfir"
        set dac_dds "dac_dds"
    }
    "nano" {
        
    }
    "plutoskyr2" {
       set lvds "lvds"
       set txfir "txfir"
       set dac_dds "dac_dds"
       set dvb "dvb"
    }
    "pciesdr7010" {
        set lvds "lvds"
    }
    "opensdrlab7010mini" {
        set lvds "lvds"
    }
    default {
        puts "CRITICAL WARNING: Project name '$project_name' not recognized."
        exit 1
    }
}


source $::tezuka_hdl_dir/common/xilinx_init.tcl
source $::tezuka_hdl_dir/boards/$project_name/ps7.tcl
source $::tezuka_hdl_dir/common/xilinx_ad9361.tcl
source $::tezuka_hdl_dir/boards/$project_name/ports.tcl
#source $::tezuka_hdl_dir/common/minimal.tcl
source $::tezuka_hdl_dir/common/maia.tcl
if {[info exists fftraw]} {
      source $::tezuka_hdl_dir/common/maiaffttoiq.tcl
} else {
   source $::tezuka_hdl_dir/common/maiafirtoiq.tcl
}



if {[info exists vctcxo]} { source $::tezuka_hdl_dir/boards/$project_name/vcxo_ctrl.tcl }
source $::tezuka_hdl_dir/common/sweeper.tcl
source $::tezuka_hdl_dir/common/cs12_cs8.tcl
if {[info exists uartlite]} { source $::tezuka_hdl_dir/common/uartlite.tcl }
if {[info exists txfir]} { source $::tezuka_hdl_dir/common/txfir.tcl }
if {[info exists sync]} { source $::tezuka_hdl_dir/common/sync.tcl }
if {[info exists iqburst]} { source $::tezuka_hdl_dir/common/iqburst.tcl }
if {[info exists dvb]} { source $::tezuka_hdl_dir/common/dvb.tcl }
if {[info exists xo_corrector]} { source $::tezuka_hdl_dir/boards/$project_name/xo_corrector.tcl }
if {[info exists spiquad]} { source $::tezuka_hdl_dir/common/spiquad.tcl }
if {[info exists i2c1emio]} { source $::tezuka_hdl_dir/common/i2c1emio.tcl }
