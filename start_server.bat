@echo off
title JustLayMe Local Server
echo Starting JustLayMe Local Web Server...
echo ================================
echo.
echo Server will be available at:
echo http://localhost:8000
echo.
echo Press Ctrl+C to stop the server
echo ================================
echo.
cd /d C:\JustLayMe
python -m http.server 8000
pause