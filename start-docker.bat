@echo off
REM Quick start script for Vampire Raiders Docker setup
REM Run this from the project root directory

echo.
echo ===================================
echo  Vampire Raiders - Docker Launcher
echo ===================================
echo.

REM Check if Docker is installed
docker --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not installed or not in PATH
    echo Please install Docker Desktop: https://www.docker.com/products/docker-desktop
    pause
    exit /b 1
)

REM Check if Docker daemon is running
docker ps >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker daemon is not running
    echo Please start Docker Desktop
    pause
    exit /b 1
)

echo [1/3] Building Docker images...
docker-compose up --build -d

echo.
echo [2/3] Waiting for services to start...
timeout /t 5 /nobreak

echo.
echo [3/3] Checking service status...
docker-compose ps

echo.
echo ===================================
echo.
echo Server Status:
docker-compose logs java-backend | findstr "Game loop started" >nul
if errorlevel 0 (
    echo ✓ Backend is running on localhost:7777
) else (
    echo ⏳ Backend is starting... (this may take 1-2 minutes)
    echo    Check progress with: docker-compose logs -f java-backend
)

docker-compose logs mysql | findstr "ready for connections" >nul
if errorlevel 0 (
    echo ✓ Database is running on localhost:3306
) else (
    echo ⏳ Database is starting...
)

echo.
echo ===================================
echo Next steps:
echo.
echo 1. Open Godot and connect to localhost:7777
echo 2. View logs: docker-compose logs -f java-backend
echo 3. Stop services: docker-compose down
echo.
echo ===================================
echo.
pause
