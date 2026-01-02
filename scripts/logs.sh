#!/bin/bash
set -e

# Определяем команду compose
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

SERVICE="${1:-bot}"
TAIL="${2:-100}"

echo "📋 Просмотр логов сервиса: $SERVICE (последние $TAIL строк)..."
$COMPOSE_CMD logs --tail=$TAIL -f $SERVICE
