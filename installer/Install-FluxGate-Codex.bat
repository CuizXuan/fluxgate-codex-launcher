@echo off
rem FluxGateAI Codex one-click installer launcher
chcp 65001 >nul
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0FluxGate-Codex-Setup.ps1"
echo.
pause
