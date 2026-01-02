#!/bin/bash
set -e

# Определяем команду compose
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="backup_${TIMESTAMP}.json"

echo "💾 Создание резервной копии данных..."
echo "📁 Файл: $BACKUP_FILE"

$COMPOSE_CMD exec -T bot python -c "
import asyncio
import json
import os
from datetime import datetime
from database import db_manager

async def create_backup():
    print('🔧 Подключение к базе данных...')
    await db_manager.connect()
    
    print('📊 Экспорт данных...')
    data = await db_manager.export_data()
    
    # Добавляем метаданные
    data['backup_metadata'] = {
        'created_at': datetime.now().isoformat(),
        'version': '1.0',
        'description': 'Telegram Support Bot Backup'
    }
    
    backup_path = f'/app/backups/$BACKUP_FILE'
    with open(backup_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print(f'✅ Резервная копия создана: $BACKUP_FILE')
    
    # Статистика
    categories = len(data.get('categories', {}))
    questions = sum(len(q) for q in data.get('questions', {}).values())
    print(f'📊 Сохранено данных:')
    print(f'  Категорий: {categories}')
    print(f'  Вопросов: {questions}')
    print(f'  Статистика: {len(data.get(\"statistics\", {}))} записей')

asyncio.run(create_backup())
"

echo ""
echo "📁 Список резервных копий:"
ls -la backups/*.json 2>/dev/null | head -10 || echo "  Резервные копии не найдены"
