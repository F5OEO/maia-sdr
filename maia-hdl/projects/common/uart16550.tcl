# 16550-compatible UART (baudrate set at runtime by the divisor latch).
# Clocked by sys_cpu_clk (100 MHz): DT node needs
# compatible = "ns16550a"; reg-shift = <2>; reg-io-width = <4>; clock-frequency = <100000000>;
ad_ip_instance axi_uart16550 miniserial
ad_connect miniserial/sout serial_tx
ad_connect miniserial/sin serial_rx
# No modem lines: CTS/DSR/DCD asserted (active low), RI deasserted
ad_connect miniserial/ctsn GND
ad_connect miniserial/dsrn GND
ad_connect miniserial/dcdn GND
ad_connect miniserial/rin VCC
ad_connect miniserial/freeze GND
ad_cpu_interrupt ps-15 mb-15 miniserial/ip2intc_irpt
ad_connect sys_cpu_resetn miniserial/s_axi_aresetn
ad_connect sys_cpu_clk miniserial/s_axi_aclk
ad_cpu_interconnect 0x42C00000 miniserial
