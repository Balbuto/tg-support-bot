#!/bin/bash
set -e

# Определяем команду compose
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

BACKUP_FILE="${1}"

if [ -z "$BACKUP_FILE" ]; then
    echo "❌ Укажите файл для восстановления"
    echo "📋 Использование: ./scripts/restore.sh <backup_file.json>"
    echo ""
    echo "📁 Доступные резервные копии:"
    ls -la backups/*.json 2>/dev/null || echo "  Файлы не найдены"
    exit 1
fi

if [ ! -f "backups/$BACKUP_FILE" ]; then
    echo "❌ Файл backups/$BACKUP_FILE не найден"
    exit 1
fi

echo "🔄 Восстановление из резервной копии: $BACKUP_FILE"
echo "⚠️  Внимание: текущие данные будут перезаписаны!"

read -p "❓ Продолжить? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Восстановление отменено"
    exit 1
fi

# Копируем файл в контейнер
echo "📤 Копирование файла в контейнер..."
docker cp "backups/$BACKUP_FILE" telegram_support_bot:/app/backups/restore.json

# Выполняем восстановление
echo "🔧 Восстановление данных..."
$COMPOSE_CMD exec -T bot python -c "
import asyncio
import json
import os
from database import db_manager

async def restore_backup():
    print('🔧 Подключение к базе данных...')
    await db_manager.connect()
    
    print('📥 Чтение файла восстановления...')
    with open('/app/backups/restore.json', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    print('🔄 Импорт данных...')
    success = await db_manager.import_data(data)
    
    if success:
        print('✅ Восстановление завершено успешно!')
        
        # Получаем статистику
        stats = await db_manager.get_total_stats()
        print(f'📊 Текущая статистика:')
        print(f'  Категорий: {stats[\"categories_count\"]}')
        print(f'  Вопросов: {stats[\"total_questions\"]}')
        print(f'  Просмотров: {stats[\"total_views\"]}')
    else:
        print('❌ Ошибка при восстановлении данных')

asyncio.run(restore_backup())
"

# Очищаем временный файл
docker exec telegram_support_bot rm -f /app/backups/restore.json

echo ""
echo "🎉 Восстановление завершено!"
