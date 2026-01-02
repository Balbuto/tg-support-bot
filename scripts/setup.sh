#!/bin/bash
set -e

echo "⚙️  Настройка Telegram Support Bot"

# Создаем структуру директорий
echo "📁 Создание структуры директорий..."
mkdir -p scripts data logs backups

# Создаем необходимые файлы если их нет
if [ ! -f docker-compose.yml ]; then
    echo "📄 Создание docker-compose.yml..."
    curl -sSL https://raw.githubusercontent.com/balbuto/telegram-support-bot/main/docker-compose.yml -o docker-compose.yml
fi

if [ ! -f .env.example ]; then
    echo "📄 Создание .env.example..."
    curl -sSL https://raw.githubusercontent.com/balbuto/telegram-support-bot/main/.env.example -o .env.example
fi

if [ ! -f scripts/init.sql ]; then
    echo "📄 Создание scripts/init.sql..."
    curl -sSL https://raw.githubusercontent.com/balbuto/telegram-support-bot/main/scripts/init.sql -o scripts/init.sql
fi

# Скачиваем остальные скрипты
SCRIPTS=("deploy.sh" "start.sh" "stop.sh" "restart.sh" "logs.sh" "status.sh" "backup.sh" "restore.sh")
for script in "${SCRIPTS[@]}"; do
    if [ ! -f "scripts/$script" ]; then
        echo "📄 Создание scripts/$script..."
        curl -sSL "https://raw.githubusercontent.com/balbuto/telegram-support-bot/main/scripts/$script" -o "scripts/$script"
        chmod +x "scripts/$script"
    fi
done

# Создаем .env если его нет
if [ ! -f .env ]; then
    echo ""
    echo "📝 Создание файла конфигурации .env"
    echo "========================================="
    cp .env.example .env
    
    echo "⚙️  Отредактируйте файл .env перед запуском:"
    echo "  1. Укажите BOT_TOKEN (получите у @BotFather)"
    echo "  2. Укажите ADMIN_IDS (ваш Telegram ID)"
    echo "  3. Настройте POSTGRES_PASSWORD"
    echo ""
    echo "📋 Команда для редактирования:"
    echo "  nano .env  # или используйте ваш любимый редактор"
    echo ""
    echo "💡 После настройки запустите:"
    echo "  ./scripts/deploy.sh"
else
    echo "✅ Файл .env уже существует"
fi

echo ""
echo "✅ Настройка завершена!"
echo "📋 Доступные команды:"
echo "  ./scripts/deploy.sh     - Развертывание бота"
echo "  ./scripts/start.sh      - Запуск бота"
echo "  ./scripts/stop.sh       - Остановка бота"
echo "  ./scripts/restart.sh    - Перезапуск бота"
echo "  ./scripts/logs.sh       - Просмотр логов"
echo "  ./scripts/status.sh     - Статус системы"
echo "  ./scripts/backup.sh     - Создание резервной копии"
echo "  ./scripts/restore.sh    - Восстановление из резервной копии"
