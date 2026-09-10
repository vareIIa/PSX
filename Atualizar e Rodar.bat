@echo off
setlocal
cd /d "%~dp0"

set "GODOT=.tools\Godot_v4.7.2-stable_win64_console.exe"
set "EXE=export\NevoaEDither.exe"

echo == Fechando instancia anterior do jogo (se houver) ==
taskkill /IM NevoaEDither.exe /F >nul 2>&1

echo == Aguardando o executavel liberar ==
if not exist export mkdir export
if exist "%EXE%" (
  for /l %%i in (1,1,30) do (
    del /f /q "%EXE%" >nul 2>&1
    if not exist "%EXE%" goto liberado
    ping -n 2 127.0.0.1 >nul
  )
  echo !! Nao consegui remover "%EXE%" - feche o jogo manualmente e tente de novo.
  pause
  exit /b 1
)
:liberado

echo == Reimportando assets ==
"%GODOT%" --headless --path game --import

echo == Exportando build mais recente ==
"%GODOT%" --headless --path game --export-release "Windows Desktop"

if not exist "%EXE%" (
  echo.
  echo !! Export falhou: "%EXE%" nao foi gerado. Veja os erros acima.
  pause
  exit /b 1
)

echo == Iniciando o jogo ==
start "" "%EXE%"

endlocal
