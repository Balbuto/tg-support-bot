#!/bin/bash
set -e

# Определяем команду compose
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

echo "🔄 Перезапуск Telegram Support Bot..."
$COMPOSE_CMD restart
$COMPOSE_CMD logs -f --tail=50
