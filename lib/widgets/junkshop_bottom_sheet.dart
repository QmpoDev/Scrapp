import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/junkshop.dart';
import '../screens/shop_detail_screen.dart';
import '../utils/navigation_handler.dart';
import '../utils/schedule_parser.dart';
import 'glass_container.dart';

/// Quick-glance bottom sheet — polished industrial glass surface.
class JunkshopBottomSheet extends StatelessWidget {
  final JunkshopModel shop;
  final double? distanceKm;

  const JunkshopBottomSheet({super.key, required this.shop, this.distanceKm});

  @override
  Widget build(BuildContext context) {
    final parsed = ScheduleParser.parse(shop.schedule);
    final bool? isOpenNow = parsed == null
        ? null
        : ScheduleParser.isOpen(parsed.open, parsed.close, TimeOfDay.now());
    final previewMaterials = shop.acceptedMaterials.take(4).toList();

    final screenWidth = MediaQuery.sizeOf(context).width;
    // Responsive padding/font — clamp keeps it readable on 320px and 600px screens.
    final hPad = (screenWidth * 0.053).clamp(14.0, 24.0);
    final titleSize = (screenWidth * 0.052).clamp(16.0, 22.0);

    return GlassContainer(
      borderRadius: 24,
      opacity: 0.97,
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

              // ── Name ────────────────────────────────────────────────────
              Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
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
                    ],
                  )
                  .animate()
                  .fadeIn(duration: const Duration(milliseconds: 250))
                  .slideY(
                    begin: 0.15,
                    end: 0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  ),

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
                duration: const Duration(milliseconds: 250),
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
                  duration: const Duration(milliseconds: 250),
                ),
              ],

              // ── Materials preview ────────────────────────────────────────
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
                            delay: Duration(milliseconds: 120 + e.key * 40),
                            duration: const Duration(milliseconds: 200),
                          )
                          .slideX(
                            begin: 0.2,
                            end: 0,
                            delay: Duration(milliseconds: 120 + e.key * 40),
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                          ),
                    ),
                    if (shop.acceptedMaterials.length > 4)
                      _MaterialChip(
                        label: '+${shop.acceptedMaterials.length - 4} more',
                        muted: true,
                      ).animate().fadeIn(
                        delay: const Duration(milliseconds: 280),
                        duration: const Duration(milliseconds: 200),
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
                    delay: const Duration(milliseconds: 150),
                    duration: const Duration(milliseconds: 300),
                  )
                  .slideY(
                    begin: 0.2,
                    end: 0,
                    delay: const Duration(milliseconds: 150),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  ),
            ],
          ),
        ),
      ),
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
      MaterialPageRoute(
        builder: (_) => ShopDetailScreen(shop: shop, distanceKm: distanceKm),
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
        duration: const Duration(milliseconds: 100),
        child: Container(
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
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
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
