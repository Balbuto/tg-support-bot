#!/bin/bash
set -e

# Определяем команду compose
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

echo "📊 Статус контейнеров Telegram Support Bot..."
echo "========================================="
$COMPOSE_CMD ps
echo "========================================="

echo ""
echo "📈 Использование ресурсов:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" | head -5

echo ""
echo "📋 Логи PostgreSQL (последние 5 строк):"
$COMPOSE_CMD logs postgres --tail=5 2>/dev/null | grep -v "^$" || echo "  Логи недоступны"

echo ""
echo "🤖 Логи бота (последние 5 строк):"
$COMPOSE_CMD logs bot --tail=5 2>/dev/null | grep -v "^$" || echo "  Логи недоступны"
