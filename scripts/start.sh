#!/bin/bash
set -e

# Определяем команду compose
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

echo "🚀 Запуск Telegram Support Bot..."
$COMPOSE_CMD up -d
$COMPOSE_CMD logs -f
