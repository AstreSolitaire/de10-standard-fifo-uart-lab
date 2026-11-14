// fifo_buf.v : FIFO 宏功能模块（scfifo，同步 FIFO）
// 等价于 MegaWizard Plug-In Manager 生成的包装文件。
// 配置：数据位宽 8 bit，深度 32 字，半满（almost_full）阈值 = 16。
// 半满标志 half_full 是本实验核心触发信号：存储数据量达到深度一半时置位。
module fifo_buf (
    input        clock,        // 同步 FIFO：读写使用同一时钟
    input        sclr,         // 同步清零（复位时清空 FIFO）
    input  [7:0] data,         // 写数据（UART 接收到的 ASCII 字符）
    input        wrreq,        // 写请求
    input        rdreq,        // 读请求
    output       almost_full,  // 半满标志：usedw >= 16 时置位
    output       empty,        // 空标志
    output       full,         // 满标志
    output [7:0] q,            // 读出数据
    output [4:0] usedw         // 当前存储字数（0~31）
);

    scfifo scfifo_component (
        .clock       (clock),
        .sclr        (sclr),
        .data        (data),
        .wrreq       (wrreq),
        .rdreq       (rdreq),
        .almost_full (almost_full),
        .empty       (empty),
        .full        (full),
        .q           (q),
        .usedw       (usedw)
    );

    defparam
        scfifo_component.add_ram_output_register  = "OFF",
        scfifo_component.almost_full_value        = 16,        // 半满阈值 = 深度一半
        scfifo_component.intended_device_family   = "Cyclone V",
        scfifo_component.lpm_numwords             = 32,        // FIFO 深度 32 字
        scfifo_component.lpm_showahead            = "OFF",     // 普通（legacy）读出时序
        scfifo_component.lpm_type                 = "SCFIFO",
        scfifo_component.lpm_width                = 8,         // 位宽 8 bit
        scfifo_component.lpm_widthu               = 5,
        scfifo_component.overflow_checking        = "ON",
        scfifo_component.underflow_checking       = "ON",
        scfifo_component.use_eab                  = "ON";

endmodule
