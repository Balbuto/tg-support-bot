#!/bin/bash
echo "🔍 Проверка здоровья Telegram Support Bot..."

# Проверка Docker контейнеров
if docker-compose ps | grep -q "Up"; then
    echo "✅ Контейнеры запущены"
    
    # Проверка бота
    if docker-compose exec -T bot python -c "
import sys
try:
    import asyncio
    from database import db_manager
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    loop.run_until_complete(db_manager.connect())
    sys.exit(0)
except:
    sys.exit(1)
    " > /dev/null 2>&1; then
        echo "✅ Бот здоров"
    else
        echo "❌ Проблемы с ботом"
    fi
    
    # Проверка PostgreSQL
    if docker-compose exec postgres pg_isready -U postgres > /dev/null 2>&1; then
        echo "✅ PostgreSQL здоров"
    else
        echo "❌ Проблемы с PostgreSQL"
    fi
    
else
    echo "❌ Контейнеры не запущены"
fi

# Проверка использования ресурсов
echo ""
echo "💾 Использование ресурсов:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | head -3

echo ""
echo "📋 Последние ошибки:"
docker-compose logs bot --tail=20 | grep -i "error\|exception" || echo "✅ Ошибок не найдено"
