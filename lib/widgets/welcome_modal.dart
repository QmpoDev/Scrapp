import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_animations.dart';

const String _kDontShowKey = 'scrapp_welcome_shown';

Future<void> showWelcomeModalIfNeeded(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_kDontShowKey) ?? false) return;
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _WelcomeDialog(),
  );
}

class _WelcomeDialog extends StatefulWidget {
  const _WelcomeDialog();

  @override
  State<_WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<_WelcomeDialog> {
  bool _dontShowAgain = false;
  bool _dismissing = false;

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    if (_dontShowAgain) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kDontShowKey, true);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final logoSize = (screenWidth * 0.28).clamp(64.0, 110.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: (screenWidth * 0.06).clamp(16.0, 32.0),
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            (screenWidth * 0.065).clamp(16.0, 28.0),
            28,
            (screenWidth * 0.065).clamp(16.0, 28.0),
            20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Lottie hero animation ─────────────────────────────────────
              // Lottie replaces the static logo for a "living" first impression.
              // Falls back gracefully to the PNG logo if the JSON fails to load.
              SizedBox(
                    width: logoSize,
                    height: logoSize,
                    child: Lottie.asset(
                      'assets/lottie/welcome_recycle.json',
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.contain,
                      repeat: true,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/logo/scrapp-s-logo.png',
                        width: logoSize,
                        height: logoSize,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  )
                  .animate()
                  .scale(
                    begin: const Offset(0.6, 0.6),
                    end: const Offset(1.0, 1.0),
                    duration: AppAnimations.emphasisFull,
                    curve: AppAnimations.elasticOut,
                  )
                  .fadeIn(duration: AppAnimations.standardSlow),

              const SizedBox(height: 20),

              // ── Title ─────────────────────────────────────────────────────
              const Text(
                    'Welcome to Scrapp!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1B),
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  )
                  .animate()
                  .fadeIn(
                    delay: const Duration(milliseconds: 150),
                    duration: AppAnimations.emphasis,
                  )
                  .slideY(
                    begin: 0.2,
                    end: 0,
                    delay: const Duration(milliseconds: 150),
                    duration: AppAnimations.emphasis,
                    curve: AppAnimations.easeOutCubic,
                  ),

              const SizedBox(height: 10),

              const Text(
                'Your go-to directory for junkshops in La Union, Philippines.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF757575),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(
                delay: const Duration(milliseconds: 220),
                duration: AppAnimations.standardSlow,
              ),

              const SizedBox(height: 20),

              // ── Feature rows — staggered entrance ────────────────────────
              // Each row slides in from the left with an increasing delay,
              // creating a choreographed "reveal" sequence (Phase 1 stagger).
              ..._features.asMap().entries.map((e) {
                final delay = Duration(milliseconds: 300 + e.key * 80);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FeatureRow(icon: e.value.$1, text: e.value.$2)
                      .animate()
                      .fadeIn(
                        delay: delay,
                        duration: AppAnimations.standardSlow,
                      )
                      .slideX(
                        begin: -0.25,
                        end: 0,
                        delay: delay,
                        duration: AppAnimations.emphasis,
                        curve: AppAnimations.easeOutCubic,
                      ),
                );
              }),

              const SizedBox(height: 24),

              // ── CTA button ────────────────────────────────────────────────
              SizedBox(
                    width: double.infinity,
                    child: _AnimatedCTAButton(onTap: _dismiss),
                  )
                  .animate()
                  .fadeIn(
                    delay: const Duration(milliseconds: 620),
                    duration: AppAnimations.emphasis,
                  )
                  .slideY(
                    begin: 0.3,
                    end: 0,
                    delay: const Duration(milliseconds: 620),
                    duration: AppAnimations.emphasisSlow,
                    curve: AppAnimations.easeOutCubic,
                  ),

              const SizedBox(height: 12),

              // ── Don't show again ──────────────────────────────────────────
              GestureDetector(
                onTap: () => setState(() => _dontShowAgain = !_dontShowAgain),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _dontShowAgain,
                        onChanged: (v) =>
                            setState(() => _dontShowAgain = v ?? false),
                        activeColor: const Color(0xFF2E7D32),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Don't show this again",
                      style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
                    ),
                  ],
                ),
              ).animate().fadeIn(
                delay: const Duration(milliseconds: 700),
                duration: AppAnimations.standardSlow,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Feature data — (icon, text) tuples.
const _features = [
  (Icons.map_outlined, 'Browse junkshops on an interactive map'),
  (Icons.search, 'Search by name or filter by municipality'),
  (Icons.directions_outlined, 'Get directions straight to any shop'),
  (Icons.my_location, 'See your location on the map'),
];

// ── Animated CTA Button ───────────────────────────────────────────────────────

/// Press-scale + gradient CTA button. Uses [AnimatedScale] (implicit widget)
/// for the press feedback — no AnimationController needed.
class _AnimatedCTAButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedCTAButton({required this.onTap});

  @override
  State<_AnimatedCTAButton> createState() => _AnimatedCTAButtonState();
}

class _AnimatedCTAButtonState extends State<_AnimatedCTAButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: AppAnimations.micro,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: AppAnimations.microMedium,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _pressed
                  ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                  : [const Color(0xFF43A047), const Color(0xFF2E7D32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF2E7D32,
                ).withValues(alpha: _pressed ? 0.2 : 0.4),
                blurRadius: _pressed ? 4 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'Get Started',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Feature Row ───────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 17, color: const Color(0xFF2E7D32)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF444444),
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
