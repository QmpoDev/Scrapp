// ClaimShopScreen — two-step OTP recovery flow for claiming a shop.
//
// Step 1: Contact number entry → triggers OTP send via Edge Function.
// Step 2: 6-digit OTP entry with countdown timer, attempt counter,
//         resend button, and lockout display.
//
// Requirements: 10.1–10.12

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/junkshop.dart';
import '../services/otp_service.dart';
import '../theme.dart';

class ClaimShopScreen extends StatefulWidget {
  const ClaimShopScreen({super.key, required this.shop});

  final JunkshopModel shop;

  @override
  State<ClaimShopScreen> createState() => _ClaimShopScreenState();
}

class _ClaimShopScreenState extends State<ClaimShopScreen> {
  // ── Step tracking ─────────────────────────────────────────────────────────
  int _step = 1; // 1 = contact entry, 2 = OTP entry

  // ── Step 1 state ──────────────────────────────────────────────────────────
  final _contactController = TextEditingController();
  bool _sendingOtp = false;

  // ── Step 2 state ──────────────────────────────────────────────────────────
  final _otpController = TextEditingController();
  bool _verifying = false;

  /// Seconds remaining on the 5-minute OTP expiry countdown.
  int _secondsRemaining = 300;
  Timer? _countdownTimer;

  /// Attempts remaining (max 3). Null until first verify attempt.
  int _attemptsRemaining = 3;

  /// Number of times OTP has been resent (max 3).
  int _resendCount = 0;
  static const int _maxResends = 3;

  /// Whether the OTP has expired (countdown reached 0).
  bool _otpExpired = false;

  /// Whether the account is locked out.
  bool _locked = false;

  /// Remaining lockout seconds (30-minute = 1800 s).
  int _lockoutSecondsRemaining = 0;
  Timer? _lockoutTimer;

  // ── Services ──────────────────────────────────────────────────────────────
  late final OtpService _otpService;
  static const _storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _otpService = OtpService(Supabase.instance.client);
  }

  @override
  void dispose() {
    _contactController.dispose();
    _otpController.dispose();
    _countdownTimer?.cancel();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  // ── Countdown helpers ─────────────────────────────────────────────────────

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _secondsRemaining = 300;
      _otpExpired = false;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _otpExpired = true;
          t.cancel();
        }
      });
    });
  }

  void _startLockoutTimer(DateTime lockedUntil) {
    _lockoutTimer?.cancel();
    final remaining = lockedUntil.difference(DateTime.now().toUtc()).inSeconds;
    setState(() {
      _locked = true;
      _lockoutSecondsRemaining = remaining > 0 ? remaining : 0;
    });
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_lockoutSecondsRemaining > 0) {
          _lockoutSecondsRemaining--;
        } else {
          _locked = false;
          t.cancel();
        }
      });
    });
  }

  String _formatSeconds(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Step 1: Send OTP ──────────────────────────────────────────────────────

  Future<void> _onSendOtp() async {
    final contact = _contactController.text.trim();
    if (contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your contact number.')),
      );
      return;
    }

    setState(() => _sendingOtp = true);

    final result = await _otpService.sendOtp(widget.shop.id);

    if (!mounted) return;
    setState(() => _sendingOtp = false);

    if (result.success) {
      // Generic message — never reveal whether the number matched (Req 10.4)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If the number matches the registered contact, an OTP has been sent.',
          ),
        ),
      );
      setState(() {
        _step = 2;
        _attemptsRemaining = 3;
        _resendCount = 0;
        _locked = false;
        _otpController.clear();
      });
      _startCountdown();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Failed to send OTP.')),
      );
    }
  }

  // ── Step 2: Verify OTP ────────────────────────────────────────────────────

  Future<void> _onVerify() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit OTP.')),
      );
      return;
    }

    setState(() => _verifying = true);

    final result = await _otpService.verifyOtp(widget.shop.id, otp);

    if (!mounted) return;
    setState(() => _verifying = false);

    if (result.success && result.editToken != null) {
      // Persist the new edit token (Req 10.7, 10.12)
      await _storage.write(
        key: 'edit_token_${widget.shop.id}',
        value: result.editToken,
      );
      if (!mounted) return;
      _countdownTimer?.cancel();
      Navigator.of(context).pop(result.editToken);
    } else {
      switch (result.error) {
        case 'invalid_otp':
          final remaining =
              result.attemptsRemaining ?? (_attemptsRemaining - 1);
          setState(() => _attemptsRemaining = remaining);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Incorrect OTP. Attempts remaining: $remaining'),
            ),
          );

        case 'expired':
          _countdownTimer?.cancel();
          setState(() => _otpExpired = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP has expired. Please request a new one.'),
            ),
          );

        case 'locked':
          _countdownTimer?.cancel();
          final lockedUntil =
              result.lockedUntil ??
              DateTime.now().toUtc().add(const Duration(minutes: 30));
          _startLockoutTimer(lockedUntil);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Too many failed attempts. Your account is temporarily locked.',
              ),
            ),
          );

        default:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.error ?? 'Verification failed. Please try again.',
              ),
            ),
          );
      }
    }
  }

  // ── Resend OTP ────────────────────────────────────────────────────────────

  Future<void> _onResend() async {
    if (_resendCount >= _maxResends) return;

    setState(() => _sendingOtp = true);

    final result = await _otpService.sendOtp(widget.shop.id);

    if (!mounted) return;
    setState(() => _sendingOtp = false);

    if (result.success) {
      setState(() {
        _resendCount++;
        _attemptsRemaining = 3;
        _otpController.clear();
      });
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If the number matches the registered contact, an OTP has been sent.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Failed to resend OTP.')),
      );
    }
  }

  // ── Button style ──────────────────────────────────────────────────────────

  ButtonStyle get _copperButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: AppTheme.secondary, // Copper #B87333
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 52),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
  );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Claim This Shop')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
          child: _step == 1 ? _buildStep1() : _buildStep2(),
        ),
      ),
    );
  }

  // ── Step 1 UI ─────────────────────────────────────────────────────────────

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.shop.name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Enter the contact number registered with this shop to receive a one-time verification code.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 32),

        // Contact number field (Req 10.2)
        TextField(
          controller: _contactController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
            LengthLimitingTextInputFormatter(15),
          ],
          decoration: const InputDecoration(
            labelText: 'Contact Number',
            hintText: 'e.g. +639171234567',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 32),

        // Send OTP button (Req 10.3)
        ElevatedButton(
          style: _copperButtonStyle,
          onPressed: _sendingOtp ? null : _onSendOtp,
          child: _sendingOtp
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Send OTP'),
        ),
      ],
    );
  }

  // ── Step 2 UI ─────────────────────────────────────────────────────────────

  Widget _buildStep2() {
    final canResend = !_locked && _resendCount < _maxResends;
    final canVerify = !_locked && !_verifying && !_otpExpired;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter Verification Code',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'A 6-digit code was sent to the registered contact number.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),

        // Countdown timer (Req 10.5)
        _buildCountdownRow(),
        const SizedBox(height: 8),

        // Attempt counter (Req 10.8)
        if (!_locked)
          Text(
            'Attempts remaining: $_attemptsRemaining',
            style: TextStyle(
              color: _attemptsRemaining <= 1 ? Colors.red : AppTheme.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),

        // Lockout message (Req 10.9)
        if (_locked) _buildLockoutMessage(),

        const SizedBox(height: 24),

        // OTP input field (Req 10.5)
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          enabled: !_locked,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 12,
          ),
          decoration: const InputDecoration(
            labelText: 'OTP Code',
            hintText: '------',
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
        const SizedBox(height: 24),

        // Verify button (Req 10.6)
        ElevatedButton(
          style: _copperButtonStyle,
          onPressed: canVerify ? _onVerify : null,
          child: _verifying
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Verify'),
        ),
        const SizedBox(height: 16),

        // Resend OTP button (Req 10.10, 10.11)
        TextButton(
          onPressed: (canResend && (_otpExpired || true)) ? _onResend : null,
          child: Text(
            _resendCount >= _maxResends
                ? 'Resend limit reached'
                : 'Resend OTP (${_maxResends - _resendCount} remaining)',
            style: TextStyle(
              color: canResend ? AppTheme.secondary : AppTheme.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCountdownRow() {
    if (_otpExpired) {
      return Row(
        children: [
          const Icon(Icons.timer_off, size: 18, color: Colors.red),
          const SizedBox(width: 6),
          Text(
            'OTP expired',
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    final color = _secondsRemaining <= 60 ? Colors.red : AppTheme.primary;
    return Row(
      children: [
        Icon(Icons.timer_outlined, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          'Expires in ${_formatSeconds(_secondsRemaining)}',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildLockoutMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _lockoutSecondsRemaining > 0
                  ? 'Account locked. Try again in ${_formatSeconds(_lockoutSecondsRemaining)}.'
                  : 'Account locked. Please try again later.',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
