@echo off
setlocal

cd /d "%~dp0"

set FPCRES=C:\lazarus\fpc\3.2.2\bin\i386-win32\fpcres.exe
set FPC=C:\lazarus\fpc\3.2.2\bin\i386-win32\fpc.exe

echo [1/2] Building resources...
"%FPCRES%" -of res -o MemClip.res MemClip.rc
if errorlevel 1 (
  echo Resource build failed.
  pause
  exit /b 1
)

echo [2/2] Compiling executable...
"%FPC%" -O2 MemClip.pas
if errorlevel 1 (
  echo Compile failed.
  pause
  exit /b 1
)

echo Build completed: MemClip.exe
endlocal
