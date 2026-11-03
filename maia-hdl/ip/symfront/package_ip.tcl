# Package SymFront IP core (maia_hdl/symfront.py)

create_project symfront . -force
add_files symfront.v
add_files -fileset constrs_1 -norecurse ../symfront.xdc
set_property top top [current_fileset]
load_features ipservices
ipx::package_project -import_files -root_dir . -vendor maia-sdr.org -library user -taxonomy /Maia-SDR -force
set_property name symfront [ipx::current_core]
set_property library user [ipx::current_core]
set_property display_name {DVB-S2 Symbol Front End} [ipx::current_core]
set_property description {DVB-S2 symbol front end: NCO mixer, interpolator, Gardner timing loop and AGC, one symbol per output strobe; bypass when disabled} [ipx::current_core]
set_property vendor_display_name {Maia SDR} [ipx::current_core]
set_property company_url {https://maia-sdr.org} [ipx::current_core]
set_property version $::env(IP_CORE_VERSION) [ipx::current_core]

# s_axi_lite_clk interface
ipx::add_bus_interface s_axi_lite_clk [ipx::current_core]
set_property abstraction_type_vlnv xilinx.com:signal:clock_rtl:1.0 \
    [ipx::get_bus_interfaces s_axi_lite_clk -of_objects [ipx::current_core]]
set_property bus_type_vlnv xilinx.com:signal:clock:1.0 \
    [ipx::get_bus_interfaces s_axi_lite_clk -of_objects [ipx::current_core]]
ipx::add_bus_parameter FREQ_HZ \
    [ipx::get_bus_interfaces s_axi_lite_clk -of_objects [ipx::current_core]]
ipx::add_port_map CLK \
    [ipx::get_bus_interfaces s_axi_lite_clk -of_objects [ipx::current_core]]
set_property physical_name s_axi_lite_clk \
    [ipx::get_port_maps CLK \
         -of_objects [ipx::get_bus_interfaces s_axi_lite_clk -of_objects [ipx::current_core]]]

# s_axi_lite_rst interface (auto-detected by Vivado)
ipx::add_bus_parameter POLARITY \
    [ipx::get_bus_interfaces s_axi_lite_rst -of_objects [ipx::current_core]]
set_property value ACTIVE_HIGH \
    [ipx::get_bus_parameters POLARITY \
         -of_objects [ipx::get_bus_interfaces s_axi_lite_rst -of_objects [ipx::current_core]]]

# iq_clk interface (IQ processing clock)
ipx::add_bus_interface iq_clk [ipx::current_core]
set_property abstraction_type_vlnv xilinx.com:signal:clock_rtl:1.0 \
    [ipx::get_bus_interfaces iq_clk -of_objects [ipx::current_core]]
set_property bus_type_vlnv xilinx.com:signal:clock:1.0 \
    [ipx::get_bus_interfaces iq_clk -of_objects [ipx::current_core]]
ipx::add_bus_parameter FREQ_HZ \
    [ipx::get_bus_interfaces iq_clk -of_objects [ipx::current_core]]
ipx::add_port_map CLK \
    [ipx::get_bus_interfaces iq_clk -of_objects [ipx::current_core]]
set_property physical_name iq_clk \
    [ipx::get_port_maps CLK \
         -of_objects [ipx::get_bus_interfaces iq_clk -of_objects [ipx::current_core]]]

# iq_rst interface (auto-detected by Vivado from 'iq_rst' port)
ipx::add_bus_parameter POLARITY \
    [ipx::get_bus_interfaces iq_rst -of_objects [ipx::current_core]]
set_property value ACTIVE_HIGH \
    [ipx::get_bus_parameters POLARITY \
         -of_objects [ipx::get_bus_interfaces iq_rst -of_objects [ipx::current_core]]]

# proc_clk interface (processing clock, at least 8 cycles per input sample)
ipx::add_bus_interface proc_clk [ipx::current_core]
set_property abstraction_type_vlnv xilinx.com:signal:clock_rtl:1.0 \
    [ipx::get_bus_interfaces proc_clk -of_objects [ipx::current_core]]
set_property bus_type_vlnv xilinx.com:signal:clock:1.0 \
    [ipx::get_bus_interfaces proc_clk -of_objects [ipx::current_core]]
ipx::add_bus_parameter FREQ_HZ \
    [ipx::get_bus_interfaces proc_clk -of_objects [ipx::current_core]]
ipx::add_port_map CLK \
    [ipx::get_bus_interfaces proc_clk -of_objects [ipx::current_core]]
set_property physical_name proc_clk \
    [ipx::get_port_maps CLK \
         -of_objects [ipx::get_bus_interfaces proc_clk -of_objects [ipx::current_core]]]

# proc_rst interface (auto-detected by Vivado from 'proc_rst' port)
ipx::add_bus_parameter POLARITY \
    [ipx::get_bus_interfaces proc_rst -of_objects [ipx::current_core]]
set_property value ACTIVE_HIGH \
    [ipx::get_bus_parameters POLARITY \
         -of_objects [ipx::get_bus_interfaces proc_rst -of_objects [ipx::current_core]]]

# associate s_axi_lite to s_axi_lite_clk (auto-detected by Vivado)
ipx::associate_bus_interfaces -busif s_axi_lite -clock s_axi_lite_clk [ipx::current_core]

ipx::create_xgui_files [ipx::current_core]
ipx::save_core [ipx::current_core]
