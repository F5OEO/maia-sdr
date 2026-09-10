# =============================================================================
# dvb.tcl — DVB-S2 modulator chain
#
# Sourced AFTER xilinx_ad9361.tcl.  Disconnects the default DAC DMA → upack
# path and reroutes through the DVB-S2 switch/encoder/filter chain.
#
#   Default (xilinx_ad9361.tcl):
#     dac_dma/m_axis ──[divclk]──▶ upack/s_axis ──▶ rfifo ──▶ AD9361
#
#   After dvb.tcl (switches run at 64-bit, converters at 32-bit boundaries):
#
#     dac_dma/m_axis ──[sys_cpu_clk, 64b]──▶ dma_domain_fifo ──▶ switchsrc
#       M00 ──▶ encoder(64→32) ──▶ dw_enc_out(32→64) ──▶ switchfir/S01
#       M01 ──────────────────────────────────────────────▶ switchfir/S00
#     switchfir
#       M01 ──▶ dw_rrc_in(64→32) ──▶ RRC(32→32) ──▶ dw_rrc_out(32→64) ──▶ switchdest/S00
#       M00 ──────────────────────────────────────────────────────────────▶ switchdest/S01
#     switchdest ──▶ interclk ──[divclk, 64b]──▶ upack/s_axis ──▶ rfifo ──▶ AD9361
#
# =============================================================================

set dvb_fpga_vivado_dir [file normalize \
    [file join $::tezuka_hdl_dir .. dvb_fpga build vivado]]
set dvb_fpga_file_list [file join $dvb_fpga_vivado_dir add_dvbs2_files.tcl]
set dvb_fpga_wrapper [file join $dvb_fpga_vivado_dir dvbs2_encoder_wrapper.vhd]

if {![file isfile $dvb_fpga_file_list]} {
    error "DVB FPGA sources not found at $dvb_fpga_vivado_dir; initialize the dvb_fpga git submodule first"
}

source $dvb_fpga_file_list
add_files -norecurse $dvb_fpga_wrapper

# ── Disconnect Default DAC Path ─────────────────────────────────────────────
# xilinx_ad9361.tcl connects:
#   line 279: util_ad9361_divclk/clk_out → axi_ad9361_dac_dma/m_axis_aclk
#   line 280: util_ad9361_dac_upack/s_axis ↔ axi_ad9361_dac_dma/m_axis

# 1) Scalar clock — disconnect divclk, reclock to sys_cpu_clk
set clk_net [get_bd_nets -of_objects [get_bd_pins axi_ad9361_dac_dma/m_axis_aclk]]
if {$clk_net ne ""} {
    disconnect_bd_net $clk_net [get_bd_pins axi_ad9361_dac_dma/m_axis_aclk]
}
ad_connect sys_cpu_clk axi_ad9361_dac_dma/m_axis_aclk

# 2) Domain-laundering FIFO: the DMA IP locks its CLK_DOMAIN property
#    to the original clock, so we interpose a same-clock FIFO whose
#    M_AXIS inherits CLK_DOMAIN from sys_cpu_clk cleanly.
ad_ip_instance axis_data_fifo dma_domain_fifo
ad_ip_parameter dma_domain_fifo CONFIG.FIFO_DEPTH 16
ad_ip_parameter dma_domain_fifo CONFIG.IS_ACLK_ASYNC 0
ad_ip_parameter dma_domain_fifo CONFIG.HAS_TLAST.VALUE_SRC USER
ad_ip_parameter dma_domain_fifo CONFIG.HAS_TLAST 0
ad_connect sys_cpu_clk     dma_domain_fifo/s_axis_aclk
ad_connect sys_cpu_resetn  dma_domain_fifo/s_axis_aresetn

# 3) Interface pins — manual disconnect (ad_disconnect uses get_bd_intf_ports
#    instead of get_bd_intf_pins, so it silently misses cell-level connections)
set net [get_bd_intf_nets -of_objects [get_bd_intf_pins axi_ad9361_dac_dma/m_axis]]
if {$net ne ""} {
    disconnect_bd_intf_net $net [get_bd_intf_pins axi_ad9361_dac_dma/m_axis]
}
set net2 [get_bd_intf_nets -of_objects [get_bd_intf_pins util_ad9361_dac_upack/s_axis]]
if {$net2 ne ""} {
    disconnect_bd_intf_net $net2 [get_bd_intf_pins util_ad9361_dac_upack/s_axis]
}

# ── AXIS Switches (all 64-bit, matching DMA width) ──────────────────────────

# Source split: DMA → {encoder, direct-to-FIR-switch}
ad_ip_instance axis_switch switchsrc
ad_ip_parameter switchsrc CONFIG.ROUTING_MODE 1
ad_ip_parameter switchsrc CONFIG.NUM_SI 1
ad_ip_parameter switchsrc CONFIG.NUM_MI 2
ad_connect sys_cpu_clk switchsrc/aclk
ad_connect sys_cpu_resetn switchsrc/aresetn
ad_cpu_interconnect 0x43C03000 switchsrc

# Dest merge: {from RRC path, from FIR bypass} → interclk → upack
ad_ip_instance axis_switch switchdest
ad_ip_parameter switchdest CONFIG.ROUTING_MODE 1
ad_ip_parameter switchdest CONFIG.NUM_SI 2
ad_ip_parameter switchdest CONFIG.NUM_MI 1
ad_connect sys_cpu_clk switchdest/aclk
ad_connect sys_cpu_resetn switchdest/aresetn
ad_cpu_interconnect 0x43C01000 switchdest

# FIR split: {direct IQ, encoded} → {RRC, bypass-to-dest}
ad_ip_instance axis_switch switchfir
ad_ip_parameter switchfir CONFIG.ROUTING_MODE 1
ad_ip_parameter switchfir CONFIG.NUM_SI 2
ad_ip_parameter switchfir CONFIG.NUM_MI 2
ad_connect sys_cpu_clk switchfir/aclk
ad_connect sys_cpu_resetn switchfir/aresetn
ad_cpu_interconnect 0x43C02000 switchfir

# ── DVB-S2 Encoder ──────────────────────────────────────────────────────────

set block_name dvbs2_encoder_wrapper
set block_cell_name dvbs2_encoder_wrapper_0
if { [catch {set dvbs2_encoder_wrapper_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
    catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
    return 1
} elseif { $dvbs2_encoder_wrapper_0 eq "" } {
    catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
    return 1
}

ad_connect sys_cpu_clk dvbs2_encoder_wrapper_0/clk
ad_ip_parameter dvbs2_encoder_wrapper_0 CONFIG.INPUT_DATA_WIDTH 64

# Reset from DAC GPIO bit[1]
ad_ip_instance xlslice reset_slice
ad_ip_parameter reset_slice CONFIG.DIN_FROM 1
ad_ip_parameter reset_slice CONFIG.DIN_TO 1
ad_connect reset_slice/Dout dvbs2_encoder_wrapper_0/rst_n
ad_connect axi_ad9361/up_dac_gpio_out reset_slice/Din

ad_cpu_interconnect 0x43C10000 dvbs2_encoder_wrapper_0

# ── Width Converters ────────────────────────────────────────────────────────
# Encoder output (32b) and RRC (32b) don't match the 64b switches.
# Three converters keep the switches uniform at 64-bit:
#   dw_enc_out:  encoder m_axis (32b) → 64b → switchfir/S01
#   dw_rrc_in:   switchfir/M01 (64b) → 32b → RRC input
#   dw_rrc_out:  RRC output (32b) → 64b → switchdest/S00

ad_ip_instance axis_dwidth_converter dw_enc_out
ad_ip_parameter dw_enc_out CONFIG.S_TDATA_NUM_BYTES 4
ad_ip_parameter dw_enc_out CONFIG.M_TDATA_NUM_BYTES 8
ad_connect sys_cpu_clk dw_enc_out/aclk
ad_connect sys_cpu_resetn dw_enc_out/aresetn

ad_ip_instance axis_dwidth_converter dw_rrc_in
ad_ip_parameter dw_rrc_in CONFIG.S_TDATA_NUM_BYTES 8
ad_ip_parameter dw_rrc_in CONFIG.M_TDATA_NUM_BYTES 4
ad_connect sys_cpu_clk dw_rrc_in/aclk
ad_connect sys_cpu_resetn dw_rrc_in/aresetn

ad_ip_instance axis_dwidth_converter dw_rrc_out
ad_ip_parameter dw_rrc_out CONFIG.S_TDATA_NUM_BYTES 4
ad_ip_parameter dw_rrc_out CONFIG.M_TDATA_NUM_BYTES 8
ad_connect sys_cpu_clk dw_rrc_out/aclk
ad_connect sys_cpu_resetn dw_rrc_out/aresetn

# ── Clock Domain Crossing FIFO ──────────────────────────────────────────────
# Bridges sys_cpu_clk (switch chain, 64b) → divclk (upack → rfifo → AD9361)

ad_ip_instance axis_data_fifo interclk
ad_ip_parameter interclk CONFIG.FIFO_DEPTH 16
ad_ip_parameter interclk CONFIG.FIFO_MODE 1
ad_ip_parameter interclk CONFIG.IS_ACLK_ASYNC 1
ad_ip_parameter interclk CONFIG.HAS_TLAST.VALUE_SRC USER
ad_ip_parameter interclk CONFIG.HAS_TLAST 0

ad_connect sys_cpu_clk                interclk/s_axis_aclk
ad_connect util_ad9361_divclk/clk_out interclk/m_axis_aclk
ad_connect sys_cpu_resetn             interclk/s_axis_aresetn

# ── RRC Interpolation Filter (32-bit: 2 paths × 16-bit) ─────────────────────

set rrc_2interpol [ create_bd_cell -type ip -vlnv xilinx.com:ip:fir_compiler:7.2 rrc_2interpol ]
set_property -dict [ list \
    CONFIG.Clock_Frequency {61.44} \
    CONFIG.CoefficientSource {COE_File} \
    CONFIG.Coefficient_File "$::tezuka_hdl_dir/common/rrc_interp_firwin2.coe" \
    CONFIG.Coefficient_Fractional_Bits {0} \
    CONFIG.Coefficient_Sets {2} \
    CONFIG.Coefficient_Sign {Signed} \
    CONFIG.Coefficient_Structure {Inferred} \
    CONFIG.Coefficient_Width {16} \
    CONFIG.ColumnConfig {17} \
    CONFIG.DATA_Has_TLAST {Not_Required} \
    CONFIG.Data_Fractional_Bits {0} \
    CONFIG.Decimation_Rate {1} \
    CONFIG.Filter_Architecture {Systolic_Multiply_Accumulate} \
    CONFIG.Filter_Type {Interpolation} \
    CONFIG.Interpolation_Rate {4} \
    CONFIG.M_DATA_Has_TREADY {true} \
    CONFIG.Number_Channels {1} \
    CONFIG.Number_Paths {2} \
    CONFIG.Output_Rounding_Mode {Symmetric_Rounding_to_Zero} \
    CONFIG.Output_Width {16} \
    CONFIG.Quantization {Integer_Coefficients} \
    CONFIG.RateSpecification {Frequency_Specification} \
    CONFIG.S_DATA_Has_FIFO {true} \
    CONFIG.Sample_Frequency {15.36} \
    CONFIG.Zero_Pack_Factor {1} \
] $rrc_2interpol

ad_connect sys_cpu_clk rrc_2interpol/aclk

# FIR coefficient set select from DAC GPIO bit[2]
ad_ip_instance xlslice select_fir
ad_ip_parameter select_fir CONFIG.DIN_FROM 2
ad_ip_parameter select_fir CONFIG.DIN_TO 2
ad_connect select_fir/Dout rrc_2interpol/s_axis_config_tdata
ad_connect axi_ad9361/up_dac_gpio_out select_fir/Din

# FIR config valid from DAC GPIO bit[3]
ad_ip_instance xlslice select_fir_valid
ad_ip_parameter select_fir_valid CONFIG.DIN_FROM 3
ad_ip_parameter select_fir_valid CONFIG.DIN_TO 3
ad_connect select_fir_valid/Dout rrc_2interpol/s_axis_config_tvalid
ad_connect axi_ad9361/up_dac_gpio_out select_fir_valid/Din

# ── Wire the Switch Chain ───────────────────────────────────────────────────
#
#  DMA(64b) ──▶ dma_domain_fifo ──▶ switchsrc
#    M00(64b) ──▶ encoder(64→32) ──▶ dw_enc_out(32→64) ──▶ switchfir/S01
#    M01(64b) ──────────────────────────────────────────────▶ switchfir/S00
#
#  switchfir
#    M01(64b) ──▶ dw_rrc_in(64→32) ──▶ RRC(32→32) ──▶ dw_rrc_out(32→64) ──▶ switchdest/S00
#    M00(64b) ─────────────────────────────────────────────────────────────▶ switchdest/S01
#
#  switchdest(64b) ──▶ interclk ──[divclk]──▶ upack(64b)

# DMA → domain FIFO → source switch
ad_connect axi_ad9361_dac_dma/m_axis        dma_domain_fifo/S_AXIS
ad_connect dma_domain_fifo/M_AXIS           switchsrc/S00_AXIS

# Encoder path: switchsrc → encoder → 32-to-64 → switchfir
ad_connect switchsrc/M00_AXIS               dvbs2_encoder_wrapper_0/s_axis
ad_connect dvbs2_encoder_wrapper_0/m_axis    dw_enc_out/S_AXIS
ad_connect dw_enc_out/M_AXIS                switchfir/S01_AXIS

# IQ passthrough path: switchsrc → switchfir
ad_connect switchsrc/M01_AXIS               switchfir/S00_AXIS

# RRC path: switchfir → 64-to-32 → RRC → 32-to-64 → switchdest
ad_connect switchfir/M01_AXIS               dw_rrc_in/S_AXIS
ad_connect dw_rrc_in/M_AXIS                 rrc_2interpol/S_AXIS_DATA
ad_connect rrc_2interpol/M_AXIS_DATA        dw_rrc_out/S_AXIS
ad_connect dw_rrc_out/M_AXIS               switchdest/S00_AXIS

# Bypass RRC path: switchfir → switchdest
ad_connect switchfir/M00_AXIS               switchdest/S01_AXIS

# Dest → clock crossing → upack
ad_connect switchdest/M00_AXIS              interclk/S_AXIS

# ── Reconnect to upack (in divclk domain, rfifo → AD9361 stays untouched) ──
ad_connect interclk/M_AXIS                 util_ad9361_dac_upack/s_axis
