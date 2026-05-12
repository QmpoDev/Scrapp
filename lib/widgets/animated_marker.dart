import 'package:flutter/material.dart';

/// A map marker with press-scale micro-interaction and an optional name label.
///
/// [showLabel] controls whether the shop name pill is visible.
/// Labels are shown only at higher zoom levels to avoid clutter.
class AnimatedMarker extends StatefulWidget {
  final VoidCallback onTap;
  final String? label;
  final bool showLabel;

  const AnimatedMarker({
    super.key,
    required this.onTap,
    this.label,
    this.showLabel = false,
  });

  @override
  State<AnimatedMarker> createState() => _AnimatedMarkerState();
}

class _AnimatedMarkerState extends State<AnimatedMarker> {
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
      child: RepaintBoundary(
        child: AnimatedScale(
          scale: _pressed ? 0.82 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Label pill — shown only when zoomed in enough
              if (widget.showLabel && widget.label != null)
                _MarkerLabel(label: widget.label!),
              _MarkerIcon(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Frosted pill label shown above the pin at high zoom levels.
class _MarkerLabel extends StatelessWidget {
  final String label;
  const _MarkerLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    // Truncate long names to keep the pill compact on screen.
    final display = label.length > 18 ? '${label.substring(0, 16)}…' : label;

    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFB87333).withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        display,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A1B),
          letterSpacing: 0.1,
          height: 1.2,
        ),
        maxLines: 1,
      ),
    );
  }
}

class _MarkerIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.location_pin, color: Color(0xFFB87333), size: 36);
  }
}

/// Animated user-location dot with a pulsing ring.
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
      duration: const Duration(milliseconds: 1600),
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
          // Pulsing ring
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
          // Inner dot
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
