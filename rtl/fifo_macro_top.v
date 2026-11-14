// fifo_macro_top.v : 实验三顶层 —— 宏功能模块的使用（PLL + FIFO）
// 功能：电脑串口发送字符 -> UART 接收 -> 写入 FIFO 宏模块缓存
//       FIFO 半满触发 -> 逐一读出并通过数码管显示，拨动开关选择两种显示周期
module fifo_macro_top #(
    parameter CLK_HZ      = 50_000_000,
    parameter PERIOD_SLOW = 50_000_000,   
    parameter PERIOD_FAST = 12_500_000    
)(
    input        CLOCK_50,    // 50 MHz 专用时钟引脚 PIN_AF14
    input        KEY0,        
    input        UART_RX,     // 串口接收，接 USB 转 TTL 转接器 TX（JP1 第 1 针 GPIO_D0）
    input        sw_period,   
    output [6:0] HEX0,
    output [6:0] HEX1,
    output [6:0] HEX2,
    output [4:0] LEDR,
    output       GND_OUT      
);

    // ------------------------------------------------------------------
    // 1. PLL 锁相环宏模块：50 MHz 输入 -> c0 = 50 MHz 主时钟，c1 = 100 MHz
    // ------------------------------------------------------------------
    wire c0, c1, locked;

    pll_sys pll_sys_inst (
        .inclk0 (CLOCK_50),
        .areset (~KEY0),
        .c0     (c0),
        .c1     (c1),
        .locked (locked)
    );

    reg [2:0] rst_sh;
    always @(posedge c0) rst_sh <= {rst_sh[1:0], (~KEY0) | (~locked)};
    wire rst = rst_sh[2];

    // ------------------------------------------------------------------
    // 2. UART 接收：115200 8-N-1，接收完成脉冲作为 FIFO 写请求
    // ------------------------------------------------------------------
    wire [7:0] rx_data;
    wire       rx_done;

    uart_rx #(
        .CLK_HZ (CLK_HZ),
        .BAUD   (115200)
    ) uart_rx_inst (
        .clk     (c0),
        .rst     (rst),
        .rx      (UART_RX),
        .rx_data (rx_data),
        .rx_done (rx_done)
    );

    // ------------------------------------------------------------------
    // 3. FIFO 宏模块：8 bit x 32 字，半满阈值 16
    // ------------------------------------------------------------------
    reg disp_en;               // 显示流程使能：半满启动，空停止
    reg       rdreq;           // FIFO 读请求（单周期脉冲）
    reg       rd_dly;          
    reg [7:0] disp_char;       
    localparam CNT_W = 27;                    
    reg [CNT_W-1:0] pcnt;      // 显示周期计数器
    wire      half_full, f_empty, f_full;
    wire [7:0] f_q;
    wire [4:0] usedw;
    wire       wrreq = rx_done & (~f_full);

    fifo_buf fifo_buf_inst (
        .clock       (c0),
        .sclr        (rst),
        .data        (rx_data),
        .wrreq       (wrreq),
        .rdreq       (rdreq),
        .almost_full (half_full),
        .empty       (f_empty),
        .full        (f_full),
        .q           (f_q),
        .usedw       (usedw)
    );

    // ------------------------------------------------------------------
    // 4. 显示控制：半满启动，空停止；每个显示周期读出一个字符
    // ------------------------------------------------------------------
    always @(posedge c0) begin
        if (rst)              disp_en <= 1'b0;
        else if (half_full)   disp_en <= 1'b1;    
        else if (disp_en & f_empty) disp_en <= 1'b0;  
    end

    wire [CNT_W-1:0] period_slow_w = PERIOD_SLOW;
    wire [CNT_W-1:0] period_fast_w = PERIOD_FAST;
    wire [CNT_W-1:0] period = sw_period ? period_fast_w : period_slow_w;

    always @(posedge c0) begin
        if (rst) begin
            pcnt      <= {CNT_W{1'b0}};
            rdreq     <= 1'b0;
            rd_dly    <= 1'b0;
            disp_char <= 8'd0;
        end else begin
            rdreq  <= 1'b0;                      // 默认单周期脉冲
            rd_dly <= rdreq;
            if (rd_dly) begin                    // 读出数据已出现在 q 上
                disp_char <= f_q;
                pcnt      <= {CNT_W{1'b0}};
            end else if (disp_en & (~f_empty)) begin
                if (pcnt >= period - 1'b1) begin // 显示周期到，发起一次读
                    pcnt  <= {CNT_W{1'b0}};
                    rdreq <= 1'b1;
                end else
                    pcnt <= pcnt + 1'b1;
            end else
                pcnt <= {CNT_W{1'b0}};
        end
    end

    // ------------------------------------------------------------------
    // 5. 数码管与 LED 显示
    // ------------------------------------------------------------------
    seg7_ascii u_seg7_char (
        .ascii (disp_char),
        .seg   (HEX0)
    );

    seg7_hex u_seg7_cnt_lo (.din(usedw[3:0]), .seg(HEX1));
    seg7_hex u_seg7_cnt_hi (.din({3'b000, usedw[4]}), .seg(HEX2));

    assign LEDR[0] = half_full;   // 半满标志
    assign LEDR[1] = disp_en;     // 显示流程进行中
    assign LEDR[2] = f_empty;     // FIFO 空
    assign LEDR[3] = f_full;      // FIFO 满
    assign LEDR[4] = ~rst;        // 系统复位正常（PLL 锁定）指示

    assign GND_OUT = 1'b0;

endmodule
