# exp3_fifo_macro.sdc : 时序约束
# 50 MHz 外部参考时钟，PLL 输出时钟由 derive_pll_clocks 自动生成
create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]
derive_pll_clocks
derive_clock_uncertainty
