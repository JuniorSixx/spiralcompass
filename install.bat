@echo off
rem Installs Spiral Compass into the game's UE4SS Mods folder.
rem Instala o Spiral Compass na pasta Mods do UE4SS do jogo.
rem Usage / Uso:  install.bat ["C:\...\steamapps\common\JIM"]
setlocal
set "GAME=%~1"
if "%GAME%"=="" (
  for %%D in (
    "%ProgramFiles(x86)%\Steam\steamapps\common\JIM"
    "C:\SteamLibrary\steamapps\common\JIM"
    "D:\SteamLibrary\steamapps\common\JIM"
    "E:\SteamLibrary\steamapps\common\JIM"
    "F:\SteamLibrary\steamapps\common\JIM"
    "G:\SteamLibrary\steamapps\common\JIM"
  ) do if exist "%%~D\JIM\Binaries\Win64\JIM-Win64-Shipping.exe" set "GAME=%%~D"
)
if "%GAME%"=="" set /p "GAME=Game folder / Pasta do jogo (...\steamapps\common\JIM): "
set "BIN=%GAME%\JIM\Binaries\Win64"

if not exist "%BIN%\JIM-Win64-Shipping.exe" (
  echo [ERRO] Game not found / Jogo nao encontrado em: "%GAME%"
  exit /b 1
)
if not exist "%BIN%\ue4ss\UE4SS.dll" (
  echo [ERRO] UE4SS is not installed / UE4SS nao esta instalado em "%BIN%".
  echo        See README / Veja o README: https://github.com/UE4SS-RE/RE-UE4SS/releases/tag/experimental-latest
  exit /b 1
)

if not exist "%~dp0SpiralCompass.exe" (
  call "%~dp0build.bat" || exit /b 1
)

set "DEST=%BIN%\ue4ss\Mods\SpiralCompass"
xcopy /E /I /Y /Q "%~dp0mod\SpiralCompass" "%DEST%" >nul
copy /Y "%~dp0SpiralCompass.exe" "%DEST%\" >nul

echo.
echo [OK] Installed / Instalado em: "%DEST%"
echo      1. Start the game and load your save / Abra o jogo e carregue o save
echo      2. Run / Execute: "%DEST%\SpiralCompass.exe"
