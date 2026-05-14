// OtpService — handles OTP send and verify via Supabase Edge Function / RPC
// Requirements: 10.3, 10.6, 10.7, 10.8, 10.9, 10.10, 10.11

import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of an OTP send request.
class OtpSendResult {
  const OtpSendResult({required this.success, this.error});

  /// Whether the OTP was successfully triggered.
  final bool success;

  /// Error description if [success] is `false`.
  final String? error;
}

/// Result of an OTP verification request.
class OtpVerifyResult {
  const OtpVerifyResult({
    required this.success,
    this.editToken,
    this.error,
    this.attemptsRemaining,
    this.lockedUntil,
  });

  /// Whether the OTP was verified successfully.
  final bool success;

  /// The new edit token returned on successful verification.
  final String? editToken;

  /// Error code on failure. Possible values:
  /// - `'locked'` — too many failed attempts; locked until [lockedUntil]
  /// - `'max_attempts'` — 3 attempts exhausted (alias for locked state)
  /// - `'expired'` — OTP has passed its 5-minute expiry
  /// - `'invalid_otp'` — OTP value did not match
  /// - `'no_otp_found'` — no OTP record exists for this shop
  final String? error;

  /// Number of verification attempts remaining (present when error is
  /// `'invalid_otp'`).
  final int? attemptsRemaining;

  /// The UTC timestamp after which the lockout expires (present when error is
  /// `'locked'`).
  final DateTime? lockedUntil;
}

/// Service that sends and verifies OTPs for the Claim Shop / token-recovery
/// flow (Requirement 10).
///
/// OTP sending is handled entirely server-side via a Supabase Edge Function.
/// OTP verification is handled via the `verify_otp_and_recover_token` RPC.
class OtpService {
  OtpService(this._client);

  final SupabaseClient _client;

  /// Triggers an OTP SMS to the contact number associated with [shopId].
  ///
  /// Calls the `send-otp` Edge Function with `{ shop_id: shopId }`.
  /// The server looks up the shop's contact number and sends the SMS.
  ///
  /// Returns [OtpSendResult.success] == `true` on success, or
  /// [OtpSendResult.error] with a description on failure.
  ///
  /// Requirement 10.3, 10.11
  Future<OtpSendResult> sendOtp(String shopId) async {
    try {
      final response = await _client.functions.invoke(
        'send-otp',
        body: {'shop_id': shopId},
      );

      // Edge Function returns a JSON body; treat any non-error response as
      // success. The function itself returns { success: true } or
      // { error: '...' }.
      final data = response.data;
      if (data is Map && data['error'] != null) {
        return OtpSendResult(success: false, error: data['error'].toString());
      }

      return const OtpSendResult(success: true);
    } on FunctionException catch (e) {
      return OtpSendResult(
        success: false,
        error: e.details?.toString() ?? 'Failed to send OTP',
      );
    } catch (e) {
      return OtpSendResult(success: false, error: e.toString());
    }
  }

  /// Verifies [otp] for [shopId] against the server-side stored value.
  ///
  /// Calls the `verify_otp_and_recover_token` RPC with:
  /// - `p_shop_id`: the shop UUID
  /// - `p_otp_hash`: the raw 6-digit OTP (the server stores and compares the
  ///   same value; the parameter name is a legacy artefact)
  ///
  /// On success, returns [OtpVerifyResult.success] == `true` and
  /// [OtpVerifyResult.editToken] containing the new edit token UUID.
  ///
  /// On failure, returns [OtpVerifyResult.success] == `false` with
  /// [OtpVerifyResult.error] set to one of:
  /// - `'locked'` — lockout active; [OtpVerifyResult.lockedUntil] is set
  /// - `'expired'` — OTP has expired
  /// - `'invalid_otp'` — wrong OTP; [OtpVerifyResult.attemptsRemaining] is set
  /// - `'no_otp_found'` — no OTP record for this shop
  ///
  /// Requirements 10.6, 10.7, 10.8, 10.9
  Future<OtpVerifyResult> verifyOtp(String shopId, String otp) async {
    try {
      final result = await _client.rpc(
        'verify_otp_and_recover_token',
        params: {'p_shop_id': shopId, 'p_otp_hash': otp},
      );

      // The RPC returns a JSONB object.
      final data = result as Map<String, dynamic>?;

      if (data == null) {
        return const OtpVerifyResult(success: false, error: 'no_otp_found');
      }

      // Success path: { edit_token: '<uuid>' }
      if (data['edit_token'] != null) {
        return OtpVerifyResult(
          success: true,
          editToken: data['edit_token'].toString(),
        );
      }

      // Error path: { error: '<code>', ... }
      final errorCode = data['error']?.toString();

      if (errorCode == 'locked') {
        final lockedUntilRaw = data['locked_until'];
        DateTime? lockedUntil;
        if (lockedUntilRaw != null) {
          lockedUntil = DateTime.tryParse(lockedUntilRaw.toString());
        }
        return OtpVerifyResult(
          success: false,
          error: 'locked',
          lockedUntil: lockedUntil,
        );
      }

      if (errorCode == 'invalid_otp') {
        final attemptsRaw = data['attempts_remaining'];
        int? attemptsRemaining;
        if (attemptsRaw != null) {
          attemptsRemaining = int.tryParse(attemptsRaw.toString());
        }
        return OtpVerifyResult(
          success: false,
          error: 'invalid_otp',
          attemptsRemaining: attemptsRemaining,
        );
      }

      // Covers: 'expired', 'no_otp_found', and any other server error codes.
      return OtpVerifyResult(
        success: false,
        error: errorCode ?? 'unknown_error',
      );
    } on PostgrestException {
      return const OtpVerifyResult(success: false, error: 'network_error');
    } catch (_) {
      return const OtpVerifyResult(success: false, error: 'network_error');
    }
  }
}
