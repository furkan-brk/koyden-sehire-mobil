-- KVKK hesap silme audit logu için enum genişletmesi
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'ACCOUNT_DELETED';
ALTER TYPE audit_target_type ADD VALUE IF NOT EXISTS 'user';
