@echo off
title OSGB Frontend (Port 3003)
echo ========================================
echo   OSGB Frontend Baslatiliyor...
echo   Port: 3003
echo   Durdurmak icin: Ctrl+C
echo ========================================
echo.
cd /d D:\Rifki\osgb\frontend
D:\dev-tools\flutter\bin\flutter run -d chrome --web-port=3003
pause
