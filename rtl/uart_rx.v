// uart_rx.v : UART 接收模块，8-N-1 格式，参数化波特率（默认 115200）。
// 50 MHz 主时钟下每比特 434 个时钟周期，在每比特中点采样，双寄存器同步防亚稳态。
module uart_rx #(
    parameter CLK_HZ = 50_000_000,
    parameter BAUD   = 115200
)(
    input        clk,
    input        rst,       // 同步复位，高有效
    input        rx,        // 串行输入，接 USB 转 TTL 转接器的 TX
    output reg [7:0] rx_data,
    output reg       rx_done // 接收完成单周期脉冲，作为 FIFO 写请求
);

    localparam CLKS_PER_BIT = CLK_HZ / BAUD;   // 50 MHz / 115200 = 434
    localparam HALF_BIT     = CLKS_PER_BIT / 2;

    localparam S_IDLE  = 2'd0,
               S_START = 2'd1,
               S_DATA  = 2'd2,
               S_STOP  = 2'd3;

    // 两级寄存器同步，防止输入亚稳态
    reg [1:0] rx_sync;
    always @(posedge clk) rx_sync <= {rx_sync[0], rx};
    wire rx_in   = rx_sync[1];
    wire rx_fall = rx_sync[1] & ~rx_sync[0];   // 下降沿（新值0旧值1）= 起始位到达

    reg [1:0]  state;
    reg [15:0] cnt;
    reg [2:0]  bit_idx;

    always @(posedge clk) begin
        if (rst) begin
            state   <= S_IDLE;
            cnt     <= 16'd0;
            bit_idx <= 3'd0;
            rx_data <= 8'd0;
            rx_done <= 1'b0;
        end else begin
            rx_done <= 1'b0;
            case (state)
                S_IDLE: begin
                    cnt <= 16'd0;
                    if (rx_fall)
                        state <= S_START;
                end
                S_START: begin
                    cnt <= cnt + 16'd1;
                    if (cnt == HALF_BIT - 1) begin       // 起始位中点
                        if (rx_in == 1'b0) begin         // 仍为低，确认起始位
                            state <= S_DATA;
                            cnt   <= 16'd0;
                            bit_idx <= 3'd0;
                        end else
                            state <= S_IDLE;             // 毛刺，放弃
                    end
                end
                S_DATA: begin
                    cnt <= cnt + 16'd1;
                    if (cnt == CLKS_PER_BIT - 1) begin   
                        cnt               <= 16'd0;
                        rx_data[bit_idx]  <= rx_in;      // LSB 在前
                        if (bit_idx == 3'd7)
                            state <= S_STOP;
                        else
                            bit_idx <= bit_idx + 3'd1;
                    end
                end
                S_STOP: begin
                    cnt <= cnt + 16'd1;
                    if (cnt == CLKS_PER_BIT - 1) begin   // 停止位中点
                        rx_done <= 1'b1;
                        state   <= S_IDLE;
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
