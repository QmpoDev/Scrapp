-- Migration: 002_create_otp_tokens
-- Creates the otp_tokens table used for the Claim Shop / OTP token recovery flow.
-- Requirements: 10.5, 10.6

CREATE TABLE IF NOT EXISTS otp_tokens (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id       UUID        NOT NULL REFERENCES junkshops(id) ON DELETE CASCADE,
  otp_hash      TEXT        NOT NULL,          -- bcrypt/sha256 hash of the 6-digit OTP; never store plaintext
  expires_at    TIMESTAMPTZ NOT NULL,           -- typically now() + interval '5 minutes'
  attempt_count INTEGER     NOT NULL DEFAULT 0, -- increments on each failed verification attempt
  locked_until  TIMESTAMPTZ,                    -- nullable; set to now() + 30 min when attempt_count reaches 3
  resend_count  INTEGER     NOT NULL DEFAULT 0, -- increments on each OTP resend; capped at 3 per session
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index on shop_id for fast lookup of the latest OTP token for a given shop
CREATE INDEX IF NOT EXISTS otp_tokens_shop_idx
  ON otp_tokens (shop_id, created_at DESC);

-- Index on expires_at to support efficient cleanup of expired tokens
CREATE INDEX IF NOT EXISTS otp_tokens_expires_idx
  ON otp_tokens (expires_at);
