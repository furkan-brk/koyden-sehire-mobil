-- Backfill invitations for applications submitted before the app started
-- inserting invitation rows on submit. Without this, the inviter's
-- "Davet Ettikleriniz" list stays empty for pre-existing applications.
INSERT INTO invitations (invite_code_id, inviter_user_id, application_id, status, created_at, updated_at)
SELECT fa.invite_code_id,
       fa.referred_by_user_id,
       fa.id,
       CASE fa.status
         WHEN 'approved' THEN 'approved'
         WHEN 'rejected' THEN 'rejected'
         ELSE 'submitted'
       END,
       fa.created_at,
       NOW()
FROM farmer_applications fa
WHERE fa.invite_code_id IS NOT NULL
  AND fa.referred_by_user_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM invitations i WHERE i.application_id = fa.id
  );
