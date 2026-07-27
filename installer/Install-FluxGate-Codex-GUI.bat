@echo off
rem FluxGateAI Codex installer - GUI edition launcher
cd /d "%~dp0"
start "" powershell -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0FluxGate-Codex-Setup-GUI.ps1"
