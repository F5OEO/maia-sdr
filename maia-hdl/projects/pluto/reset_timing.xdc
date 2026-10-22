# Implementation-only constraints (maia_iio builds). Read after synthesis, when the cells exist.
# (Constraints in system_constr.xdc are read at synth_design, before the
# Xilinx-generated AXI HP2 interconnect internals exist, so cell-based
# false paths there match nothing.)

# Asynchronous reset pins inside the AXI HP2 interconnect's FIFOs (clk_fpga_0
# -> 187.5 MHz clock). Only the PRE/CLR control pins are covered, so the only
# checks waived are recovery/removal on those resets; the FIFO data paths are
# still timed. Reset release is handled by the FIFO's own reset synchronizers.
set_false_path -to [get_pins -hierarchical -filter {NAME =~ *axi_hp2_interconnect*/PRE}]
set_false_path -to [get_pins -hierarchical -filter {NAME =~ *axi_hp2_interconnect*/CLR}]

# Peripheral reset from the system reset generator (sys_rstgen, 100 MHz PS
# clock) into asynchronous PRE/CLR pins in the faster clock domains. Scoped to
# the async pins only, so the generator's synchronous reset logic stays timed.
set_false_path -from [get_pins -hierarchical -filter {NAME =~ *sys_rstgen/U0/*/C}] -to [get_pins -hierarchical -filter {NAME =~ */CLR}]
set_false_path -from [get_pins -hierarchical -filter {NAME =~ *sys_rstgen/U0/*/C}] -to [get_pins -hierarchical -filter {NAME =~ */PRE}]
set_false_path -from [get_pins -hierarchical -filter {NAME =~ *sys_rstgen/U0/*/C}] -to [get_pins -hierarchical -filter {NAME =~ */RST}]

# Raw-capture FIFO reset (Recorder16IQ): fifo_run is in the DMA clock domain
# and the async FIFO's write side is in the 187.5 MHz domain. The recorder
# enforces the release ordering itself (run_delay: reset deasserted at least
# two read cycles before the first write), so the recovery/removal check on
# this RST pin is not the real constraint.
set_false_path -from [get_pins -hierarchical -filter {NAME =~ *raw_capture/fifo_run_reg/C}] -to [get_pins -hierarchical -filter {NAME =~ *raw_capture/fifo/fifo18e1/RST}]
