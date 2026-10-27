@echo off
title Vela - Daten zuruecksetzen / reset data
echo.
echo ============================================
echo   VELA - alle Daten loeschen / delete all data
echo   (Playlists, Einstellungen, Cache, Downloads)
echo ============================================
echo.
set /p ok="Wirklich alles loeschen? (J/N) / Delete everything? (Y/N): "
if /I "%ok%"=="J" goto :doit
if /I "%ok%"=="Y" goto :doit
echo Abgebrochen. / Cancelled.
pause
exit /b

:doit
echo.
echo Schliesse Vela ...
taskkill /IM velaplayer.exe /F >nul 2>&1
echo Loesche Daten ...
rmdir /s /q "%APPDATA%\com.vela" >nul 2>&1
rmdir /s /q "%LOCALAPPDATA%\com.vela" >nul 2>&1
del /q "%TEMP%\vela_m3u_*.cache" >nul 2>&1
del /q "%LOCALAPPDATA%\Temp\vela_m3u_*.cache" >nul 2>&1
rmdir /s /q "D:\VelaDownloads" >nul 2>&1
echo.
echo Fertig - Vela ist auf Nullzustand. / Done - Vela reset.
echo Beim naechsten Start kommt die Sprachauswahl.
echo.
pause
