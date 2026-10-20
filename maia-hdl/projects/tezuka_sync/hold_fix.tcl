###############################################################################
# Vivado 2025 hold-timing fix hook.
# Registered as STEPS.POST_ROUTE_PHYS_OPT_DESIGN.TCL.PRE
#
# Root cause (AMD confirmed, known bug): the Vivado 2025 router silently stops
# fixing hold violations, leaving small WHS violations (-0.010 to -0.200 ns)
# that phys_opt_design -hold_fix alone cannot resolve because the violations
# are routing-topology induced (paths too short due to aggressive placement).
#
# Workaround from AMD engineer chaowen: re-run route_design here so the router
# gets a second pass at fixing hold via routing detours.  phys_opt_design
# -directive Explore then runs as the main POST_ROUTE_PHYS_OPT_DESIGN step
# (setup fix), and the checkpoint is saved automatically with both fixes.
###############################################################################
puts "INFO: hold_fix.tcl: re-running route_design to fix hold violations (Vivado 2025 workaround)"
route_design
puts "INFO: hold_fix.tcl: done"
