-- Admin kullanıcısı 000012_seed_admin tarafından oluşturulur; burada yalnızca
-- founder davet kodu eklenir.
INSERT INTO invite_codes (
  code,
  owner_user_id,
  owner_type,
  max_uses,
  used_count,
  is_active
) VALUES (
  'KYS-FOUNDER',
  (SELECT id FROM users WHERE phone = '05000000000'),
  'admin',
  50,
  0,
  true
) ON CONFLICT (code) DO NOTHING;
