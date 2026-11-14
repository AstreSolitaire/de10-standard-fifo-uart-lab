// seg7_ascii.v : ASCII 字符 -> 七段数码管段码译码
// 段码顺序 seg[6:0] = {g,f,e,d,c,b,a}，共阳数码管，低电平点亮。
// 可显示字符：数字 0-9、字母 A-Z（少数字形近似）、'-'。其余字符显示空白。
module seg7_ascii (
    input  [7:0] ascii,
    output [6:0] seg          // {g,f,e,d,c,b,a}，0 = 点亮
);

    function [6:0] segmap (input [7:0] c);
        case (c)
            "0":        segmap = 7'b1000000;
            "1":        segmap = 7'b1111001;
            "2":        segmap = 7'b0100100;
            "3":        segmap = 7'b0110000;
            "4":        segmap = 7'b0011001;
            "5":        segmap = 7'b0010010;
            "6":        segmap = 7'b0000010;
            "7":        segmap = 7'b1111000;
            "8":        segmap = 7'b0000000;
            "9":        segmap = 7'b0010000;
            "A", "a":   segmap = 7'b0001000;
            "B", "b":   segmap = 7'b0000011;
            "C", "c":   segmap = 7'b1000110;
            "D", "d":   segmap = 7'b0100001;
            "E", "e":   segmap = 7'b0000110;
            "F", "f":   segmap = 7'b0001110;
            "G", "g":   segmap = 7'b0100000;
            "H", "h":   segmap = 7'b1001000;
            "I", "i":   segmap = 7'b1001111;
            "J", "j":   segmap = 7'b1110001;
            "L", "l":   segmap = 7'b1000111;
            "O", "o":   segmap = 7'b1000000;
            "P", "p":   segmap = 7'b0001100;
            "Q", "q":   segmap = 7'b0011000;
            "R", "r":   segmap = 7'b0101111;
            "S", "s":   segmap = 7'b0010010;
            "T", "t":   segmap = 7'b0000111;
            "U", "u":   segmap = 7'b1000001;
            "Y", "y":   segmap = 7'b0010001;
            "Z", "z":   segmap = 7'b0100100;
            "-":        segmap = 7'b0111111;
            " ":        segmap = 7'b1111111;   // 空格显示空白
            default:    segmap = 7'b1111111;   // 无法显示的字符显示空白
        endcase
    endfunction

    assign seg = segmap(ascii);

endmodule
