// pll_sys.v : PLL 锁相环宏功能模块（altpll）
// 等价于 MegaWizard Plug-In Manager 生成的基本包装文件（I/O 版本）。
// 配置：输入 50 MHz，输出 c0 = 50 MHz（主时钟），c1 = 100 MHz（备用/扩展）。
// 实验报告截图可打开 MegaWizard 选中 ip/pll_sys 重新查看这些参数。
module pll_sys (
    input      inclk0,   // 50 MHz 参考时钟，必须来自专用时钟引脚 PIN_AF14
    input      areset,   // 异步复位（高有效）
    output     c0,       // 50 MHz 主时钟：UART / FIFO / 显示控制统一时钟域
    output     c1,       // 100 MHz 备用时钟输出
    output     locked    // 锁定指示，锁定后（高电平）才释放内部复位
);

    wire [1:0]  sub_wire_clk;
    wire        sub_wire_locked;

    assign c0     = sub_wire_clk[0];
    assign c1     = sub_wire_clk[1];
    assign locked = sub_wire_locked;

    altpll altpll_component (
        .inclk  ({1'b0, inclk0}),   // inclk[1] 未用，inclk[0] 接外部参考时钟
        .clk    (sub_wire_clk),
        .areset (areset),
        .locked (sub_wire_locked)
    );

    defparam
        altpll_component.bandwidth_type          = "AUTO",
        altpll_component.clk0_divide_by          = 1,
        altpll_component.clk0_duty_cycle         = 50,
        altpll_component.clk0_multiply_by        = 1,
        altpll_component.clk0_phase_shift        = "0",
        altpll_component.clk1_divide_by          = 1,
        altpll_component.clk1_duty_cycle         = 50,
        altpll_component.clk1_multiply_by        = 2,
        altpll_component.clk1_phase_shift        = "0",
        altpll_component.compensate_clock        = "CLK0",
        altpll_component.inclk0_input_frequency  = 20000,   // 20 ns = 50 MHz
        // 器件族：综合用 Cyclone V。仿真时（ModelSim ASE 10.1d 的 Cyclone V
        // 通用 PLL 行为模型不输出时钟）加 +define+SIM_PLL_IV 切到 Cyclone IV E
        // 行为模型，仅影响仿真，不影响综合结果。
        altpll_component.intended_device_family  =
`ifdef SIM_PLL_IV
            "Cyclone IV E"
`else
            "Cyclone V"
`endif
        ,
        altpll_component.lpm_type                = "ALTPLL",
        altpll_component.operation_mode          = "NORMAL",
        altpll_component.pll_type                = "AUTO";

endmodule
