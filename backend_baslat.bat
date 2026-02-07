@echo off
title OSGB Backend (Port 8002)
echo ========================================
echo   OSGB Backend Baslatiliyor...
echo   Port: 8002
echo   Durdurmak icin: Ctrl+C
echo ========================================
echo.
cd /d D:\Rifki\osgb\backend
python -m uvicorn app.main:app --host 0.0.0.0 --port 8002 --reload
pause
