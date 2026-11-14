# simulate.do : ModelSim ASE 仿真脚本（在 D:\exp3_fifo_macro\sim 下运行）
# 注意：-L altera_mf_ver 加载 Verilog 版宏模块库；
# +define+SIM_PLL_IV 让 PLL 用 Cyclone IV E 行为模型仿真（ASE 的 Cyclone V 模型不输出时钟）。
vlib sim_work
vlog -work sim_work +define+SIM_PLL_IV ../rtl/pll_sys.v ../rtl/fifo_buf.v ../rtl/uart_rx.v ../rtl/seg7_ascii.v ../rtl/seg7_hex.v ../rtl/fifo_macro_top.v
vlog -work sim_work tb_fifo_macro_top.sv
vsim -L altera_mf_ver -voptargs=+acc sim_work.tb_fifo_macro_top
run -all
