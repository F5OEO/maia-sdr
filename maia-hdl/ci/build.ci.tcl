###############################################################################
## build.ci.tcl — In-process CI build for maia-sdr FPGA bitstreams
##
## Replaces adi_project_run (which uses launch_runs → child-process crash
## under Rosetta) with in-process synth/impl/bitstream.
##
## Usage:
##   cd maia-hdl/projects
##   PROJECT_NAME=pluto vivado -mode batch -source ../ci/build.ci.tcl
##
## Two-phase approach:
##   1. Source system_project.tcl with ADI_SKIP_SYNTHESIS=1 — creates project
##      and block design, generates IP output products, but skips the
##      launch_runs-based synth/impl.
##   2. Run synth_design, opt_design, place_design, route_design,
##      write_bitstream directly (in-process, no child processes).
##
## Required env: PROJECT_NAME — one of the supported board targets.
## Output: /work/${PROJECT_NAME}.bit + /work/${PROJECT_NAME}.bin
###############################################################################

# ---- Phase 0: copy custom IPs into ADI library path ----
# adi_project sets ip_repo_paths = $ad_hdl_dir/library only.
# Custom IPs (maia-sdr, dvbs2rx, etc.) must live there to be found.
set custom_ip_dir [file normalize "../ip"]
set adi_lib [file normalize "../adi-hdl/library"]
puts "=== Phase 0: copying custom IPs to ADI library ==="
foreach ip_type [glob -nocomplain -dir $custom_ip_dir *] {
    if {![file isdirectory $ip_type]} { continue }
    foreach cfg [glob -nocomplain -dir $ip_type *] {
        if {![file isdirectory $cfg]} { continue }
        set comp_xml [file join $cfg component.xml]
        if {[file exists $comp_xml]} {
            set ip_name [file tail $cfg]
            set dest [file join $adi_lib $ip_name]
            if {![file exists $dest]} {
                file copy -force $cfg $dest
                puts "  copied $ip_name"
            }
        }
    }
}
puts "=== Phase 0 complete ==="

# ---- Phase 1: project creation (skip launch_runs) ----

set env(ADI_SKIP_SYNTHESIS) 1
set env(ADI_IGNORE_VERSION_CHECK) 1

# Source the tezuka meta-build (handles all board targets via PROJECT_NAME env)
cd tezuka
source system_project.tcl
cd ..

unset env(ADI_SKIP_SYNTHESIS)

# ---- Phase 2: in-process synthesis & implementation ----

set project_name $::env(PROJECT_NAME)
set part [get_property PART [current_project]]
set top [get_property TOP [current_fileset]]

puts "=== CI build: $project_name (part=$part top=$top) ==="

# Upgrade IPs if needed (handles Vivado version mismatches)
foreach ip [get_ips] {
    if {[catch {upgrade_ip $ip -quiet} err]} {
        puts "  IP $ip: $err (skipping)"
    }
}
generate_target all [get_ips]

# Suppress common warnings
set_msg_config -id {Synth 8-7129} -suppress
set_msg_config -id {Synth 8-3917} -suppress
set_msg_config -id {Synth 8-7071} -suppress
set_msg_config -id {Synth 8-7023} -suppress
set_msg_config -id {Board 49-26} -suppress

# Enable bitstream compression
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

set_param general.maxBackupLogs 0

# Synthesis
puts "=== synth_design ==="
synth_design -top $top -part $part
report_timing_summary -file /work/timing_synth_${project_name}.rpt

# Optimization
puts "=== opt_design ==="
opt_design

# Placement with aggressive directives (from reference rules)
puts "=== place_design ==="
place_design -directive ExtraTimingOpt

puts "=== phys_opt_design ==="
phys_opt_design -directive AggressiveExplore

# Routing
puts "=== route_design ==="
route_design

# Reports
report_timing_summary -file /work/timing_impl_${project_name}.rpt
report_utilization -file /work/utilization_${project_name}.rpt
report_drc -file /work/drc_${project_name}.rpt
report_methodology -file /work/methodology_${project_name}.rpt
report_power -file /work/power_${project_name}.rpt

# Bitstream (.bit with header + .bin raw for uhd_image_loader)
puts "=== write_bitstream ==="
write_bitstream -force -bin_file /work/${project_name}

puts "=== CI build complete: $project_name ==="
puts "  Output: /work/${project_name}.bit /work/${project_name}.bin"
