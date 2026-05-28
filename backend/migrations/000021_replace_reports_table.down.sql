DROP TABLE IF EXISTS reports;

-- Restore the original stub table from migration 10
CREATE TABLE reports (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id     UUID        NOT NULL REFERENCES products(id),
  reporter_phone VARCHAR(20),
  reason         VARCHAR(50) NOT NULL,
  description    TEXT,
  status         VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (
    status IN ('pending', 'reviewed', 'dismissed')
  ),
  created_at     TIMESTAMP   NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMP   NOT NULL DEFAULT NOW()
);
