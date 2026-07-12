ALTER TABLE notifications ADD COLUMN data JSONB NOT NULL DEFAULT '{}'::jsonb;
