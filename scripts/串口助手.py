# -*- coding: utf-8 -*-
# 串口调试助手（实验三专用）：pyserial + tkinter
# 用法：插入 USB 转 TTL 线 → 端口下拉框选择（或手动输入 COM 号，如 COM8）
#       → 波特率 115200 → 打开串口 → 发送 16 个字符（一键"发送测试串"）
import serial
import serial.tools.list_ports
import threading
import time
import tkinter as tk
from tkinter import ttk, messagebox

APP_TITLE = '串口调试助手 - 实验三（宏功能模块 FIFO）'

class App:
    def __init__(self, root):
        self.root = root
        root.title(APP_TITLE)
        root.geometry('880x580')
        self.ser = None
        self.rx_thread = None
        self.rx_running = False
        self._build_ui()
        self._auto_refresh()

    # ---------- UI ----------
    def _build_ui(self):
        top = ttk.Frame(self.root); top.pack(fill='x', padx=8, pady=6)

        ttk.Label(top, text='端口:').grid(row=0, column=0)
        self.port_var = tk.StringVar(value='')
        # 可编辑下拉框：枚举不到时也能手动输入 COM8
        self.port_cb = ttk.Combobox(top, textvariable=self.port_var, width=10)
        self.port_cb.grid(row=0, column=1, padx=4)
        ttk.Button(top, text='刷新', command=self.refresh_ports, width=6).grid(row=0, column=2)
        ttk.Label(top, text='波特率:').grid(row=0, column=3)
        self.baud_var = tk.StringVar(value='115200')
        ttk.Combobox(top, textvariable=self.baud_var, width=9, state='readonly',
                     values=['9600', '19200', '38400', '57600', '115200']).grid(row=0, column=4, padx=4)
        ttk.Label(top, text='校验:').grid(row=0, column=5)
        self.par_var = tk.StringVar(value='N')
        ttk.Combobox(top, textvariable=self.par_var, width=4, state='readonly',
                     values=['N', 'E', 'O']).grid(row=0, column=6, padx=4)
        self.open_btn = ttk.Button(top, text='打开串口', command=self.toggle_port, width=12)
        self.open_btn.grid(row=0, column=7, padx=10)

        self.status_var = tk.StringVar(value='串口未打开')
        self.status_lbl = ttk.Label(top, textvariable=self.status_var, foreground='#c00')
        self.status_lbl.grid(row=1, column=0, columnspan=8, sticky='w', pady=(4, 0))

        mid = ttk.LabelFrame(self.root, text='发送（电脑 → FPGA）'); mid.pack(fill='x', padx=8, pady=4)
        self.tx_var = tk.StringVar(value='0123456789ABCDEF')
        ttk.Entry(mid, textvariable=self.tx_var, width=58).grid(row=0, column=0, padx=6, pady=6, sticky='w')
        ttk.Button(mid, text='发送', command=self.send_text, width=10).grid(row=0, column=1, padx=4)
        ttk.Button(mid, text='发送测试串(16字符)', command=self.send_test, width=18).grid(row=0, column=2, padx=4)
        self.hex_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(mid, text='HEX 发送', variable=self.hex_var).grid(row=0, column=3, padx=4)
        ttk.Label(mid, text='发送 16 个字符后 FIFO 半满触发显示（HEX1/HEX2 字数递增 → LEDR0/LEDR1 亮 → HEX0 轮显）'
                  ).grid(row=1, column=0, columnspan=4, padx=6, pady=(0, 6), sticky='w')

        rx_frame = ttk.LabelFrame(self.root, text='记录（本实验 FPGA 不发送，RX 区通常为空；TX 操作会记录在此）')
        rx_frame.pack(fill='both', expand=True, padx=8, pady=4)
        self.rx_text = tk.Text(rx_frame, height=16, font=('Consolas', 10))
        self.rx_text.pack(side='left', fill='both', expand=True, padx=(6, 0), pady=6)
        sb = ttk.Scrollbar(rx_frame, command=self.rx_text.yview)
        sb.pack(side='left', fill='y', pady=6)
        self.rx_text['yscrollcommand'] = sb.set
        rx_opt = ttk.Frame(rx_frame); rx_opt.pack(side='left', fill='y', padx=6)
        self.rxhex_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(rx_opt, text='HEX 显示', variable=self.rxhex_var).pack(anchor='n', pady=6)
        ttk.Button(rx_opt, text='清空记录', command=lambda: self.rx_text.delete('1.0', 'end')).pack(anchor='n')

        self.root.protocol('WM_DELETE_WINDOW', self.on_close)

    def set_status(self, s, ok=False):
        self.status_var.set(s)
        self.status_lbl.config(foreground='#080' if ok else '#c00')

    # ---------- 串口枚举 ----------
    def _list_ports(self):
        """枚举 COM 口：优先 pyserial，失败/为空时退回注册表，两处合并。"""
        devs = []
        try:
            devs = [p.device for p in serial.tools.list_ports.comports()]
        except Exception as e:
            self.log(f'枚举异常(pyserial): {e!r}')
        if not devs:
            try:
                import winreg
                k = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r'HARDWARE\DEVICEMAP\SERIALCOMM')
                i = 0
                while True:
                    try:
                        _, val, _ = winreg.EnumValue(k, i)
                        devs.append(val); i += 1
                    except OSError:
                        break
            except OSError:
                pass
        return sorted(set(devs), key=lambda s: int(s[3:]) if s[3:].isdigit() else 999)

    def refresh_ports(self):
        devs = self._list_ports()
        self.port_cb['values'] = devs
        if devs:
            cur = self.port_var.get()
            if cur not in devs:
                self.port_var.set('COM8' if 'COM8' in devs else devs[0])
            self.set_status(f'检测到 {len(devs)} 个串口：{"、".join(devs)}', ok=True)
        else:
            self.set_status('未检测到任何串口设备！请插入 USB 转 TTL 线（或检查 PL23XX 驱动/设备管理器），'
                            '也可手动输入 COM 号', ok=False)

    def _auto_refresh(self):
        """每 2 秒自动刷新端口列表（插拔转接线后无需手动刷新）。"""
        try:
            self.refresh_ports()
        except Exception:
            pass
        self.root.after(2000, self._auto_refresh)

    # ---------- 日志 ----------
    def log(self, s):
        t = time.strftime('%H:%M:%S')
        self.rx_text.insert('end', f'[{t}] {s}\n')
        self.rx_text.see('end')

    # ---------- 开关串口 ----------
    def toggle_port(self):
        if self.ser:
            self.rx_running = False
            try:
                self.ser.close()
            except Exception:
                pass
            self.ser = None
            self.open_btn['text'] = '打开串口'
            self.set_status('串口未打开')
            return
        port = self.port_var.get().strip()
        if not port:
            messagebox.showwarning('提示', '没有串口可选：请插入 USB 转 TTL 线后点"刷新"，'
                                   '或手动输入 COM 号（如 COM8）')
            return
        try:
            parity = {'N': serial.PARITY_NONE, 'E': serial.PARITY_EVEN, 'O': serial.PARITY_ODD}[self.par_var.get()]
            self.ser = serial.Serial(port, int(self.baud_var.get()),
                                     bytesize=8, parity=parity, stopbits=1, timeout=0.1)
        except serial.SerialException as e:
            msg = str(e)
            if 'FileNotFound' in msg or 'FileNotFoundError' in repr(e):
                messagebox.showerror('打开串口失败',
                                     f'{port} 不存在。请确认 USB 转 TTL 线已插入、驱动已装'
                                     f'（PL23XX），并在设备管理器确认实际 COM 号。')
            elif 'PermissionError' in msg or 'Access is denied' in msg:
                messagebox.showerror('打开串口失败',
                                     f'{port} 被占用。请关闭其他占用该串口的软件后重试。')
            else:
                messagebox.showerror('打开串口失败', f'{port}: {e}')
            return
        except Exception as e:
            messagebox.showerror('打开串口失败', f'{port}: {e!r}')
            return
        self.open_btn['text'] = '关闭串口'
        self.set_status(f'已打开 {self.ser.port} @ {self.ser.baudrate} 8{self.par_var.get()}1', ok=True)
        self.rx_running = True
        self.rx_thread = threading.Thread(target=self.rx_loop, daemon=True)
        self.rx_thread.start()

    def rx_loop(self):
        while self.rx_running and self.ser:
            try:
                data = self.ser.read(256)
            except Exception:
                break
            if data:
                if self.rxhex_var.get():
                    s = ' '.join(f'{b:02X}' for b in data)
                else:
                    s = data.decode('ascii', errors='replace').replace('\r', '').replace('\n', '\\n')
                self.log('RX: ' + s)

    # ---------- 发送 ----------
    def send_bytes(self, payload, desc):
        if not self.ser:
            messagebox.showwarning('提示', '请先打开串口')
            return
        try:
            self.ser.write(payload)
            self.log(f'TX({len(payload)}字节): {desc}')
        except Exception as e:
            messagebox.showerror('发送失败', str(e))

    def send_text(self):
        t = self.tx_var.get()
        if self.hex_var.get():
            try:
                payload = bytes.fromhex(t.replace(' ', ''))
            except ValueError:
                messagebox.showerror('错误', 'HEX 格式不正确（应为偶数位 0-9 A-F）')
                return
            desc = ' '.join(f'{b:02X}' for b in payload)
        else:
            payload = t.encode('ascii', errors='replace')
            desc = t
        self.send_bytes(payload, desc)

    def send_test(self):
        s = '0123456789ABCDEF'
        self.tx_var.set(s)
        self.send_bytes(s.encode('ascii'), s)

    def on_close(self):
        self.rx_running = False
        if self.ser:
            try:
                self.ser.close()
            except Exception:
                pass
        self.root.destroy()

if __name__ == '__main__':
    try:
        root = tk.Tk()
        App(root)
        root.mainloop()
    except Exception:
        import traceback
        with open(r'D:\exp3_fifo_macro\串口助手_err.log', 'a', encoding='utf-8') as f:
            f.write(time.strftime('%Y-%m-%d %H:%M:%S ') + traceback.format_exc() + '\n----\n')
        raise
