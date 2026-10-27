@echo off
title Dienstplan JKEB veroeffentlichen
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0veroeffentlichen.ps1"
if errorlevel 1 (
  echo.
  echo *** FEHLER - es wurde nichts oder nicht alles hochgeladen. Meldung oben lesen. ***
) else (
  echo.
  echo Fertig.
)
echo.
pause
