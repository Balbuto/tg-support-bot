#!/bin/bash
# Скрипт диагностики PostgreSQL

echo "🔍 Диагностика PostgreSQL..."

# Проверка Docker
if ! docker ps > /dev/null 2>&1; then
    echo "❌ Docker не запущен или нет прав"
    exit 1
fi

# Проверка контейнера PostgreSQL
if ! docker ps | grep -q "postgres"; then
    echo "⚠️  Контейнер PostgreSQL не запущен"
    
    # Попытка запуска
    echo "🔄 Попытка запуска PostgreSQL..."
    docker compose -f docker-compose.yml up -d postgres
    
    sleep 5
    
    if ! docker ps | grep -q "postgres"; then
        echo "❌ Не удалось запустить PostgreSQL"
        
        # Просмотр логов
        echo "📋 Логи последней попытки:"
        docker compose -f docker-compose.yml logs postgres --tail=20
        
        # Проверка конфигурации
        echo "📄 Проверка конфигурации:"
        echo "  POSTGRES_PASSWORD установлен: $(grep -c "POSTGRES_PASSWORD" .env)"
        echo "  Объем данных: $(docker volume ls | grep -c postgres_data)"
        
        exit 1
    fi
fi

echo "✅ Контейнер PostgreSQL запущен"

# Проверка здоровья
echo "🩺 Проверка здоровья PostgreSQL..."
for i in {1..30}; do
    if docker compose -f docker-compose.yml exec -T postgres pg_isready -U postgres > /dev/null 2>&1; then
        echo "✅ PostgreSQL готов к подключениям"
        break
    fi
    
    if [ $i -eq 30 ]; then
        echo "❌ PostgreSQL не готов после 30 попыток"
        
        # Просмотр логов
        echo "📋 Логи PostgreSQL:"
        docker compose -f docker-compose.yml logs postgres --tail=30
        
        # Проверка порта
        echo "🔌 Проверка порта 5432:"
        docker port support_bot_postgres
        
        # Проверка использования диска
        echo "💾 Использование диска:"
        docker exec support_bot_postgres df -h /var/lib/postgresql/data
        
        exit 1
    fi
    
    echo "⏳ Ожидание... ($i/30)"
    sleep 2
done

# Проверка подключения от бота
echo "🔗 Проверка подключения от бота..."
docker compose -f docker-compose.yml exec -T bot python -c "
import sys
try:
    import asyncio
    from database import db_manager
    import os
    
    print(f'Проверка подключения:')
    print(f'  Хост: {os.getenv(\"POSTGRES_HOST\", \"NOT SET\")}')
    print(f'  Порт: {os.getenv(\"POSTGRES_PORT\", \"NOT SET\")}')
    print(f'  БД: {os.getenv(\"POSTGRES_DB\", \"NOT SET\")}')
    print(f'  Пользователь: {os.getenv(\"POSTGRES_USER\", \"NOT SET\")}')
    print(f'  Пароль: {'SET' if os.getenv(\"POSTGRES_PASSWORD\") else 'NOT SET'}')
    
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    loop.run_until_complete(db_manager.connect())
    print('✅ Подключение успешно')
    sys.exit(0)
except Exception as e:
    print(f'❌ Ошибка подключения: {e}')
    sys.exit(1)
"

if [ $? -eq 0 ]; then
    echo "🎉 Все проверки пройдены успешно!"
else
    echo "⚠️  Есть проблемы с подключением"
    
    # Дополнительная диагностика
    echo "📊 Дополнительная диагностика:"
    
    # Проверка сети
    echo "🌐 Проверка сети между контейнерами:"
    docker compose -f docker-compose.yml exec postgres ping -c 2 bot
    
    # Проверка таблиц
    echo "📋 Проверка таблиц в базе данных:"
    docker compose -f docker-compose.yml exec postgres psql -U postgres -d support_bot -c "\dt" || \
    echo "  ❌ Не удалось подключиться к базе данных"
fi
