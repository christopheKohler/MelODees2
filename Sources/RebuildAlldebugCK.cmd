@echo off
del MelODees.adf

REM cd Intro
REM call BuildAndRunDemo.bat -b
REM cd..

cd MusicDisk
call BuildAndRunDemo.bat -b
cd..

REM cd 03_fadetest
REM call BuildAndRunDemo.bat -b
REM cd..

..\LDOS\install script.txt MelODees.adf

"..\..\ToolsForFramework\winuae\winuae_ckdebug.exe" -config="configs\a500.uae" -s floppy0="%~dp0%MelODees.adf"

pause
