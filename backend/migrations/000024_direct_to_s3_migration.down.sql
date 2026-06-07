-- Rollback Phase 1 changes: rename image_key back to image_url, restore NOT NULL constraints, and restore original status check constraint.

-- First, ensure there are no NULL values in these columns (might fail if dirty data exists, but standard for rollback)
UPDATE products SET category_id = '00000000-0000-0000-0000-000000000000' WHERE category_id IS NULL;
UPDATE products SET title = '' WHERE title IS NULL;
UPDATE products SET description = '' WHERE description IS NULL;
UPDATE products SET price = 0 WHERE price IS NULL;
UPDATE products SET unit = 'adet' WHERE unit IS NULL;
UPDATE products SET city = '' WHERE city IS NULL;
UPDATE products SET district = '' WHERE district IS NULL;
UPDATE products SET village = '' WHERE village IS NULL;

ALTER TABLE products ALTER COLUMN category_id SET NOT NULL;
ALTER TABLE products ALTER COLUMN title SET NOT NULL;
ALTER TABLE products ALTER COLUMN description SET NOT NULL;
ALTER TABLE products ALTER COLUMN price SET NOT NULL;
ALTER TABLE products ALTER COLUMN unit SET NOT NULL;
ALTER TABLE products ALTER COLUMN city SET NOT NULL;
ALTER TABLE products ALTER COLUMN district SET NOT NULL;
ALTER TABLE products ALTER COLUMN village SET NOT NULL;

-- Remove products with new status values before restoring constraint (or update them)
UPDATE products SET status = 'draft' WHERE status IN ('on-going', 'successful', 'failed');

ALTER TABLE products DROP CONSTRAINT IF EXISTS products_status_check;
ALTER TABLE products ADD CONSTRAINT products_status_check CHECK (
  status IN ('draft', 'pending', 'active', 'passive', 'rejected', 'hidden')
);

ALTER TABLE product_images RENAME COLUMN image_key TO image_url;
