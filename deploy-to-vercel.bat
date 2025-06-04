@echo off
echo ============================================
echo Deploying justlay.me to Vercel
echo ============================================
echo.

cd /d C:\Users\fastl\justlayme

echo Checking if you're logged in to Vercel...
vercel whoami 2>nul
if %errorlevel% neq 0 (
    echo You need to login first!
    echo.
    vercel login
)

echo.
echo Starting deployment...
echo.

REM Deploy to production with the domain
vercel --prod --yes

echo.
echo ============================================
echo Deployment Complete!
echo ============================================
echo.
echo Your website is now live at:
echo https://justlay.me
echo.
echo It works on PC and mobile - no special URLs!
echo.
echo Note: The AI chat needs a backend API to work.
echo See DEPLOY-NOW.txt for API setup options.
echo.
pause