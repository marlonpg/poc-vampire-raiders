#!/bin/bash

# Quick start script for Vampire Raiders Docker setup
# Run this from the project root directory

echo ""
echo "==================================="
echo "  Vampire Raiders - Docker Launcher"
echo "==================================="
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed"
    echo "Please install Docker Desktop: https://www.docker.com/products/docker-desktop"
    exit 1
fi

# Check if Docker daemon is running
if ! docker ps &> /dev/null; then
    echo "ERROR: Docker daemon is not running"
    echo "Please start Docker Desktop"
    exit 1
fi

echo "[1/3] Building Docker images..."
docker-compose up --build -d

echo ""
echo "[2/3] Waiting for services to start..."
sleep 5

echo ""
echo "[3/3] Checking service status..."
docker-compose ps

echo ""
echo "==================================="
echo ""
echo "Server Status:"

if docker-compose logs java-backend | grep -q "Game loop started"; then
    echo "✓ Backend is running on localhost:7777"
else
    echo "⏳ Backend is starting... (this may take 1-2 minutes)"
    echo "   Check progress with: docker-compose logs -f java-backend"
fi

if docker-compose logs mysql | grep -q "ready for connections"; then
    echo "✓ Database is running on localhost:3306"
else
    echo "⏳ Database is starting..."
fi

echo ""
echo "==================================="
echo "Next steps:"
echo ""
echo "1. Open Godot and connect to localhost:7777"
echo "2. View logs: docker-compose logs -f java-backend"
echo "3. Stop services: docker-compose down"
echo ""
echo "==================================="
echo ""
