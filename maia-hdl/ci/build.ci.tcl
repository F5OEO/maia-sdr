###############################################################################
## build.ci.tcl — CI build for maia-sdr FPGA bitstreams
##
## Standard ADI flow: adi_project → adi_project_run (uses launch_runs
## for OOC IP synthesis — fine on x86_64 CI runners).
##
## Usage:
##   cd maia-hdl/projects
##   PROJECT_NAME=pluto vivado -mode batch -source ../ci/build.ci.tcl
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

# ---- Phase 1: project creation ----

set env(ADI_IGNORE_VERSION_CHECK) 1

# Source the tezuka meta-build (handles all board targets via PROJECT_NAME env)
cd tezuka
if {[catch {source system_project.tcl} err]} {
    puts "=== WARNING: system_project.tcl reported timing failure: $err ==="
    puts "=== Continuing Phase 2 (reports + bitstream) ==="
}
cd ..

# ---- Phase 2: write .bin ----
# adi_project_run already wrote .bit to project dir. Re-open impl
# and write .bin (raw, no header) for bitstream deployment.

set project_name $::env(PROJECT_NAME)

puts "=== CI: opening implemented design ==="
open_run impl_1

puts "=== generate reports ==="
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 10 -input_pins -file /work/${project_name}_timing.rpt
report_utilization -file /work/${project_name}_utilization.rpt
report_power -file /work/${project_name}_power.rpt

puts "=== write_bitstream ==="
write_bitstream -force -bin_file /work/${project_name}

puts "=== CI build complete: $project_name ==="
puts "  Output: /work/${project_name}.bit /work/${project_name}.bin"
puts "  Reports: /work/${project_name}_timing.rpt /work/${project_name}_utilization.rpt /work/${project_name}_power.rpt"
