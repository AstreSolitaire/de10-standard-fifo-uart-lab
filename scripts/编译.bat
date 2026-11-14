@echo off
rem 实验三 一键编译：自动去 BOM 编译、完成后恢复 BOM
rem （Quartus II 13.1 综合器不接受 UTF-8 BOM，而编辑器需要 BOM 显示中文，故由本脚本托管编译）
cd /d %~dp0
D:\python.exe bom.py strip
set TEMP=%~dp0temp
set TMP=%~dp0temp
D:\altera\13.1\quartus\bin64\quartus_sh.exe --flow compile exp3_fifo_macro > compile.log 2>&1
set RC=%ERRORLEVEL%
D:\python.exe bom.py add
echo.
if %RC%==0 (
  echo ===== 编译成功，BOM 已恢复 =====
  echo 产物：output_files\exp3_fifo_macro.sof
) else (
  echo ===== 编译失败，详见 compile.log =====
)
pause
exit /b %RC%
