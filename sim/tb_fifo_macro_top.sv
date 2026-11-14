// tb_fifo_macro_top.sv : 实验三自校验 testbench
// 验证内容：
//   1) UART 连续接收 16 个字符写入 FIFO；
//   2) FIFO 达到半满（16 字）时 LEDR0/LEDR1 置位，开始逐一显示；
//   3) 显示顺序与写入顺序一致（先进先出）；
//   4) FIFO 读空后显示流程结束（LEDR1=0）；
//   5) 拨动开关切换到快周期后，字符切换间隔明显缩短。
// 仿真时间参数：显示周期改小为 2000 周期（慢）/ 500 周期（快）。
`timescale 1ns/1ps

module tb_fifo_macro_top;

    localparam CLKP      = 20;          // 50 MHz，20 ns
    localparam CPB       = 434;         // 115200 波特率下每比特时钟数
    localparam SLOW_CYC  = 2000;
    localparam FAST_CYC  = 500;

    reg         CLOCK_50   = 1'b0;
    reg         KEY0       = 1'b1;
    reg         UART_RX    = 1'b1;
    reg         sw_period  = 1'b0;
    wire [6:0]  HEX0, HEX1, HEX2;
    wire [4:0]  LEDR;

    fifo_macro_top #(
        .PERIOD_SLOW (SLOW_CYC),
        .PERIOD_FAST (FAST_CYC)
    ) dut (
        .CLOCK_50  (CLOCK_50),
        .KEY0      (KEY0),
        .UART_RX   (UART_RX),
        .sw_period (sw_period),
        .HEX0      (HEX0),
        .HEX1      (HEX1),
        .HEX2      (HEX2),
        .LEDR      (LEDR)
    );

    always #(CLKP/2) CLOCK_50 = ~CLOCK_50;   // 20 ns 周期 = 50 MHz

    // ---- 发送一个字节（8-N-1，LSB 在前）----
    task send_byte (input [7:0] b);
        integer i;
        begin
            UART_RX = 1'b0;
            repeat (CPB) @(posedge CLOCK_50);      // 起始位
            for (i = 0; i < 8; i = i + 1) begin
                UART_RX = b[i];
                repeat (CPB) @(posedge CLOCK_50);  // 数据位
            end
            UART_RX = 1'b1;
            repeat (CPB) @(posedge CLOCK_50);      // 停止位
        end
    endtask

    // ---- 采样读出的显示字符（rd_dly 后一拍 disp_char 已更新）----
    reg [7:0] seen [0:31];
    reg [63:0] gap_cycles [0:31];
    integer seen_n = 0;
    reg        cap;
    reg [63:0] prev_time = 0;
    always @(posedge CLOCK_50) begin
        cap <= dut.rd_dly;
        if (cap) begin
            seen[seen_n]      = dut.disp_char;
            gap_cycles[seen_n] = ($time - prev_time) / CLKP;
            prev_time = $time;
            seen_n = seen_n + 1;
        end
    end

    // ---- 带超时的等待 ----
    task wait_sig_hi (input integer which_led, input integer max_cyc);
        integer g;
        begin
            g = 0;
            while (LEDR[which_led] !== 1'b1 && g < max_cyc) begin
                @(posedge CLOCK_50);
                g = g + 1;
            end
            if (g >= max_cyc) begin
                $display("[FAIL] LEDR[%0d] 超时未置位", which_led);
                $finish;
            end
        end
    endtask

    task wait_sig_lo (input integer which_led, input integer max_cyc);
        integer g;
        begin
            g = 0;
            while (LEDR[which_led] !== 1'b0 && g < max_cyc) begin
                @(posedge CLOCK_50);
                g = g + 1;
            end
            if (g >= max_cyc) begin
                $display("[FAIL] LEDR[%0d] 超时未清零", which_led);
                $finish;
            end
        end
    endtask

    integer errors = 0;
    integer i;
    reg [7:0] msg1 [0:15];
    reg [7:0] msg2 [0:15];
    reg [7:0] pre [0:1];

    initial begin
        // 第一轮消息 "0123456789ABCDEF"
        for (i = 0; i < 16; i = i + 1) msg1[i] = "0" + i;
        // 第二轮前缀 "AB"
        pre[0] = "A"; pre[1] = "B";
        // 第二轮补齐到半满的 14 个字符
        msg2[0]="A"; msg2[1]="B";
        for (i = 2; i < 16; i = i + 1) msg2[i] = "A" + i;   // A B C ... P

        // 复位
        KEY0 = 1'b0;
        repeat (20) @(posedge CLOCK_50);
        KEY0 = 1'b1;

        // 等 PLL 行为模型锁定、内部复位释放（约 1 us）
        begin : wait_lock
            integer wg;
            wg = 0;
            while ((dut.rst !== 1'b0) && wg < 20000) begin
                @(posedge CLOCK_50);
                wg = wg + 1;
            end
        end
        repeat (20) @(posedge CLOCK_50);

        if (LEDR[2] !== 1'b1) begin errors = errors + 1; $display("[FAIL] 复位后 FIFO 应为空 (LEDR2=1)"); end
        if (LEDR[1] !== 1'b0) begin errors = errors + 1; $display("[FAIL] 复位后显示流程不应启动"); end

        // ---- 第一轮：连续发送 16 字符，触发半满 ----
        $display("[INFO] 第一轮：发送 16 字符 ...");
        for (i = 0; i < 16; i = i + 1)
            send_byte(msg1[i]);

        // 半满应触发
        wait_sig_hi(0, 50000);          // LEDR0 half_full
        wait_sig_hi(1, 50000);          // LEDR1 disp_en
        $display("[INFO] 半满触发，显示流程启动 (LEDR0=1, LEDR1=1)");

        wait_sig_lo(1, 500000);         // FIFO 读空后显示流程结束
        $display("[INFO] FIFO 读空，显示流程结束，共读出 %0d 个字符", seen_n);

        if (seen_n != 16) begin
            errors = errors + 1;
            $display("[FAIL] 读出字符数 %0d != 16", seen_n);
        end
        for (i = 0; i < 16 && i < seen_n; i = i + 1)
            if (seen[i] !== msg1[i]) begin
                errors = errors + 1;
                $display("[FAIL] 第 %0d 个显示字符 %c != 发送的 %c", i, seen[i], msg1[i]);
            end

        // ---- 第二轮：先发 2 个（不触发），切快周期后再补到半满 ----
        $display("[INFO] 第二轮：切换 sw_period=1（快周期），先发 2 字符 ...");
        sw_period = 1'b1;
        send_byte(pre[0]);
        send_byte(pre[1]);
        repeat (50) @(posedge CLOCK_50);
        if (LEDR[1] !== 1'b0) begin
            errors = errors + 1;
            $display("[FAIL] 未达半满时显示流程不应启动");
        end

        $display("[INFO] 再发 14 字符补到半满 ...");
        for (i = 2; i < 16; i = i + 1)
            send_byte(msg2[i]);

        wait_sig_lo(1, 500000);
        if (seen_n != 32) begin
            errors = errors + 1;
            $display("[FAIL] 第二轮读出总数 %0d != 32", seen_n);
        end
        for (i = 16; i < 32 && i < seen_n; i = i + 1)
            if (seen[i] !== msg2[i-16]) begin
                errors = errors + 1;
                $display("[FAIL] 第 %0d 个显示字符 %c != 发送的 %c", i, seen[i], msg2[i-16]);
            end

        // 快周期间隔检查：读出间隔应约为 FAST_CYC 周期（考虑读延迟余量）
        for (i = 17; i < 32 && i < seen_n; i = i + 1)
            if (gap_cycles[i] < FAST_CYC - 60 || gap_cycles[i] > FAST_CYC + 100) begin
                errors = errors + 1;
                $display("[FAIL] 快周期字符间隔 %0d 周期不在 [%0d, %0d] 内",
                         gap_cycles[i], FAST_CYC-60, FAST_CYC+100);
            end
        $display("[INFO] 快周期显示间隔约 %0d 周期", gap_cycles[20]);

        if (errors == 0)
            $display("===== PASS：半满触发、FIFO 顺序读出、双显示周期 全部验证通过 =====");
        else
            $display("===== FAIL：共 %0d 处错误 =====", errors);
        $finish;
    end

    // 全局看门狗
    initial begin
        #40_000_000;
        $display("[FAIL] 仿真看门狗超时");
        $finish;
    end

endmodule
