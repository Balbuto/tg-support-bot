-- Инициализация базы данных для Telegram Support Bot

-- Проверка и создание расширений
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS btree_gin;

-- Таблица категорий
CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Таблица вопросов
CREATE TABLE IF NOT EXISTS questions (
    id SERIAL PRIMARY KEY,
    category_id INTEGER NOT NULL,
    question TEXT NOT NULL,
    answer TEXT NOT NULL,
    views INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(category_id, question),
    CONSTRAINT fk_category
        FOREIGN KEY(category_id) 
        REFERENCES categories(id)
        ON DELETE CASCADE
);

-- Таблица статистики
CREATE TABLE IF NOT EXISTS statistics (
    id SERIAL PRIMARY KEY,
    action VARCHAR(100) NOT NULL UNIQUE,
    count INTEGER DEFAULT 0,
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Индексы для производительности
CREATE INDEX IF NOT EXISTS idx_questions_category_id ON questions(category_id);
CREATE INDEX IF NOT EXISTS idx_questions_question_gin ON questions USING gin(question gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_categories_name ON categories(name);
CREATE INDEX IF NOT EXISTS idx_statistics_action ON statistics(action);

-- Вставляем базовые данные статистики
INSERT INTO statistics (action, count, last_activity) VALUES 
('start_command', 0, CURRENT_TIMESTAMP),
('question_viewed', 0, CURRENT_TIMESTAMP),
('search_performed', 0, CURRENT_TIMESTAMP),
('category_added', 0, CURRENT_TIMESTAMP),
('question_added', 0, CURRENT_TIMESTAMP),
('question_edited', 0, CURRENT_TIMESTAMP),
('question_deleted', 0, CURRENT_TIMESTAMP),
('feedback_positive', 0, CURRENT_TIMESTAMP),
('feedback_negative', 0, CURRENT_TIMESTAMP),
('support_requested', 0, CURRENT_TIMESTAMP)
ON CONFLICT (action) DO NOTHING;

-- Создаем пользователя для приложения (если нужно)
-- DO $$
-- BEGIN
--   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'app_user') THEN
--     CREATE ROLE app_user WITH LOGIN PASSWORD 'app_password';
--   END IF;
-- END
-- $$;
-- 
-- GRANT CONNECT ON DATABASE support_bot TO app_user;
-- GRANT USAGE ON SCHEMA public TO app_user;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
-- GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_user;
