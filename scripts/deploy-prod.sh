#!/bin/bash
set -e

echo "🚀 Запуск развертывания в production..."

# Проверка Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker не установлен"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose не установлен"
    exit 1
fi

# Проверка переменных окружения
if [ ! -f .env.production ]; then
    echo "❌ Файл .env.production не найден"
    echo "📋 Создайте его из примера: cp .env.example .env.production"
    echo "📝 Отредактируйте перед запуском"
    exit 1
fi

# Проверка обязательных переменных
source .env.production

if [ -z "$BOT_TOKEN" ]; then
    echo "❌ BOT_TOKEN не установлен в .env.production"
    exit 1
fi

if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "⚠️  POSTGRES_PASSWORD не установлен, используется значение по умолчанию"
fi

# Создание директорий
echo "📁 Создание структуры директорий..."
mkdir -p {data,logs,backups}/prod
mkdir -p docker/postgres

# Копирование init.sql если его нет
if [ ! -f docker/postgres/init.sql ]; then
    echo "📄 Создание init.sql..."
    cp docker/postgres/init.sql docker/postgres/init.sql 2>/dev/null || \
    curl -sSL https://raw.githubusercontent.com/balbuto/telegram-support-bot/main/docker/postgres/init.sql -o docker/postgres/init.sql
fi

# Остановка существующих контейнеров
echo "🛑 Остановка существующих контейнеров..."
docker-compose -f docker-compose.prod.yml down || true

# Удаление старых образов
echo "🧹 Очистка Docker..."
docker system prune -f --volumes

# Запуск контейнеров
echo "🐳 Запуск контейнеров..."
docker-compose -f docker-compose.prod.yml up -d

echo "⏳ Ожидание запуска PostgreSQL..."
sleep 10

# Проверка статуса
echo "🔍 Проверка статуса контейнеров..."
docker-compose -f docker-compose.prod.yml ps

echo "📊 Проверка здоровья PostgreSQL..."
for i in {1..10}; do
    if docker-compose -f docker-compose.prod.yml exec -T postgres pg_isready -U postgres > /dev/null 2>&1; then
        echo "✅ PostgreSQL готов"
        break
    fi
    echo "⏳ Ожидание PostgreSQL... ($i/10)"
    sleep 5
done

echo "📊 Проверка здоровья бота..."
for i in {1..10}; do
    if docker-compose -f docker-compose.prod.yml exec -T bot python -c "
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
        echo "✅ Бот готов"
        break
    fi
    echo "⏳ Ожидание бота... ($i/10)"
    sleep 5
done

echo "📋 Итоговый статус:"
echo "========================================="
docker-compose -f docker-compose.prod.yml ps
echo "========================================="

echo ""
echo "📊 Просмотр логов PostgreSQL:"
echo "  docker-compose -f docker-compose.prod.yml logs postgres --tail=20"

echo ""
echo "🤖 Просмотр логов бота:"
echo "  docker-compose -f docker-compose.prod.yml logs bot --tail=20"

echo ""
echo "✅ Развертывание завершено!"
echo "📞 Бот должен быть доступен в Telegram"
