-- Migration: 003_rls_policies
-- Enables Row Level Security on the junkshops and otp_tokens tables
-- and defines access policies for anonymous and authenticated roles.
--
-- Policy summary for junkshops:
--   anon  SELECT  → only rows where status IN ('pending', 'verified')
--   anon  INSERT  → allowed when status = 'pending' (new registrations)
--   anon  UPDATE  → DENIED (updates go through the update_shop_with_token DB function)
--   anon  DELETE  → DENIED
--   authenticated / service_role → full access (bypasses RLS via service_role key)
--
-- Policy summary for otp_tokens:
--   anon  INSERT  → allowed (OTP creation during claim flow)
--   anon  SELECT  → allowed (OTP lookup during claim flow)
--   anon  UPDATE  → DENIED
--   anon  DELETE  → DENIED
--
-- Requirements: 12.7

-- ─────────────────────────────────────────────────────────────────────────────
-- junkshops
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE junkshops ENABLE ROW LEVEL SECURITY;

-- Anonymous SELECT: only pending and verified records are visible
CREATE POLICY "anon_select_shops"
  ON junkshops
  FOR SELECT
  TO anon
  USING (status IN ('pending', 'verified'));

-- Anonymous INSERT: new registrations must enter as 'pending'
CREATE POLICY "anon_insert_shops"
  ON junkshops
  FOR INSERT
  TO anon
  WITH CHECK (status = 'pending');

-- Explicitly DENY direct UPDATE for anonymous users.
-- All owner-initiated updates must go through the update_shop_with_token
-- SECURITY DEFINER function which validates the edit_token server-side.
CREATE POLICY "anon_deny_update_shops"
  ON junkshops
  FOR UPDATE
  TO anon
  USING (false);

-- Explicitly DENY direct DELETE for anonymous users.
CREATE POLICY "anon_deny_delete_shops"
  ON junkshops
  FOR DELETE
  TO anon
  USING (false);

-- Authenticated role (admin dashboard via service_role key) gets full access.
-- The service_role key bypasses RLS entirely, so no explicit policy is needed
-- for service_role. The authenticated policy below covers admin users who
-- connect via Supabase Auth (email/password) rather than the service_role key.
CREATE POLICY "authenticated_full_access_shops"
  ON junkshops
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- otp_tokens
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE otp_tokens ENABLE ROW LEVEL SECURITY;

-- Anonymous INSERT: allow OTP record creation during the claim flow
CREATE POLICY "anon_insert_otp"
  ON otp_tokens
  FOR INSERT
  TO anon
  WITH CHECK (true);

-- Anonymous SELECT: allow OTP lookup during the claim flow
CREATE POLICY "anon_select_otp"
  ON otp_tokens
  FOR SELECT
  TO anon
  USING (true);

-- Explicitly DENY direct UPDATE for anonymous users on otp_tokens.
-- OTP state changes (attempt_count, locked_until) are performed only by
-- the verify_otp_and_recover_token SECURITY DEFINER function.
CREATE POLICY "anon_deny_update_otp"
  ON otp_tokens
  FOR UPDATE
  TO anon
  USING (false);

-- Explicitly DENY direct DELETE for anonymous users on otp_tokens.
-- Deletion is handled by the verify_otp_and_recover_token function on success.
CREATE POLICY "anon_deny_delete_otp"
  ON otp_tokens
  FOR DELETE
  TO anon
  USING (false);

-- Authenticated role gets full access to otp_tokens (admin operations)
CREATE POLICY "authenticated_full_access_otp"
  ON otp_tokens
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);
