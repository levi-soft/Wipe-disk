@echo off
:: PANIC WIPE - Raw disk write zeros - No confirmation

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0PanicWipe.ps1"
