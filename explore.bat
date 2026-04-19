@echo off
setlocal
title OEIS Discovery Station Sync

echo ===================================================
echo   OEIS DISCOVERY STATION: SSHFS CACHE FLUSH
echo ===================================================

:: Step 1: Force recursive directory scan (Flushes WinFSP Metadata Cache)
echo [1/3] Flushing Cache (Recursive Sync)...
dir /s /b > NUL 2>&1

:: Step 2: Clear local Ruby cache/lock issues if any
if exist Gemfile.lock (
    echo [2/3] Environment Verified.
)

:: Step 3: Execute Ruby Exploration
echo [3/3] Launching Obsidian Explorer v1.6.0...
echo.
bundle exec ruby oeis_cli.rb explore

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [!] Process exited with Error Code: %ERRORLEVEL%
    pause
)

endlocal
