REM A batch file to to optimize uae cpu core.

REM cd Release
REM copy cpuemu.asm cpuemu0.asm
REM ..\vc5opti\Release\vc5opti.exe cpuemu.asm
REM ml /c /coff cpuemu.asm
REM cd ..

REM cd Release
REM ml /c /coff cpuemuop.asm
REM copy cpuemuop.obj cpuemu.obj
REM cd ..

cd BasiliskII___Win32_Win9x
copy cpuemu.asm cpuemu0.asm
..\vc5opti\Release\vc5opti.exe cpuemu.asm
..\masm\ml /c /coff cpuemu.asm
cd ..
