# Clock domain crossing constraints for the symfront IP (scoped to the IP
# instance). Clocks: s_axi_lite_clk (100 MHz), iq_clk (AD9361 sample clock),
# proc_clk (125 MHz).

# First stage of the Amaranth FFSynchronizers (enable, overflow, AsyncFIFO
# gray-code pointers, RegisterCDC toggles)
set_false_path -to [get_cells -hier -filter {amaranth.vivado.false_path == "TRUE"}]

# AsyncFIFO reset synchronizers (asynchronous preset)
set_false_path -to [get_pins -of_objects [get_cells -hier -filter {amaranth.vivado.false_path_pre == "TRUE"}] -filter {REF_PIN_NAME == PRE}]

# RegisterCDC data registers: stable when the synchronized toggle arrives
set_false_path -to [get_pins -hierarchical "*cdc_request_data_dest_reg*/D"]
set_false_path -to [get_pins -hierarchical "*cdc_response_data_dest_reg*/D"]

# AsyncFIFO storage (distributed RAM written in one domain, read in the
# other): bound the datapath to the fastest clock period
set_max_delay -datapath_only -from [get_cells -hier -filter {NAME =~ *fifo_in/storage_reg* && IS_SEQUENTIAL}] 8.0
set_max_delay -datapath_only -from [get_cells -hier -filter {NAME =~ *fifo_out/storage_reg* && IS_SEQUENTIAL}] 8.0
