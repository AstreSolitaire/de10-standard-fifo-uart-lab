// seg7_hex.v : 4bit 十六进制数 -> 七段数码管段码（0~F），用于显示 FIFO 剩余字数
// 段码顺序 seg[6:0] = {g,f,e,d,c,b,a}，低电平点亮。
module seg7_hex (
    input  [3:0] din,
    output reg [6:0] seg
);

    always @(*) begin
        case (din)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;
            4'hF: seg = 7'b0001110;
        endcase
    end

endmodule
