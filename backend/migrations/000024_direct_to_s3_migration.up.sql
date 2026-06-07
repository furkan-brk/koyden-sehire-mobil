-- Phase 1: Support 'on-going', 'successful', 'failed' statuses, make columns nullable for draft mode, and rename image_url to image_key.

ALTER TABLE products ALTER COLUMN category_id DROP NOT NULL;
ALTER TABLE products ALTER COLUMN title DROP NOT NULL;
ALTER TABLE products ALTER COLUMN description DROP NOT NULL;
ALTER TABLE products ALTER COLUMN price DROP NOT NULL;
ALTER TABLE products ALTER COLUMN unit DROP NOT NULL;
ALTER TABLE products ALTER COLUMN city DROP NOT NULL;
ALTER TABLE products ALTER COLUMN district DROP NOT NULL;
ALTER TABLE products ALTER COLUMN village DROP NOT NULL;

ALTER TABLE products DROP CONSTRAINT IF EXISTS products_status_check;
ALTER TABLE products ADD CONSTRAINT products_status_check CHECK (
  status IN ('draft', 'pending', 'active', 'passive', 'rejected', 'hidden', 'on-going', 'successful', 'failed')
);

ALTER TABLE product_images RENAME COLUMN image_url TO image_key;
