-- ════════════════════════════════════════════════════════════════════
-- 2026-11-05  Lock down profiles.is_admin and internal functions
-- ════════════════════════════════════════════════════════════════════
-- Applied to the live project as two migrations:
--   lock_down_profiles_is_admin_and_internal_functions
--   restore_profile_save_columns_keep_is_admin_locked
--
-- WHY: the "Users can update own profile" policy let any signed-in user write
-- their own row, and is_admin was a writable column, so one API call could have
-- made any account an admin (unlocking admin_users() and the admin read policies).
-- The fix is column-level: the API roles can no longer write is_admin at all.
-- (Verified afterwards: self-promotion fails with "permission denied", normal
-- profile edits still work, and the only is_admin = true row is the owner's.)
-- Requires: public.is_admin(), admin_overview(), admin_users(), handle_new_user(),
-- rls_auto_enable(), set_updated_at() to already exist (they do in the live project).

-- 1. Make is_admin unwritable from the API (only the columns listed are writable)
revoke insert, update on public.profiles from anon, authenticated;
grant insert (id, name, primary_language, visa_status, marketing_consent, phone, created_at, updated_at)
  on public.profiles to authenticated;
grant update (id, name, primary_language, visa_status, marketing_consent, phone, updated_at)
  on public.profiles to authenticated;

-- 2. Lock down internal functions
revoke execute on function public.handle_new_user() from anon, authenticated, public;
revoke execute on function public.rls_auto_enable() from anon, authenticated, public;
revoke execute on function public.is_admin() from anon;
revoke execute on function public.admin_overview() from anon;
revoke execute on function public.admin_users() from anon;

-- 3. Pin the search path
alter function public.set_updated_at() set search_path = public;

-- Still to do by hand (dashboard, cannot be done in SQL):
--   Authentication → password security → enable "Leaked password protection".
