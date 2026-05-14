-- Migration: 005_otp_verify_function
-- Creates the verify_otp_and_recover_token SECURITY DEFINER function used in
-- the Claim Shop / OTP token recovery flow.
-- Requirements: 10.6, 10.7, 10.8, 10.9

CREATE OR REPLACE FUNCTION verify_otp_and_recover_token(
  p_shop_id  UUID,
  p_otp_hash TEXT   -- SHA-256 / bcrypt hash of the 6-digit OTP submitted by the user
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_otp       otp_tokens%ROWTYPE;
  v_new_token UUID;
BEGIN
  -- Fetch the most recent OTP record for this shop and lock it for the duration
  -- of this transaction to prevent concurrent verification races.
  SELECT *
    INTO v_otp
    FROM otp_tokens
   WHERE shop_id = p_shop_id
   ORDER BY created_at DESC
   LIMIT 1
     FOR UPDATE;

  -- No OTP record found for this shop.
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'no_otp_found');
  END IF;

  -- ── Check 1: Lockout ────────────────────────────────────────────────────────
  -- If locked_until is set and still in the future, reject immediately.
  IF v_otp.locked_until IS NOT NULL AND v_otp.locked_until > now() THEN
    RETURN jsonb_build_object(
      'success',      false,
      'error',        'locked',
      'locked_until', v_otp.locked_until
    );
  END IF;

  -- ── Check 2: Max attempts already reached ───────────────────────────────────
  -- If attempt_count is already >= 3 before this attempt, apply/refresh the
  -- lockout and reject.  This guards against a race where locked_until was not
  -- yet set (e.g. the record was just created with attempt_count = 3).
  IF v_otp.attempt_count >= 3 THEN
    UPDATE otp_tokens
       SET attempt_count = attempt_count + 1,
           locked_until  = now() + interval '30 minutes'
     WHERE id = v_otp.id;

    RETURN jsonb_build_object('success', false, 'error', 'max_attempts');
  END IF;

  -- ── Check 3: Expiry ─────────────────────────────────────────────────────────
  IF v_otp.expires_at < now() THEN
    RETURN jsonb_build_object('success', false, 'error', 'expired');
  END IF;

  -- ── Check 4: Hash comparison ────────────────────────────────────────────────
  -- The caller passes the hash of the OTP they received; compare it directly
  -- against the stored hash.  No plaintext OTP ever travels through this
  -- function.
  IF v_otp.otp_hash <> p_otp_hash THEN
    -- Increment attempt counter.  If this brings the count to 3, set lockout.
    UPDATE otp_tokens
       SET attempt_count = attempt_count + 1,
           locked_until  = CASE
                             WHEN attempt_count + 1 >= 3
                             THEN now() + interval '30 minutes'
                             ELSE locked_until
                           END
     WHERE id = v_otp.id;

    RETURN jsonb_build_object(
      'success',           false,
      'error',             'invalid_otp',
      'attempts_remaining', GREATEST(0, 3 - (v_otp.attempt_count + 1))
    );
  END IF;

  -- ── All checks passed: rotate edit_token and clean up ───────────────────────
  -- Generate a fresh edit_token on the junkshops record so the old token is
  -- immediately invalidated.
  UPDATE junkshops
     SET edit_token = gen_random_uuid()
   WHERE id = p_shop_id
  RETURNING edit_token INTO v_new_token;

  -- Remove the consumed OTP record so it cannot be replayed.
  DELETE FROM otp_tokens WHERE id = v_otp.id;

  RETURN jsonb_build_object(
    'success',    true,
    'edit_token', v_new_token
  );
END;
$$;
