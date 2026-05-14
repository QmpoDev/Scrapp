import 'dart:ui';
import 'package:flutter/material.dart';

import '../utils/app_animations.dart';

/// Industrial Glass surface — frosted blur with a 1px Steel border.
///
/// [opacity] controls the white fill intensity.
/// [blurSigma] is animated implicitly — changing it triggers a smooth
/// transition of the backdrop blur, creating a "focus" effect when a shop
/// is selected on the map.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final double blurSigma;

  /// Duration for the implicit blur animation. Defaults to 300 ms.
  final Duration animationDuration;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 14,
    this.opacity = 0.88,
    this.padding,
    this.blurSigma = 12,
    this.animationDuration = AppAnimations.standardSlow,
  });

  @override
  Widget build(BuildContext context) {
    return _AnimatedGlassContainer(
      borderRadius: borderRadius,
      opacity: opacity,
      padding: padding,
      blurSigma: blurSigma,
      animationDuration: animationDuration,
      child: child,
    );
  }
}

/// Stateful wrapper that drives the implicit blur-sigma animation.
/// When [blurSigma] changes on the parent, TweenAnimationBuilder smoothly
/// interpolates the BackdropFilter sigma — no AnimationController needed.
class _AnimatedGlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final double blurSigma;
  final Duration animationDuration;

  const _AnimatedGlassContainer({
    required this.child,
    required this.borderRadius,
    required this.opacity,
    required this.padding,
    required this.blurSigma,
    required this.animationDuration,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: blurSigma, end: blurSigma),
      duration: animationDuration,
      curve: AppAnimations.easeInOutCubic,
      builder: (context, sigma, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: AnimatedContainer(
              duration: animationDuration,
              curve: AppAnimations.easeInOutCubic,
              padding: padding,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: opacity),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: const Color(0xFF4E5963).withValues(alpha: 0.18),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
