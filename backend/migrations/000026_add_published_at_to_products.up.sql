ALTER TABLE products ADD COLUMN published_at TIMESTAMPTZ;

-- Backfill already-published products so they keep a sensible order instead of
-- all sinking to the bottom under "published_at DESC NULLS LAST".
UPDATE products
SET published_at = COALESCE(updated_at, created_at)
WHERE status = 'active' AND published_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_products_published_at ON products (published_at DESC);
