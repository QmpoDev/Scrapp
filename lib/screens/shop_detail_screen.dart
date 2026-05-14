import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/junkshop.dart';
import '../utils/app_animations.dart';
import '../utils/navigation_handler.dart';
import '../utils/schedule_parser.dart';

/// Full shop profile screen.
///
/// Hero receiver: the shop name in the [SliverAppBar] is wrapped in a [Hero]
/// with tag `shop_name_<id>`, matching the source tag in [JunkshopBottomSheet].
/// The [flightShuttleBuilder] on the source side handles the in-flight widget,
/// so the receiver just needs the matching tag.
///
/// Content entrance: each section (status row, info rows, buttons, materials,
/// prices) animates in with a staggered fade + slideY sequence, giving the
/// screen a choreographed "reveal" feel (Phase 2 — Staggered Animations).
class ShopDetailScreen extends StatelessWidget {
  final JunkshopModel shop;
  final double? distanceKm;

  const ShopDetailScreen({super.key, required this.shop, this.distanceKm});

  @override
  Widget build(BuildContext context) {
    final parsed = ScheduleParser.parse(shop.schedule);
    final bool? isOpenNow = parsed == null
        ? null
        : ScheduleParser.isOpen(parsed.open, parsed.close, TimeOfDay.now());

    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final appBarHeight = (screenHeight * 0.19).clamp(110.0, 160.0);
    final contentPadding = (screenWidth * 0.053).clamp(14.0, 24.0);

    final magneticItems = shop.prices
        .where((p) => _isFerrousMetal(p.material))
        .toList();
    final nonMagneticItems = shop.prices
        .where((p) => _isNonFerrousMetal(p.material))
        .toList();
    final otherItems = shop.prices
        .where(
          (p) =>
              !_isFerrousMetal(p.material) && !_isNonFerrousMetal(p.material),
        )
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── App bar — Hero receiver ───────────────────────────────────────
          SliverAppBar(
            expandedHeight: appBarHeight,
            pinned: true,
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              titlePadding: const EdgeInsets.fromLTRB(56, 0, 56, 14),
              // Hero tag matches the source in JunkshopBottomSheet.
              // The text style here is the "destination" state of the flight.
              title: Hero(
                tag: 'shop_name_${shop.id}',
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    shop.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF43A047), Color(0xFF2E7D32)],
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Image.asset(
                      'assets/images/logo/scrapp-s-logo.png',
                      width: 56,
                      height: 56,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      color: Colors.white.withValues(alpha: 0.85),
                      colorBlendMode: BlendMode.srcATop,
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(contentPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Status row ──────────────────────────────────────────
                  Row(
                        children: [
                          _StatusBadge(
                            label: shop.category,
                            color: const Color(0xFF2E7D32),
                          ),
                          if (isOpenNow != null) ...[
                            const SizedBox(width: 8),
                            _StatusBadge(
                              label: isOpenNow ? 'Open Now' : 'Closed',
                              color: isOpenNow
                                  ? const Color(0xFF2E7D32)
                                  : Colors.grey,
                            ),
                          ],
                        ],
                      )
                      .animate()
                      .fadeIn(duration: AppAnimations.standardSlow)
                      .slideY(
                        begin: 0.15,
                        end: 0,
                        duration: AppAnimations.emphasis,
                        curve: AppAnimations.easeOutCubic,
                      ),

                  const SizedBox(height: 20),

                  // ── Info rows — staggered ───────────────────────────────
                  ..._buildInfoRows(context, shop, distanceKm),

                  const SizedBox(height: 24),

                  // ── Action buttons ──────────────────────────────────────
                  Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              label: 'Directions',
                              icon: Icons.directions,
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              onTap: () => _onDirections(context),
                            ),
                          ),
                          if (shop.phone.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ActionButton(
                                label: 'Call',
                                icon: Icons.phone,
                                backgroundColor: Colors.transparent,
                                foregroundColor: const Color(0xFFB87333),
                                borderColor: const Color(0xFFB87333),
                                onTap: () => _callPhone(context, shop.phone),
                              ),
                            ),
                          ],
                        ],
                      )
                      .animate()
                      .fadeIn(
                        delay: const Duration(milliseconds: 200),
                        duration: AppAnimations.standardSlow,
                      )
                      .slideY(
                        begin: 0.15,
                        end: 0,
                        delay: const Duration(milliseconds: 200),
                        duration: AppAnimations.emphasis,
                        curve: AppAnimations.easeOutCubic,
                      ),

                  const SizedBox(height: 28),

                  // ── Accepted materials ──────────────────────────────────
                  if (shop.acceptedMaterials.isNotEmpty) ...[
                    const _SectionHeader(
                      title: 'Accepted Materials',
                    ).animate().fadeIn(
                      delay: const Duration(milliseconds: 280),
                      duration: AppAnimations.standardSlow,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: shop.acceptedMaterials
                          .asMap()
                          .entries
                          .map(
                            (e) => _MaterialChip(label: e.value)
                                .animate()
                                .fadeIn(
                                  delay: Duration(
                                    milliseconds: 320 + e.key * 30,
                                  ),
                                  duration: AppAnimations.standard,
                                )
                                .scale(
                                  begin: const Offset(0.8, 0.8),
                                  end: const Offset(1.0, 1.0),
                                  delay: Duration(
                                    milliseconds: 320 + e.key * 30,
                                  ),
                                  duration: AppAnimations.standardFade,
                                  curve: AppAnimations.easeOutBack,
                                ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // ── Price list ──────────────────────────────────────────
                  if (shop.prices.isNotEmpty) ...[
                    const _SectionHeader(title: 'Price List').animate().fadeIn(
                      delay: const Duration(milliseconds: 380),
                      duration: AppAnimations.standardSlow,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Prices may vary.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ).animate().fadeIn(
                      delay: const Duration(milliseconds: 400),
                      duration: AppAnimations.standardFade,
                    ),
                    const SizedBox(height: 12),
                    if (magneticItems.isNotEmpty) ...[
                      const _PriceCategoryHeader(
                        title: 'Magnetic Metals',
                      ).animate().fadeIn(
                        delay: const Duration(milliseconds: 420),
                        duration: AppAnimations.standardFade,
                      ),
                      ..._staggeredPriceRows(magneticItems, startDelay: 440),
                      const SizedBox(height: 12),
                    ],
                    if (nonMagneticItems.isNotEmpty) ...[
                      const _PriceCategoryHeader(
                        title: 'Non-Magnetic Metals',
                      ).animate().fadeIn(
                        delay: const Duration(milliseconds: 500),
                        duration: AppAnimations.standardFade,
                      ),
                      ..._staggeredPriceRows(nonMagneticItems, startDelay: 520),
                      const SizedBox(height: 12),
                    ],
                    if (otherItems.isNotEmpty) ...[
                      const _PriceCategoryHeader(
                        title: 'Other Materials',
                      ).animate().fadeIn(
                        delay: const Duration(milliseconds: 560),
                        duration: AppAnimations.standardFade,
                      ),
                      ..._staggeredPriceRows(otherItems, startDelay: 580),
                    ],
                    const SizedBox(height: 32),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds info rows with a staggered delay starting at 80 ms.
  List<Widget> _buildInfoRows(
    BuildContext context,
    JunkshopModel shop,
    double? distanceKm,
  ) {
    final rows = <(IconData, String, String, VoidCallback?, bool)>[];

    rows.add((
      Icons.location_on_outlined,
      'Address',
      shop.address.isNotEmpty ? shop.address : 'N/A',
      null,
      false,
    ));
    if (shop.municipality.isNotEmpty) {
      rows.add((
        Icons.map_outlined,
        'Municipality',
        shop.municipality,
        null,
        false,
      ));
    }
    if (distanceKm != null) {
      rows.add((
        Icons.near_me_outlined,
        'Distance',
        distanceKm < 1
            ? '${(distanceKm * 1000).toStringAsFixed(0)} m away'
            : '${distanceKm.toStringAsFixed(1)} km away',
        null,
        false,
      ));
    }
    if (shop.schedule.isNotEmpty) {
      rows.add((
        Icons.access_time_outlined,
        'Hours',
        shop.schedule,
        null,
        false,
      ));
    }
    if (shop.phone.isNotEmpty) {
      rows.add((
        Icons.phone_outlined,
        'Phone',
        shop.phone,
        () => _callPhone(context, shop.phone),
        true,
      ));
    }

    return rows.asMap().entries.expand((e) {
      final delay = Duration(milliseconds: 80 + e.key * 60);
      final (icon, label, value, onTap, isLink) = e.value;
      return [
        _InfoRow(
              icon: icon,
              label: label,
              value: value,
              onTap: onTap,
              isLink: isLink,
            )
            .animate()
            .fadeIn(delay: delay, duration: AppAnimations.standardSlow)
            .slideX(
              begin: -0.1,
              end: 0,
              delay: delay,
              duration: AppAnimations.standardSlow,
              curve: AppAnimations.easeOutCubic,
            ),
        const SizedBox(height: 10),
      ];
    }).toList();
  }

  /// Builds price rows with a staggered delay.
  List<Widget> _staggeredPriceRows(
    List<MaterialPrice> items, {
    required int startDelay,
  }) {
    return items.asMap().entries.map((e) {
      final delay = Duration(milliseconds: startDelay + e.key * 25);
      return _PriceRow(price: e.value)
          .animate()
          .fadeIn(delay: delay, duration: AppAnimations.standard)
          .slideX(
            begin: 0.08,
            end: 0,
            delay: delay,
            duration: AppAnimations.standardMid,
            curve: AppAnimations.easeOutCubic,
          );
    }).toList();
  }

  bool _isFerrousMetal(String material) {
    const ferrous = ['Scrap Iron', 'Tin Cans', 'Metal Roofing'];
    return ferrous.any((f) => material.toLowerCase().contains(f.toLowerCase()));
  }

  bool _isNonFerrousMetal(String material) {
    const nonFerrous = ['Aluminum', 'Copper', 'Brass', 'Stainless Steel'];
    return nonFerrous.any(
      (f) => material.toLowerCase().contains(f.toLowerCase()),
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

  Future<void> _callPhone(BuildContext context, String phone) async {
    final uri = Uri.parse('tel:${phone.replaceAll('-', '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot make calls on this device.')),
      );
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppAnimations.standardFade,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
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
        scale: _pressed ? 0.95 : 1.0,
        duration: AppAnimations.micro,
        child: AnimatedContainer(
          duration: AppAnimations.microMedium,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: _pressed
                ? widget.backgroundColor.withValues(alpha: 0.85)
                : widget.backgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: widget.borderColor != null
                ? Border.all(color: widget.borderColor!, width: 1.5)
                : null,
            boxShadow: widget.backgroundColor != Colors.transparent
                ? [
                    BoxShadow(
                      color: widget.backgroundColor.withValues(
                        alpha: _pressed ? 0.15 : 0.3,
                      ),
                      blurRadius: _pressed ? 4 : 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 18, color: widget.foregroundColor),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: widget.foregroundColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool isLink;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.isLink = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF9E9E9E)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9E9E9E),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: isLink
                        ? const Color(0xFFB87333)
                        : const Color(0xFF1A1A1B),
                    fontWeight: FontWeight.w500,
                    decoration: isLink
                        ? TextDecoration.underline
                        : TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1A1A1B),
      ),
    );
  }
}

class _PriceCategoryHeader extends StatelessWidget {
  final String title;
  const _PriceCategoryHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFFB87333),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final MaterialPrice price;
  const _PriceRow({required this.price});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              price.material,
              style: const TextStyle(fontSize: 13, color: Color(0xFF444444)),
            ),
          ),
          Text(
            price.displayPrice,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1B),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialChip extends StatelessWidget {
  final String label;
  const _MaterialChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0EB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0C9A6)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF7A4F1E),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
