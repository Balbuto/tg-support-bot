-- Инициализация базы данных для Telegram Support Bot
-- Этот файл автоматически выполняется при первом запуске PostgreSQL

-- Проверка и создание расширений для полнотекстового поиска
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;

-- Таблица категорий FAQ
CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE categories IS 'Таблица категорий вопросов';
COMMENT ON COLUMN categories.name IS 'Название категории (уникальное)';
COMMENT ON COLUMN categories.description IS 'Описание категории';

-- Таблица вопросов-ответов
CREATE TABLE IF NOT EXISTS questions (
    id SERIAL PRIMARY KEY,
    category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    views INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(category_id, question)
);

COMMENT ON TABLE questions IS 'Таблица вопросов и ответов';
COMMENT ON COLUMN questions.question IS 'Текст вопроса';
COMMENT ON COLUMN questions.answer IS 'Текст ответа';
COMMENT ON COLUMN questions.views IS 'Количество просмотров вопроса';

-- Таблица статистики использования бота
CREATE TABLE IF NOT EXISTS statistics (
    id SERIAL PRIMARY KEY,
    action VARCHAR(100) NOT NULL UNIQUE,
    count INTEGER DEFAULT 0,
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE statistics IS 'Таблица статистики использования бота';
COMMENT ON COLUMN statistics.action IS 'Тип действия (команда/событие)';
COMMENT ON COLUMN statistics.count IS 'Количество выполнений действия';
COMMENT ON COLUMN statistics.last_activity IS 'Время последнего выполнения';

-- Индексы для оптимизации производительности

-- Индекс для быстрого поиска вопросов по категории
CREATE INDEX IF NOT EXISTS idx_questions_category_id ON questions(category_id);

-- GIN индекс для полнотекстового поиска по вопросам (триграммы)
CREATE INDEX IF NOT EXISTS idx_questions_question_gin ON questions USING gin(question gin_trgm_ops);

-- Индекс для поиска по названиям категорий
CREATE INDEX IF NOT EXISTS idx_categories_name ON categories(name);

-- Индекс для статистики
CREATE INDEX IF NOT EXISTS idx_statistics_action ON statistics(action);

-- Вставляем базовые данные статистики
-- Эти записи отслеживают основные действия пользователей
INSERT INTO statistics (action, count, last_activity) VALUES 
('start_command', 0, CURRENT_TIMESTAMP),          -- Команда /start
('question_viewed', 0, CURRENT_TIMESTAMP),        -- Просмотр вопроса
('search_performed', 0, CURRENT_TIMESTAMP),       -- Выполнен поиск
('category_added', 0, CURRENT_TIMESTAMP),         -- Добавлена категория
('question_added', 0, CURRENT_TIMESTAMP),         -- Добавлен вопрос
('question_edited', 0, CURRENT_TIMESTAMP),        -- Отредактирован вопрос
('question_deleted', 0, CURRENT_TIMESTAMP),       -- Удален вопрос
('feedback_positive', 0, CURRENT_TIMESTAMP),      -- Положительный отзыв
('feedback_negative', 0, CURRENT_TIMESTAMP),      -- Отрицательный отзыв
('support_requested', 0, CURRENT_TIMESTAMP)       -- Обращение в поддержку
ON CONFLICT (action) DO NOTHING;

-- Создаем функцию для автоматического обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Триггер для автоматического обновления updated_at в таблице categories
DROP TRIGGER IF EXISTS update_categories_updated_at ON categories;
CREATE TRIGGER update_categories_updated_at
    BEFORE UPDATE ON categories
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Триггер для автоматического обновления updated_at в таблице questions
DROP TRIGGER IF EXISTS update_questions_updated_at ON questions;
CREATE TRIGGER update_questions_updated_at
    BEFORE UPDATE ON questions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Функция для поиска вопросов (можно использовать из приложения)
CREATE OR REPLACE FUNCTION search_questions(search_query TEXT)
RETURNS TABLE(
    category_name VARCHAR(255),
    question_text TEXT,
    answer_text TEXT,
    similarity REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.name AS category_name,
        q.question AS question_text,
        q.answer AS answer_text,
        similarity(q.question, search_query) AS similarity
    FROM questions q
    JOIN categories c ON q.category_id = c.id
    WHERE q.question % search_query
       OR unaccent(q.question) ILIKE '%' || unaccent(search_query) || '%'
    ORDER BY similarity DESC, q.views DESC
    LIMIT 50;
END;
$$ LANGUAGE plpgsql;

-- Пример вставки тестовых данных (раскомментировать при необходимости)
/*
-- Тестовая категория
INSERT INTO categories (name, description) VALUES 
('Общие вопросы', 'Часто задаваемые вопросы общего характера')
ON CONFLICT (name) DO NOTHING;

-- Тестовые вопросы
INSERT INTO questions (category_id, question, answer) VALUES 
(1, 'Как зарегистрироваться?', 'Для регистрации перейдите на страницу /register и заполните форму.'),
(1, 'Как сбросить пароль?', 'Нажмите "Забыли пароль?" на странице входа.')
ON CONFLICT (category_id, question) DO UPDATE 
SET answer = EXCLUDED.answer;
*/

-- Информационное сообщение при выполнении скрипта
DO $$
BEGIN
    RAISE NOTICE '✅ База данных Telegram Support Bot инициализирована';
    RAISE NOTICE '📊 Созданы таблицы: categories, questions, statistics';
    RAISE NOTICE '🔍 Созданы индексы для оптимизации поиска';
    RAISE NOTICE '📈 Добавлены записи статистики';
END $$;
