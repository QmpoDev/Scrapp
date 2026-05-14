import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/junkshop.dart';
import '../screens/shop_detail_screen.dart';
import '../utils/app_animations.dart';
import '../utils/navigation_handler.dart';
import '../utils/schedule_parser.dart';
import 'glass_container.dart';
import 'pending_status_badge.dart';

/// Quick-glance bottom sheet — polished industrial glass surface.
///
/// Hero tag: each shop's [JunkshopModel.id] is used as the Hero tag for the
/// shop name text, enabling a shared-element transition to [ShopDetailScreen].
/// Using the ID (not the name) guarantees uniqueness and avoids Hero conflicts
/// when multiple sheets could theoretically be in the tree simultaneously.
class JunkshopBottomSheet extends StatelessWidget {
  final JunkshopModel shop;
  final double? distanceKm;
  final bool hasEditToken;
  final VoidCallback? onEdit;
  final VoidCallback? onClaim;

  const JunkshopBottomSheet({
    super.key,
    required this.shop,
    this.distanceKm,
    this.hasEditToken = false,
    this.onEdit,
    this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final parsed = ScheduleParser.parse(shop.schedule);
    final bool? isOpenNow = parsed == null
        ? null
        : ScheduleParser.isOpen(parsed.open, parsed.close, TimeOfDay.now());
    final previewMaterials = shop.acceptedMaterials.take(4).toList();

    final screenWidth = MediaQuery.sizeOf(context).width;
    final hPad = (screenWidth * 0.053).clamp(14.0, 24.0);
    final titleSize = (screenWidth * 0.052).clamp(16.0, 22.0);

    return GlassContainer(
          borderRadius: 24,
          opacity: 0.97,
          // Slightly higher blur when the sheet is open — creates a "focus" effect
          // on the map behind it (Phase 2 — Glassmorphism Polish).
          blurSigma: 16,
          animationDuration: AppAnimations.emphasis,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Grab handle ──────────────────────────────────────────────
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4E5963).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // ── Name — Hero source ───────────────────────────────────────
                  // The Hero tag is the shop ID. The flightShuttleBuilder renders
                  // the text in a Material widget during the flight so it stays
                  // legible against any background colour.
                  Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Hero(
                              tag: 'shop_name_${shop.id}',
                              flightShuttleBuilder:
                                  (
                                    flightContext,
                                    animation,
                                    direction,
                                    fromContext,
                                    toContext,
                                  ) {
                                    // Fade + scale the text during the Hero flight.
                                    return AnimatedBuilder(
                                      animation: animation,
                                      builder: (_, __) {
                                        final t =
                                            direction ==
                                                HeroFlightDirection.push
                                            ? animation.value
                                            : 1 - animation.value;
                                        return Material(
                                          color: Colors.transparent,
                                          child: Opacity(
                                            opacity: (t * 2).clamp(0.0, 1.0),
                                            child: Text(
                                              shop.name,
                                              style: TextStyle(
                                                fontSize:
                                                    titleSize +
                                                    (20 - titleSize) * t,
                                                fontWeight: FontWeight.w800,
                                                color: Color.lerp(
                                                  const Color(0xFF1A1A1B),
                                                  Colors.white,
                                                  t,
                                                ),
                                                letterSpacing: -0.3,
                                                height: 1.2,
                                                decoration: TextDecoration.none,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                              child: Text(
                                shop.name,
                                style: TextStyle(
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1A1A1B),
                                  letterSpacing: -0.3,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                      .animate()
                      .fadeIn(duration: AppAnimations.standardFade)
                      .slideY(
                        begin: 0.15,
                        end: 0,
                        duration: AppAnimations.standardSlow,
                        curve: AppAnimations.easeOutCubic,
                      ),

                  if (shop.status == ShopStatus.pending) ...[
                    const SizedBox(height: 6),
                    const PendingStatusBadge(),
                  ],

                  const SizedBox(height: 8),

                  // ── Meta pills ───────────────────────────────────────────────
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      _MetaPill(
                        icon: Icons.category_outlined,
                        label: shop.category,
                        color: const Color(0xFFA0A0A2),
                      ),
                      if (isOpenNow != null)
                        _MetaPill(
                          icon: isOpenNow
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                          label: isOpenNow ? 'Open Now' : 'Closed',
                          color: isOpenNow
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFA0A0A2),
                        ),
                      if (distanceKm != null)
                        _MetaPill(
                          icon: Icons.near_me_outlined,
                          label: distanceKm! < 1
                              ? '${(distanceKm! * 1000).toStringAsFixed(0)} m'
                              : '${distanceKm!.toStringAsFixed(1)} km',
                          color: const Color(0xFF2E7D32),
                        ),
                    ],
                  ).animate().fadeIn(
                    delay: const Duration(milliseconds: 60),
                    duration: AppAnimations.standardFade,
                  ),

                  // ── Address ──────────────────────────────────────────────────
                  if (shop.address.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: Color(0xFFA0A0A2),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            shop.address,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFA0A0A2),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(
                      delay: const Duration(milliseconds: 100),
                      duration: AppAnimations.standardFade,
                    ),
                  ],

                  // ── Materials preview — staggered chips ──────────────────────
                  // Each chip animates in sequentially: position → opacity.
                  // This is the Phase 2 staggered list animation applied to chips.
                  if (previewMaterials.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'ACCEPTS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFA0A0A2),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...previewMaterials.asMap().entries.map(
                          (e) => _MaterialChip(label: e.value)
                              .animate()
                              .fadeIn(
                                delay: Duration(milliseconds: 120 + e.key * 50),
                                duration: AppAnimations.standardMid,
                              )
                              .slideX(
                                begin: 0.25,
                                end: 0,
                                delay: Duration(milliseconds: 120 + e.key * 50),
                                duration: AppAnimations.standardFade,
                                curve: AppAnimations.easeOutCubic,
                              )
                              .scale(
                                begin: const Offset(0.85, 0.85),
                                end: const Offset(1.0, 1.0),
                                delay: Duration(milliseconds: 120 + e.key * 50),
                                duration: AppAnimations.standardFade,
                                curve: AppAnimations.easeOutBack,
                              ),
                        ),
                        if (shop.acceptedMaterials.length > 4)
                          _MaterialChip(
                            label: '+${shop.acceptedMaterials.length - 4} more',
                            muted: true,
                          ).animate().fadeIn(
                            delay: const Duration(milliseconds: 320),
                            duration: AppAnimations.standard,
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 18),

                  // ── Action buttons ───────────────────────────────────────────
                  Row(
                        children: [
                          Expanded(
                            child: _GradientButton(
                              label: 'Navigate',
                              icon: Icons.directions,
                              onTap: () => _onDirections(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _OutlineButton(
                              label: 'View Details',
                              icon: Icons.info_outline,
                              onTap: () => _openDetail(context),
                            ),
                          ),
                        ],
                      )
                      .animate()
                      .fadeIn(
                        delay: const Duration(milliseconds: 180),
                        duration: AppAnimations.standardSlow,
                      )
                      .slideY(
                        begin: 0.2,
                        end: 0,
                        delay: const Duration(milliseconds: 180),
                        duration: AppAnimations.standardSlow,
                        curve: AppAnimations.easeOutCubic,
                      ),

                  if (hasEditToken || onClaim != null) ...[
                    const SizedBox(height: 8),
                    if (hasEditToken)
                      SizedBox(
                        width: double.infinity,
                        child: _OutlineButton(
                          label: 'Edit Listing',
                          icon: Icons.edit_outlined,
                          onTap: onEdit ?? () {},
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          icon: const Icon(
                            Icons.lock_open_outlined,
                            size: 16,
                            color: Color(0xFFB87333),
                          ),
                          label: const Text(
                            'Claim This Shop',
                            style: TextStyle(
                              color: Color(0xFFB87333),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: onClaim,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: AppAnimations.standardSlow)
        .slideY(
          begin: 0.08,
          end: 0,
          duration: AppAnimations.standardSlow,
          curve: AppAnimations.easeOutCubic,
        );
  }

  Future<void> _onDirections(BuildContext context) async {
    final launched = await NavigationHandler.launch(shop.lat, shop.lng);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No navigation app found on this device.'),
        ),
      );
    }
  }

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        // Use a custom page route so the Hero animation plays correctly
        // alongside a fade transition (plain MaterialPageRoute also works).
        pageBuilder: (_, __, ___) =>
            ShopDetailScreen(shop: shop, distanceKm: distanceKm),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: AppAnimations.easeInOutCubic,
          ),
          child: child,
        ),
        transitionDuration: AppAnimations.emphasis,
      ),
    );
  }
}

// ── Gradient Navigate Button ──────────────────────────────────────────────────

class _GradientButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
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
        scale: _pressed ? 0.94 : 1.0,
        duration: AppAnimations.micro,
        child: AnimatedContainer(
          duration: AppAnimations.microMedium,
          padding: const EdgeInsets.symmetric(vertical: 13),
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
                blurRadius: _pressed ? 4 : 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 17, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Outline Button ────────────────────────────────────────────────────────────

class _OutlineButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_OutlineButton> createState() => _OutlineButtonState();
}

class _OutlineButtonState extends State<_OutlineButton> {
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
        scale: _pressed ? 0.94 : 1.0,
        duration: AppAnimations.micro,
        child: AnimatedContainer(
          duration: AppAnimations.microMedium,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: _pressed
                ? const Color(0xFFB87333).withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFB87333), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 17, color: const Color(0xFFB87333)),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Color(0xFFB87333),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Meta Pill ─────────────────────────────────────────────────────────────────

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Material Chip ─────────────────────────────────────────────────────────────

class _MaterialChip extends StatelessWidget {
  final String label;
  final bool muted;

  const _MaterialChip({required this.label, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: muted ? const Color(0xFFF5F5F5) : const Color(0xFFF5F0EB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: muted
              ? const Color(0xFF4E5963).withValues(alpha: 0.15)
              : const Color(0xFFE0C9A6),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: muted ? const Color(0xFFA0A0A2) : const Color(0xFF7A4F1E),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
