import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/junkshop.dart';
import '../utils/navigation_handler.dart';
import '../utils/schedule_parser.dart';

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

    // Group prices by ferrous / non-ferrous / other for the price list sections.
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
          // ── App bar ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: appBarHeight,
            pinned: true,
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              titlePadding: const EdgeInsets.fromLTRB(56, 0, 56, 14),
              title: Text(
                shop.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          shop.category,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                      if (isOpenNow != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isOpenNow
                                ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isOpenNow ? 'Open Now' : 'Closed',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isOpenNow
                                  ? const Color(0xFF2E7D32)
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Info rows ───────────────────────────────────────────
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Address',
                    value: shop.address.isNotEmpty ? shop.address : 'N/A',
                  ),
                  if (shop.municipality.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.map_outlined,
                      label: 'Municipality',
                      value: shop.municipality,
                    ),
                  ],
                  if (distanceKm != null) ...[
                    const SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.near_me_outlined,
                      label: 'Distance',
                      value: distanceKm! < 1
                          ? '${(distanceKm! * 1000).toStringAsFixed(0)} m away'
                          : '${distanceKm!.toStringAsFixed(1)} km away',
                    ),
                  ],
                  if (shop.schedule.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.access_time_outlined,
                      label: 'Hours',
                      value: shop.schedule,
                    ),
                  ],
                  if (shop.phone.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: shop.phone,
                      onTap: () => _callPhone(context, shop.phone),
                      isLink: true,
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Action buttons ──────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _onDirections(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.directions, size: 18),
                          label: const Text(
                            'Directions',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      if (shop.phone.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _callPhone(context, shop.phone),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFB87333),
                              side: const BorderSide(
                                color: Color(0xFFB87333),
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.phone, size: 18),
                            label: const Text(
                              'Call',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── Accepted materials ──────────────────────────────────
                  if (shop.acceptedMaterials.isNotEmpty) ...[
                    _SectionHeader(title: 'Accepted Materials'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: shop.acceptedMaterials
                          .map((m) => _MaterialChip(label: m))
                          .toList(),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // ── Price list ──────────────────────────────────────────
                  if (shop.prices.isNotEmpty) ...[
                    _SectionHeader(title: 'Price List'),
                    const SizedBox(height: 4),
                    Text(
                      'Prices may vary.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (magneticItems.isNotEmpty) ...[
                      _PriceCategoryHeader(title: 'Magnetic Metals'),
                      ...magneticItems.map((p) => _PriceRow(price: p)),
                      const SizedBox(height: 12),
                    ],
                    if (nonMagneticItems.isNotEmpty) ...[
                      _PriceCategoryHeader(title: 'Non-Magnetic Metals'),
                      ...nonMagneticItems.map((p) => _PriceRow(price: p)),
                      const SizedBox(height: 12),
                    ],
                    if (otherItems.isNotEmpty) ...[
                      _PriceCategoryHeader(title: 'Other Materials'),
                      ...otherItems.map((p) => _PriceRow(price: p)),
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

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

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
