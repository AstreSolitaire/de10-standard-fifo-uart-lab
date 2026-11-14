@echo off
rem 实验三 一键仿真：ModelSim 自校验（自动去 BOM、仿真后恢复）
cd /d %~dp0sim
D:\python.exe ..\bom.py strip
set TEMP=%~dp0..\temp
set TMP=%~dp0..\temp
if exist sim_work rmdir /s /q sim_work
D:\altera\13.1\modelsim_ase\win32aloem\vsim.exe -c -do simulate.do > sim.log 2>&1
set RC=%ERRORLEVEL%
D:\python.exe ..\bom.py add
findstr /C:"PASS" sim.log >nul
if %RC%==0 (echo. & echo ===== 仿真完成，结果见 sim\sim.log =====) else (echo. & echo ===== 仿真异常，详见 sim\sim.log =====)
pause
exit /b %RC%
