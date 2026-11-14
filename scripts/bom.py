# -*- coding: utf-8 -*-
"""BOM 管理：编译/仿真前去掉源文件 BOM（Quartus II 13.1 综合器不认 BOM），
编辑后恢复 BOM（Quartus II 13.1 编辑器需要 BOM 才能正确显示中文）。
用法：python bom.py strip   # 去 BOM（编译/仿真前调用）
      python bom.py add     # 加 BOM（编译/仿真后调用）
"""
import glob
import os
import sys

BASE = r'D:\exp3_fifo_macro'
TARGETS = (glob.glob(os.path.join(BASE, 'rtl', '*.v')) +
           glob.glob(os.path.join(BASE, 'sim', '*.sv')))
BOM = b'\xef\xbb\xbf'


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else 'strip'
    for p in TARGETS:
        raw = open(p, 'rb').read()
        had = raw.startswith(BOM)
        if mode == 'strip' and had:
            open(p, 'wb').write(raw[3:])
            print('strip:', os.path.basename(p))
        elif mode == 'add' and not had:
            open(p, 'wb').write(BOM + raw)
            print('add  :', os.path.basename(p))
    print('done:', mode)


if __name__ == '__main__':
    main()
