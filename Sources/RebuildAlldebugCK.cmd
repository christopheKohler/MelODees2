@echo off
del MelODees.adf

cd Intro
call BuildAndRunDemo.bat -b
cd..

cd Loader
call BuildAndRunDemo.bat -b
cd..

cd MusicDisk
call BuildAndRunDemo.bat -b
cd..


..\LDOS\install script.txt MelODees.adf

"..\..\ToolsForFramework\winuae\winuae_ckdebug.exe" -config="configs\a500.uae" -s floppy0="%~dp0%MelODees.adf"

pause
