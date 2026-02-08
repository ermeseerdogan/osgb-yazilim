@echo off
title OSGB Backend (Port 8001)
echo ========================================
echo   OSGB Backend Baslatiliyor...
echo   Port: 8001
echo   Durdurmak icin: Ctrl+C
echo ========================================
echo.
cd /d D:\Rifki\osgb\backend
venv\Scripts\python.exe run_server.py
pause
