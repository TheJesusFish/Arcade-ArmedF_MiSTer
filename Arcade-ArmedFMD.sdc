derive_pll_clocks
derive_clock_uncertainty

# i8751 gated-clock domain: 8-cycle multicycle to and from the MC8051 core.
set mcu_gated [add_to_collection [get_registers {*|i8751:*|mc8051_core:u_mcu|*}] \
               [add_to_collection [get_registers {*|i8751:*|dual_port_ram:u_prom|*}] \
                                  [get_registers {*|i8751:*|dual_port_ram:u_iram|*}]]]
set mcu_src    [add_to_collection $mcu_gated [get_registers {*|i8751:*|mcu_in_*}]]
set mcu_dst    [add_to_collection $mcu_gated [get_registers {*|i8751:*|mcu_out_*}]]

set_multicycle_path -setup -end 8 -from $mcu_src -to $mcu_dst
set_multicycle_path -hold  -end 7 -from $mcu_src -to $mcu_dst
