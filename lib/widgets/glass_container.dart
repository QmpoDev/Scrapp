import 'dart:ui';
import 'package:flutter/material.dart';

/// Industrial Glass surface — frosted blur with a 1px Steel border.
/// Use [opacity] to control the white fill intensity.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final double blurSigma;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 14,
    this.opacity = 0.88,
    this.padding,
    this.blurSigma = 12,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: const Color(0xFF4E5963).withValues(alpha: 0.18), // Steel
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
  }
}
