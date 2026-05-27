-- Drop the minimal stub table created in migration 10 and replace it
-- with the full reports schema that supports both product and farmer targets,
-- optional reporter (guest-friendly), admin review workflow, and duplicate prevention.

DROP TABLE IF EXISTS reports;

CREATE TABLE reports (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id  UUID        REFERENCES users(id) ON DELETE SET NULL,
  target_type  VARCHAR(20) NOT NULL CHECK (target_type IN ('product', 'farmer')),
  target_id    UUID        NOT NULL,
  reason       VARCHAR(30) NOT NULL CHECK (reason IN ('inappropriate', 'misleading', 'spam', 'other')),
  note         TEXT        NOT NULL DEFAULT '',
  status       VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'dismissed')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at  TIMESTAMPTZ,
  reviewed_by  UUID        REFERENCES users(id) ON DELETE SET NULL,
  review_note  TEXT        NOT NULL DEFAULT ''
);

CREATE INDEX idx_reports_status      ON reports (status);
CREATE INDEX idx_reports_target      ON reports (target_type, target_id);
CREATE INDEX idx_reports_reporter    ON reports (reporter_id) WHERE reporter_id IS NOT NULL;
CREATE INDEX idx_reports_created_at  ON reports (created_at DESC);
