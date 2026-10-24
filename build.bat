@echo off
rem Compiles the Spiral Compass panel using the C# compiler that ships with Windows (.NET Framework 4.x).
rem Compila o painel usando o compilador C# que ja vem com o Windows (.NET Framework 4.x).
setlocal
set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not exist "%CSC%" (
  echo [ERRO] csc.exe nao encontrado. Instale o .NET Framework 4.8.
  exit /b 1
)
"%CSC%" /nologo /codepage:65001 /target:winexe /optimize ^
  /win32icon:"%~dp0panel\icon.ico" ^
  /out:"%~dp0SpiralCompass.exe" ^
  /r:System.Windows.Forms.dll /r:System.Drawing.dll ^
  "%~dp0panel\SpiralCompass.cs"
if errorlevel 1 (
  echo [ERRO] Falha ao compilar.
  exit /b 1
)
echo [OK] SpiralCompass.exe gerado.
