CREATE TYPE audit_action AS ENUM (
    'APPLICATION_APPROVED',
    'APPLICATION_REJECTED',
    'APPLICATION_VIDEO_REQUESTED',
    'PRODUCT_APPROVED',
    'PRODUCT_REJECTED',
    'PRODUCT_HIDDEN',
    'PRODUCT_DELETED',
    'FARMER_SUSPENDED',
    'FARMER_REACTIVATED',
    'FARMER_FOUNDING_SET',
    'FARMER_INVITE_QUOTA_UPDATED',
    'CATEGORY_CREATED',
    'CATEGORY_UPDATED',
    'CATEGORY_DELETED'
);

CREATE TYPE audit_target_type AS ENUM (
    'application',
    'product',
    'farmer',
    'category'
);

CREATE TABLE admin_audit_logs (
    id              UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id        UUID              NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    action          audit_action      NOT NULL,
    target_type     audit_target_type NOT NULL,
    target_id       UUID              NOT NULL,
    target_snapshot JSONB             NULL,
    reason          TEXT              NULL,
    metadata        JSONB             NULL,
    created_at      TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_admin_id       ON admin_audit_logs (admin_id);
CREATE INDEX idx_audit_logs_action         ON admin_audit_logs (action);
CREATE INDEX idx_audit_logs_target         ON admin_audit_logs (target_type, target_id);
CREATE INDEX idx_audit_logs_created_at     ON admin_audit_logs (created_at DESC);
CREATE INDEX idx_audit_logs_created_action ON admin_audit_logs (created_at DESC, action);
