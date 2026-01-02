#!/bin/bash
set -e

echo "🚀 Запуск развертывания Telegram Support Bot..."

# Проверка Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker не установлен"
    exit 1
fi

# Проверка Docker Compose (версия 2)
if ! docker compose version &> /dev/null; then
    echo "⚠️  Docker Compose V2 не найден, проверяем docker-compose V1..."
    if ! command -v docker-compose &> /dev/null; then
        echo "❌ Docker Compose не установлен"
        echo "📦 Установите Docker Compose:"
        echo "  Для Docker Desktop: уже включен"
        echo "  Для Linux: sudo apt-get install docker-compose-plugin"
        exit 1
    else
        COMPOSE_CMD="docker-compose"
        echo "✅ Используется docker-compose V1"
    fi
else
    COMPOSE_CMD="docker compose"
    echo "✅ Используется docker compose V2"
fi

# Проверка переменных окружения
if [ ! -f .env ]; then
    echo "❌ Файл .env не найден"
    echo "📋 Создайте его из примера: cp .env.example .env"
    echo "📝 Отредактируйте перед запуском"
    exit 1
fi

# Проверка синтаксиса .env файла
echo "🔍 Проверка синтаксиса .env файла..."
if ! source .env 2>/dev/null; then
    echo "❌ Ошибка синтаксиса в .env файле"
    echo "📋 Проверьте следующие моменты:"
    echo "  1. Нет незакрытых кавычек"
    echo "  2. Нет специальных символов без экранирования"
    echo "  3. Каждая переменная на отдельной строке"
    exit 1
fi

# Проверка обязательных переменных
if [ -z "$BOT_TOKEN" ]; then
    echo "❌ BOT_TOKEN не установлен в .env файле"
    exit 1
fi

if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "⚠️  POSTGRES_PASSWORD не установлен, используется значение по умолчанию"
fi

echo "✅ Проверка переменных окружения завершена"

# Создание директорий
echo "📁 Создание структуры директорий..."
mkdir -p data logs backups

# Проверка наличия init.sql
if [ ! -f scripts/init.sql ]; then
    echo "❌ Файл scripts/init.sql не найден"
    echo "📄 Создайте файл init.sql в папке scripts/"
    exit 1
fi

echo "📊 Файл init.sql найден:"
echo "  Размер: $(wc -l < scripts/init.sql) строк"
echo "  Содержимое:"
head -5 scripts/init.sql
echo "  ..."
tail -5 scripts/init.sql

# Остановка существующих контейнеров
echo "🛑 Остановка существующих контейнеров..."
$COMPOSE_CMD down || true

# Очистка томов при необходимости
if [ "$1" = "--clean" ]; then
    echo "🧹 Очистка томов Docker..."
    docker volume rm -f support_bot_postgres_data 2>/dev/null || true
fi

# Запуск контейнеров
echo "🐳 Запуск контейнеров..."
$COMPOSE_CMD up -d

echo ""
echo "⏳ Ожидание запуска PostgreSQL..."
for i in {1..30}; do
    if $COMPOSE_CMD ps | grep -q "postgres.*Up"; then
        echo "✅ PostgreSQL запущен"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ PostgreSQL не запустился за 60 секунд"
        echo "📋 Логи PostgreSQL:"
        $COMPOSE_CMD logs postgres
        exit 1
    fi
    echo "⏳ Ожидание... ($i/30)"
    sleep 2
done

echo ""
echo "🩺 Проверка здоровья PostgreSQL..."
for i in {1..20}; do
    if $COMPOSE_CMD exec -T postgres pg_isready -U postgres > /dev/null 2>&1; then
        echo "✅ PostgreSQL готов к подключениям"
        break
    fi
    if [ $i -eq 20 ]; then
        echo "❌ PostgreSQL не готов к подключениям"
        echo "📋 Логи здоровья:"
        $COMPOSE_CMD logs postgres --tail=20
        exit 1
    fi
    echo "⏳ Проверка готовности... ($i/20)"
    sleep 3
done

echo ""
echo "🤖 Проверка запуска бота..."
for i in {1..15}; do
    if $COMPOSE_CMD ps | grep -q "bot.*Up"; then
        echo "✅ Бот запущен"
        break
    fi
    if [ $i -eq 15 ]; then
        echo "⚠️  Бот еще не запущен, проверьте логи"
        break
    fi
    echo "⏳ Ожидание запуска бота... ($i/15)"
    sleep 2
done

echo ""
echo "🔗 Тестирование подключения к базе данных..."
$COMPOSE_CMD exec -T bot python -c "
import sys
try:
    import asyncio
    from database import db_manager
    
    async def test():
        print('🔧 Тестирование подключения к PostgreSQL...')
        print(f'  Хост: postgres')
        print(f'  Порт: 5432')
        
        await db_manager.connect()
        stats = await db_manager.get_total_stats()
        print(f'✅ Подключение успешно!')
        print(f'📊 Статистика базы данных:')
        print(f'  Категорий: {stats[\"categories_count\"]}')
        print(f'  Вопросов: {stats[\"total_questions\"]}')
        print(f'  Просмотров: {stats[\"total_views\"]}')
    
    asyncio.run(test())
except Exception as e:
    print(f'❌ Ошибка подключения: {e}')
    sys.exit(1)
"

echo ""
echo "📋 Итоговый статус:"
echo "========================================="
$COMPOSE_CMD ps
echo "========================================="

echo ""
echo "📊 Команды для управления:"
echo "  Просмотр логов:           $COMPOSE_CMD logs -f"
echo "  Просмотр логов PostgreSQL: $COMPOSE_CMD logs postgres"
echo "  Просмотр логов бота:       $COMPOSE_CMD logs bot"
echo "  Остановка:                $COMPOSE_CMD down"
echo "  Перезапуск:               $COMPOSE_CMD restart"
echo "  Проверка статуса:         $COMPOSE_CMD ps"

echo ""
echo "🎉 Развертывание завершено!"
echo "📞 Теперь ваш бот доступен в Telegram!"
echo ""
echo "💡 Следующие шаги:"
echo "  1. Найдите вашего бота в Telegram"
echo "  2. Отправьте команду /start"
echo "  3. Добавьте категории и вопросы через админ-панель"
