# sweeper_it reset comes from axi_ad9361/rst (l_clk domain) and is
# synchronised to the maia_sdr clock inside the module. Only the asynchronous
# preset of the two synchroniser flops is a false path; the release through
# reset_sync is timed in the maia_sdr clock domain.

set sweeper_rst_pins [get_pins -quiet -hier -regexp \
    {.*sweeper_io.*/reset_sync_reg\[[01]\]/PRE}]

# Expect exactly 2 pins (reset_sync_reg[0..1]/PRE).
set_false_path -to $sweeper_rst_pins
