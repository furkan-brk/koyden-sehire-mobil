DROP INDEX IF EXISTS idx_products_published_at;
ALTER TABLE products DROP COLUMN IF EXISTS published_at;
