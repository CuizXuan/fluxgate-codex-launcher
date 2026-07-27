@echo off
chcp 65001 >nul
cd /d "%~dp0"
title FluxGateAI Bridge
where node >nul 2>nul
if errorlevel 1 (
  echo [错误] 未检测到 Node.js。请先安装 Node.js 18+：https://nodejs.org
  pause
  exit /b 1
)
if not exist "node_modules\ws" (
  echo 首次运行，正在安装依赖 ws ...
  call npm install --no-audit --no-fund
  if errorlevel 1 (
    echo [错误] 依赖安装失败，尝试用镜像重试...
    call npm install --no-audit --no-fund --registry=https://registry.npmmirror.com
  )
)
node fluxgate-bridge.mjs
echo.
echo Bridge 已退出。
pause
