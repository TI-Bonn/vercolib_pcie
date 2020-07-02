set_property IOSTANDARD LVCMOS18 [get_ports sys_rst_n]
set_property PACKAGE_PIN AV35 [get_ports sys_rst_n]
set_property PULLUP true [get_ports sys_rst_n]

set_property LOC IBUFDS_GTE2_X1Y5 [get_cells */refclk_ibuf]

create_clock -period 10.000 -name sys_clk [get_ports sys_clk_p]

set_false_path -from [get_ports sys_rst_n]






