-- Migration: 004_update_shop_function
-- Creates the update_shop_with_token SECURITY DEFINER function.
--
-- This function is the sole permitted path for anonymous clients to update
-- shop fields. It validates the caller-supplied edit_token against the
-- stored value before applying any changes, satisfying the RLS requirement
-- that anonymous users may NOT UPDATE records directly (Requirement 12.7).
--
-- Return value:
--   TRUE  – token matched and fields were updated successfully
--   FALSE – shop not found OR edit_token did not match (no exception raised)
--
-- Requirements: 9.4, 9.9, 9.10, 12.7

CREATE OR REPLACE FUNCTION update_shop_with_token(
  p_shop_id        UUID,
  p_edit_token     UUID,
  p_name           TEXT,
  p_owner_name     TEXT,
  p_contact_number TEXT,
  p_schedule       TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
-- Run as the postgres role so the function can bypass RLS and perform the
-- UPDATE even though the calling anon role has no direct UPDATE privilege.
SET search_path = public
AS $$
DECLARE
  v_stored_token UUID;
BEGIN
  -- Fetch the stored edit_token for the given shop.
  -- FOR UPDATE locks the row to prevent concurrent token-swap races.
  SELECT edit_token
    INTO v_stored_token
    FROM junkshops
   WHERE id = p_shop_id
     FOR UPDATE;

  -- Shop not found → return FALSE without raising an exception.
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;

  -- Token mismatch → return FALSE without raising an exception.
  -- Uses the UUID equality operator; NULL tokens are treated as non-matching.
  IF v_stored_token IS DISTINCT FROM p_edit_token THEN
    RETURN FALSE;
  END IF;

  -- Token matched: apply the field updates.
  -- Only the four editable fields are touched; status, device_id, edit_token,
  -- submitted_at, and storefront_photo_url are intentionally excluded
  -- (Requirement 9.13).
  UPDATE junkshops
     SET name           = p_name,
         owner_name     = p_owner_name,
         contact_number = p_contact_number,
         schedule       = p_schedule
   WHERE id = p_shop_id;

  RETURN TRUE;
END;
$$;

-- Transfer ownership to the postgres superuser role so that SECURITY DEFINER
-- executes with full privileges regardless of which role created the function.
ALTER FUNCTION update_shop_with_token(UUID, UUID, TEXT, TEXT, TEXT, TEXT)
  OWNER TO postgres;

-- Grant EXECUTE to the anon role so the Flutter app (using the anon key) can
-- call this function via Supabase RPC without needing direct table UPDATE.
GRANT EXECUTE ON FUNCTION update_shop_with_token(UUID, UUID, TEXT, TEXT, TEXT, TEXT)
  TO anon;
