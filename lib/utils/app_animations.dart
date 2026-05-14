import 'package:flutter/animation.dart';

/// Centralised animation constants for the Scrapp app.
///
/// All animation durations and curves are defined here so that the motion
/// feel of the entire app can be adjusted by editing a single file.
abstract final class AppAnimations {
  AppAnimations._();

  // ── Durations ──────────────────────────────────────────────────────────────

  /// Micro: icon swap, press feedback (≤ 150 ms)
  static const Duration micro = Duration(milliseconds: 100);
  static const Duration microMedium = Duration(milliseconds: 150);

  /// Standard: chip colour, search border, button press (200–300 ms)
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration standardMid = Duration(milliseconds: 220);
  static const Duration standardSlow = Duration(milliseconds: 300);
  static const Duration standardFade = Duration(milliseconds: 250);

  /// Emphasis: page transitions, blur focus, entrance slides (350–500 ms)
  static const Duration emphasis = Duration(milliseconds: 350);
  static const Duration emphasisSlow = Duration(milliseconds: 400);
  static const Duration emphasisMax = Duration(milliseconds: 450);
  static const Duration emphasisFull = Duration(milliseconds: 500);

  /// Loop: repeating animations (1 000–10 000 ms)
  static const Duration pulse = Duration(milliseconds: 1600);

  /// Marker-specific durations
  static const Duration markerPress = Duration(milliseconds: 120);
  static const Duration markerRelease = Duration(milliseconds: 300);
  static const Duration markerEntrance = Duration(milliseconds: 350);
  static const Duration markerEntranceFade = Duration(milliseconds: 200);
  static const Duration markerStaggerStep = Duration(milliseconds: 60);

  /// Chip-specific durations
  static const Duration chipMicro = Duration(milliseconds: 180);

  // ── Curves ─────────────────────────────────────────────────────────────────

  static const Curve easeOutCubic = Cubic(0.215, 0.61, 0.355, 1.0);
  static const Curve elasticOut = ElasticOutCurve(0.5);
  static const Curve easeOutBack = Cubic(0.34, 1.56, 0.64, 1.0);
  static const Curve easeInOutCubic = Cubic(0.645, 0.045, 0.355, 1.0);
}
