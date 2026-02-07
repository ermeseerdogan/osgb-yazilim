@echo off
echo ========================================
echo   OSGB Yazilim Baslatiliyor...
echo   Backend: Port 8002
echo   Frontend: Port 3003
echo ========================================
echo.
echo Backend ve Frontend ayri pencerelerde aciliyor...
echo.

start "" "D:\Rifki\osgb\backend_baslat.bat"
timeout /t 3 /nobreak >nul
start "" "D:\Rifki\osgb\frontend_baslat.bat"

echo.
echo Her iki sunucu da baslatildi!
echo Bu pencereyi kapatabilirsiniz.
echo.
pause
