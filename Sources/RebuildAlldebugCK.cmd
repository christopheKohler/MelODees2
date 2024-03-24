@echo off
del MelODees2.adf

cd Intro
call BuildAndRunDemo.bat -b
cd..

cd Loader
call BuildAndRunDemo.bat -b
cd..

cd MusicDisk
call BuildAndRunDemo.bat -b
cd..


..\LDOS\install script.txt MelODees2.adf

"..\..\ToolsForFramework\winuae\winuae_ckdebug.exe" -config="configs\a500.uae" -s floppy0="%~dp0%MelODees2.adf"

pause
