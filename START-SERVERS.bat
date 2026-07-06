@echo off
title Wedding App - Server Starter
color 0A

echo ========================================
echo   WEDDING APP SERVER STARTER
echo ========================================
echo.

echo [1/4] Docker Desktop check kar raha hai...
docker info >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo  [WARNING] Docker Desktop band hai!
    echo  PostgreSQL ke liye Docker Desktop start karein.
    echo  Phir bhi API seeded codes se kaam karega...
    echo.
) else (
    echo  [OK] Docker chal raha hai.
    echo [2/4] PostgreSQL database start kar raha hai...
    docker compose up -d
    timeout /t 3 /nobreak >nul
    echo  [OK] Database ready.
)

echo.
echo [3/4] API server start ho raha hai (port 4000)...
start "Wedding API (port 4000)" cmd /k "cd /d d:\new curent projecs\az projects\weddingapp\apps\api && node dist/main.js"

timeout /t 3 /nobreak >nul

echo [4/4] Web server start ho raha hai (port 3000)...
start "Wedding Web (port 3000)" cmd /k "cd /d d:\new curent projecs\az projects\weddingapp\apps\web && npm run dev"

echo.
echo ========================================
echo   SERVERS START HO RAHE HAIN!
echo ========================================
echo.
echo   Website:    http://localhost:3000
echo   Admin:      http://localhost:3000/admin
echo   API:        http://localhost:4000/api
echo.
echo   ADMIN LOGIN CODES:
echo   ==================
echo   9001  = Organiser (Admin access)
echo   1001  = Aija (Super Admin)
echo   1002  = Abhi (Super Admin)
echo   1234  = Guest (Admin nahi)
echo.
echo Dono windows band mat karein!
echo.
pause
