# 实验三：宏功能模块的使用（PLL + FIFO + UART 接收）

Terasic **DE10-Standard**（Cyclone V SoC 5CSXFC6D6F31C6）+ Quartus II 13.1 + Verilog HDL。

电脑串口发送字符 → FPGA 的 UART 接收并写入 **FIFO 宏模块（scfifo，8bit×32 字）** → FIFO 达到**半满（16 字）**后，数码管逐一显示缓存字符 → 拨动开关 SW0 切换两种显示周期（1.0s / 0.25s）。

## 功能

- **PLL 宏模块**（altpll）：50MHz 输入 → c0=50MHz 主时钟、c1=100MHz 备用，locked 门控复位
- **FIFO 宏模块**（scfifo）：8bit × 32 字，半满阈值 16（almost_full）
- **UART 接收**：115200-8-N-1，双寄存器同步 + 中点采样
- **显示**：HEX0 轮显字符（ASCII→七段译码）；HEX1/HEX2 实时显示 FIFO 剩余字数；LEDR0~4 状态指示
- **双显示周期**：SW0 拨动开关选择 1.0s / 0.25s，显示进行中随时生效

## 仓库结构

```
├── rtl/                      # 全部 Verilog 源码（6 个文件，405 行）
│   ├── fifo_macro_top.v      # 顶层：PLL/FIFO 例化 + 半满触发 FSM + 显示控制
│   ├── uart_rx.v             # UART 接收状态机（115200-8-N-1）
│   ├── pll_sys.v             # PLL 宏模块包装（altpll，c0=50M、c1=100M）
│   ├── fifo_buf.v            # FIFO 宏模块包装（scfifo，半满阈值16）
│   ├── seg7_ascii.v          # ASCII→七段译码
│   └── seg7_hex.v            # 4bit 十六进制→七段译码
├── sim/
│   ├── tb_fifo_macro_top.sv  # ModelSim 自校验 testbench（半满触发/顺序读出/双周期）
│   └── simulate.do
├── output_files/
│   └── exp3_fifo_macro.sof   # 已编译固件（可直接烧录）
├── scripts/
│   ├── 编译.bat               # 一键编译（自动管理源文件 BOM）
│   ├── 仿真.bat               # 一键 ModelSim 仿真
│   ├── bom.py                # BOM 管理工具
│   └── 串口助手.py            # 自制串口调试助手（Python+pyserial+tkinter）
├── docs/
│   ├── 操作说明.md            # 完整接线/烧录/调试手册
│   ├── 测试数据表.md          # T1~T8 测试数据与预期结果
│   ├── 代码逐行功能解析.pdf   # 全部 405 行逐行功能解析（14 页）
│   └── 接线图*.png            # 实图标注接线图
├── exp3_fifo_macro.qpf/.qsf/.sdc  # Quartus 工程文件（克隆后可直接打开编译）
└── demo/
    └── 现象演示.mp4           # 上板实测视频：半满触发、字符轮显、双周期切换
```

## 接线（USB 转 TTL，共地）

| 转接器线 | 开发板端 | 说明 |
|---|---|---|
| 绿色 TX | **JP1 第 1 针**（GPIO_D0 / W15） | 右边缘 SD 卡槽下方 2×20 长排针顶端一排左针 |
| 黑色 GND | **JP1 第 2 针**（GPIO_D1 / AK2） | 绿线右边相邻针——工程已把该脚配置为常低输出充当虚拟地（JP1 无 GND 针） |

> 本板 50MHz 时钟在 **PIN_AF14**（指导书写的 PIN_V11 不适用于 DE10-Standard）。

## 使用

1. `Tools → Programmer`（或命令行 `quartus_pgm`）将 `output_files/exp3_fifo_macro.sof` 烧录到 JTAG 链中的 **5CSXFC6**（FPGA，非 HPS）
2. 按 KEY0 复位 → LEDR4 亮（PLL 锁定）
3. 串口助手（或 `scripts/串口助手.py`）选转接器 COM 口、115200-8-N-1，发送 **16 个字符**
4. 观察：HEX1/HEX2 字数递增 → LEDR0/LEDR1 亮（半满）→ HEX0 逐一轮显 → 拨 SW0 变速

## 编译与仿真

- Quartus II 13.1 打开 `exp3_fifo_macro.qpf` 直接全编译，或运行 `scripts/编译.bat`
- ⚠️ 源码为 UTF-8+BOM（Quartus 编辑器正确显示中文注释）；Quartus II 13.1 综合器不接受 BOM，
  因此**请用 `scripts/编译.bat` 编译**（自动临时去 BOM、编译后恢复）或手动去除 BOM 后编译
- 仿真：`scripts/仿真.bat`，结果见 `sim/sim.log`（自校验 PASS）

## 实测记录

| 测试项 | 结果 |
|---|---|
| ModelSim 自校验（半满触发/顺序读出/双周期） | ✅ PASS |
| Quartus 全编译 | ✅ 0 错误，时序正裕量 |
| 上板 T1~T8（半满/顺序/满丢弃/复位/双周期） | ✅ 见 `docs/测试数据表.md` 与演示视频 |
