import 'package:flutter/material.dart';

import '../models/junkshop.dart';
import '../utils/app_animations.dart';

/// A map marker with press-scale micro-interaction and an optional name label.
///
/// Tap behaviour (Phase 1 — Marker Scaling):
///   • onTapDown  → scale to 1.2x with a spring curve (feels "alive")
///   • onTapUp    → spring back to 1.0x, then fires [onTap]
///   • onTapCancel → spring back to 1.0x without firing [onTap]
///
/// [showLabel] controls whether the shop name pill is visible.
/// Labels are shown only at higher zoom levels to avoid clutter.
///
/// [isSelected] highlights the pin in the primary green when the
/// corresponding bottom sheet is open, giving clear spatial feedback.
class AnimatedMarker extends StatefulWidget {
  final VoidCallback onTap;
  final String? label;
  final bool showLabel;
  final bool isSelected;
  final ShopStatus? status;

  const AnimatedMarker({
    super.key,
    required this.onTap,
    this.label,
    this.showLabel = false,
    this.isSelected = false,
    this.status,
  });

  @override
  State<AnimatedMarker> createState() => _AnimatedMarkerState();
}

class _AnimatedMarkerState extends State<AnimatedMarker>
    with SingleTickerProviderStateMixin {
  // Explicit AnimationController gives us full spring control.
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnim;

  // Track whether the finger is currently down so we can spring back on cancel.
  bool _isDown = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      // Duration for the press-down phase; spring-back uses reverseDuration.
      duration: AppAnimations.markerPress,
      reverseDuration: AppAnimations.markerRelease,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _scaleController,
        // easeOutBack gives the slight overshoot that makes it feel "springy".
        curve: AppAnimations.easeOutBack,
        reverseCurve: AppAnimations.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _isDown = true;
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _isDown = false;
    // Spring back first, then fire the callback so the animation is visible.
    _scaleController.reverse().then((_) {
      if (mounted) widget.onTap();
    });
  }

  void _onTapCancel() {
    if (!_isDown) return;
    _isDown = false;
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _scaleAnim,
          builder: (context, child) =>
              Transform.scale(scale: _scaleAnim.value, child: child),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Label pill — shown only when zoomed in enough.
              if (widget.showLabel && widget.label != null)
                _MarkerLabel(
                  label: widget.label!,
                  isSelected: widget.isSelected,
                ),
              _MarkerIcon(isSelected: widget.isSelected, status: widget.status),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Label pill ────────────────────────────────────────────────────────────────

/// Frosted pill label shown above the pin at high zoom levels.
/// Uses [AnimatedContainer] + [AnimatedDefaultTextStyle] for implicit
/// colour transitions when [isSelected] changes.
class _MarkerLabel extends StatelessWidget {
  final String label;
  final bool isSelected;

  const _MarkerLabel({required this.label, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final display = label.length > 18 ? '${label.substring(0, 16)}…' : label;

    return AnimatedContainer(
      duration: AppAnimations.standardFade,
      curve: AppAnimations.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        // Selected: copper tint; default: frosted white.
        color: isSelected
            ? const Color(0xFFB87333).withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFB87333).withValues(alpha: 0.7)
              : const Color(0xFFB87333).withValues(alpha: 0.35),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isSelected ? 0.2 : 0.14),
            blurRadius: isSelected ? 10 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AnimatedDefaultTextStyle(
        duration: AppAnimations.standardFade,
        curve: AppAnimations.easeOutCubic,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
          color: isSelected ? const Color(0xFFB87333) : const Color(0xFF1A1A1B),
          letterSpacing: 0.1,
          height: 1.2,
        ),
        child: Text(display, maxLines: 1),
      ),
    );
  }
}

// ── Pin icon ──────────────────────────────────────────────────────────────────

/// The copper location pin. Uses [AnimatedScale] + [AnimatedOpacity] to
/// subtly pulse when [isSelected] is true, drawing the eye to the active shop.
class _MarkerIcon extends StatelessWidget {
  final bool isSelected;
  final ShopStatus? status;
  const _MarkerIcon({required this.isSelected, this.status});

  Color get _pinColor {
    if (isSelected) return const Color(0xFF2E7D32); // selected = green
    if (status == ShopStatus.pending) return const Color(0xFFFFA000); // amber
    return const Color(0xFFB87333); // copper (verified or null)
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isSelected ? 1.15 : 1.0,
      duration: AppAnimations.standardSlow,
      curve: AppAnimations.elasticOut,
      child: Icon(
        Icons.location_pin,
        color: _pinColor,
        size: 36,
        shadows: isSelected
            ? [
                Shadow(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.45),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
    );
  }
}

// ── User location dot ─────────────────────────────────────────────────────────

/// Animated user-location dot with a pulsing ring.
/// Uses an explicit [AnimationController] with [.repeat()] for the loop —
/// this is the correct pattern for indefinite animations (Phase 3).
class UserLocationMarker extends StatefulWidget {
  const UserLocationMarker({super.key});

  @override
  State<UserLocationMarker> createState() => _UserLocationMarkerState();
}

class _UserLocationMarkerState extends State<UserLocationMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: AppAnimations.pulse,
    )..repeat();

    _pulseScale = Tween<double>(
      begin: 0.6,
      end: 1.4,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
    _pulseOpacity = Tween<double>(
      begin: 0.5,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing ring — driven by explicit AnimationController.
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) => Transform.scale(
              scale: _pulseScale.value,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withValues(
                    alpha: _pulseOpacity.value * 0.3,
                  ),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: _pulseOpacity.value),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          // Inner dot — intentionally a sibling of AnimatedBuilder (not nested
          // inside it) so it is never rebuilt by the pulse animation loop.
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.shade600,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.4),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
