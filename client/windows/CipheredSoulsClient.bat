@echo off
setlocal
title Ciphered Souls Client
cd /d "%~dp0\..\.."
echo Starting Ciphered Souls local server...
start "Ciphered Souls Server" cmd /k "npm run dev"
timeout /t 2 /nobreak >nul
echo Opening Ciphered Souls client...
start "" "http://localhost:8787?v=desktop"
echo.
echo Ciphered Souls is opening in your browser.
echo Keep the server window open while playing.
pause
