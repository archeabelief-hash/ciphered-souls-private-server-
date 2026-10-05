@echo off
setlocal EnableDelayedExpansion
title Ciphered Souls
cd /d "%~dp0"

REM Remove leftover from a previous self-update
if exist "Play-Elder-Souls.old.bat" del "Play-Elder-Souls.old.bat" >nul 2>&1

REM ==================== AUTO-UPDATER ====================
REM Checks GitHub for a newer version and installs it automatically.
set "GH=https://raw.githubusercontent.com/archeabelief-hash/ciphered-souls-private-server-/main/game"
if not exist "version.txt" echo 1>"version.txt"
set /p LOCALVER=<"version.txt"
where curl >nul 2>nul
if !errorlevel!==0 (
    netstat -an | find "43594" | find "LISTENING" >nul
    if !errorlevel! NEQ 0 (
        curl -s -L -f --max-time 25 "!GH!/version.txt" -o "!TEMP!\cs_version.txt" >nul 2>nul
        if exist "!TEMP!\cs_version.txt" (
            set /p REMOTEVER=<"!TEMP!\cs_version.txt"
            del "!TEMP!\cs_version.txt" >nul 2>nul
            if !REMOTEVER! GTR !LOCALVER! (
                echo.
                echo ==================================================
                echo  Ciphered Souls update v!REMOTEVER! found - installing...
                echo  (Do not close this window.)
                echo ==================================================
                set "UPD_OK=1"
                curl -s -L -f --max-time 60 "!GH!/patches/v!REMOTEVER!/parts.txt" -o "!TEMP!\cs_parts.txt" >nul 2>nul
                if !errorlevel! NEQ 0 set "UPD_OK=0"
                if "!UPD_OK!"=="1" (
                    for /f "usebackq tokens=1,2 delims=|" %%A in ("!TEMP!\cs_parts.txt") do (
                        if "%%B"=="" (set "URL=!GH!/patches/v!REMOTEVER!/%%A") else (set "URL=%%B")
                        curl -s -L -f --max-time 900 "!URL!" -o "!TEMP!\cs_%%A" >nul 2>nul
                        if !errorlevel! NEQ 0 set "UPD_OK=0"
                    )
                )
                if "!UPD_OK!"=="1" (
                    REM Rename this running script so the update can replace it
                    ren "Play-Elder-Souls.bat" "Play-Elder-Souls.old.bat" >nul 2>nul
                    for /f "usebackq tokens=1 delims=|" %%A in ("!TEMP!\cs_parts.txt") do (
                        powershell -NoProfile -Command "Expand-Archive -Force '!TEMP!\cs_%%A' '%~dp0'" >nul 2>nul
                    )
                    del "!TEMP!\cs_*.zip" "!TEMP!\cs_parts.txt" >nul 2>nul
                    echo !REMOTEVER!>"version.txt"
                    echo.
                    echo Update installed. Restarting the game...
                    timeout /t 2 /nobreak >nul
                    start "" "%~dp0Play-Elder-Souls.bat"
                    exit /b
                ) else (
                    echo Update download failed - starting your current version instead.
                    del "!TEMP!\cs_*.zip" "!TEMP!\cs_parts.txt" >nul 2>nul
                )
            )
        )
    ) else (
        echo (Server already running - skipping update check.)
    )
) else (
    echo (curl not found - skipping update check.)
)
REM ================== END AUTO-UPDATER ==================

REM --- 1. Put the game cache where the client expects it (first run only) ---
if not exist "%USERPROFILE%\CIPHERED_SOULS\main_file_cache.dat2" (
    echo First run: installing game cache, one moment...
    mkdir "%USERPROFILE%\CIPHERED_SOULS" 2>nul
    xcopy /Y /Q "cache\main_file_cache.*" "%USERPROFILE%\CIPHERED_SOULS\"
    echo Cache installed.
)

REM --- 2. Start the server if it isn't already running ---
netstat -an | find "43594" | find "LISTENING" >nul
if errorlevel 1 (
    echo Starting game server in the background...
    start "Ciphered Souls Server" /min "server\Start-Server.bat"
) else (
    echo Game server is already running.
)

REM --- 3. Wait until the server is ready ---
echo Waiting for the server to finish loading...
:waitloop
powershell -NoProfile -Command "try { $c=New-Object Net.Sockets.TcpClient; $c.Connect('127.0.0.1',43594); $c.Close(); exit 0 } catch { exit 1 }" >nul 2>&1
if errorlevel 1 (
    timeout /t 5 /nobreak >nul
    goto waitloop
)

REM --- 4. Open the game ---
echo Opening Ciphered Souls...
cd client
..\java8\bin\java -cp "classes;lib\*" Loader
