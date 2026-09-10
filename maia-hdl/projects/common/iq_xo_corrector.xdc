# AXI configuration enters iq_xo_corrector asynchronously. Only the first
# metastability stage is a false timing path; all subsequent synchronizer
# stages remain timed in the sample-clock domain.
#
# The multi-bit FTW/control buses are held stable by software before the apply
# toggle changes. The toggle has an additional synchronizer stage, so the
# settled buses are captured coherently after crossing this boundary.

set xo_cfg_meta_pins [get_pins -quiet -hier -regexp \
    {.*iq_xo_corrector.*/cfg_(rx_ftw|tx_ftw|control)_meta_reg\[[0-9]+\]/D}]

set xo_apply_meta_pin [get_pins -quiet -hier -regexp \
    {.*iq_xo_corrector.*/apply_sync_reg\[0\]/D}]

if {[llength $xo_cfg_meta_pins] != 68} {
    puts "CRITICAL WARNING: XO corrector expected 68 configuration CDC pins, found [llength $xo_cfg_meta_pins]"
}

if {[llength $xo_apply_meta_pin] != 1} {
    puts "CRITICAL WARNING: XO corrector expected one apply-toggle CDC pin, found [llength $xo_apply_meta_pin]"
}

set_false_path -to $xo_cfg_meta_pins
set_false_path -to $xo_apply_meta_pin
