import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/shop_provider.dart';

/// Filter by a single material's price range. Bounds come from
/// [pricingBoundsProvider] so they always reflect scrap_standard_pricing.json.
class PriceFilterSheet extends ConsumerStatefulWidget {
  const PriceFilterSheet({super.key});

  @override
  ConsumerState<PriceFilterSheet> createState() => _PriceFilterSheetState();
}

class _PriceFilterSheetState extends ConsumerState<PriceFilterSheet> {
  String? _selectedMaterial;
  RangeValues? _range;

  static const Map<String, List<String>> _categories = {
    'Ferrous Metals': ['Steel', 'Tin Cans', 'Metal Roofing'],
    'Non-Ferrous Metals': ['Aluminum', 'Copper', 'Brass', 'Stainless Steel'],
    'Recyclables': ['Plastics', 'Paper', 'Cardboard'],
    'Glass': [
      'Glass Bottles (2x2 Gin)',
      'Glass Bottles (Longneck Emperador)',
      'Glass Bottles (Ketchup)',
    ],
    'Electronics': ['Motherboard', 'IC', 'TV Board'],
  };

  @override
  void initState() {
    super.initState();
    final state = ref.read(shopProvider);
    _selectedMaterial = state.priceFilterMaterial;
    _range = state.priceFilterRange;
  }

  void _selectMaterial(
    String material,
    Map<String, ({double min, double max, String unit})> bounds,
  ) {
    final b = bounds[material];
    setState(() {
      _selectedMaterial = material;
      // Reset to full bounds on material switch.
      _range = b != null ? RangeValues(b.min, b.max) : null;
    });
  }

  void _apply() {
    if (_selectedMaterial != null && _range != null) {
      ref
          .read(shopProvider.notifier)
          .setPriceFilter(_selectedMaterial!, _range!);
    } else {
      ref.read(shopProvider.notifier).clearPriceFilter();
    }
    Navigator.of(context).pop();
  }

  void _clear() => setState(() {
    _selectedMaterial = null;
    _range = null;
  });

  // Integers shown without decimals; values < 10 shown with 2dp.
  String _fmt(double v, String unit) {
    final s = v < 10
        ? v.toStringAsFixed(2)
        : v % 1 == 0
        ? v.toInt().toString()
        : v.toStringAsFixed(0);
    return '₱$s/${unit == 'piece' ? 'pc' : unit}';
  }

  @override
  Widget build(BuildContext context) {
    final boundsAsync = ref.watch(pricingBoundsProvider);
    final allMaterials = ref.watch(allMaterialsProvider);
    final isActive = _selectedMaterial != null && _range != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDDDDD),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.price_change_outlined,
                      color: Color(0xFFB87333),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Filter by Price',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1B),
                        ),
                      ),
                    ),
                    if (isActive)
                      TextButton(
                        onPressed: _clear,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF9E9E9E),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Clear',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Pick a material, then set your price range. Only shops offering that material within the range will be shown.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFA0A0A2),
                    height: 1.4,
                  ),
                ),
              ),

              const Divider(height: 1),

              Expanded(
                child: boundsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFB87333),
                      strokeWidth: 2,
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Could not load pricing data.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                  data: (bounds) {
                    final selectedBounds = _selectedMaterial != null
                        ? bounds[_selectedMaterial]
                        : null;

                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                      children: [
                        for (final entry in _categories.entries)
                          if (entry.value.any(
                            (m) =>
                                allMaterials.contains(m) &&
                                bounds.containsKey(m),
                          )) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 14,
                                bottom: 8,
                              ),
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB87333),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: entry.value
                                  .where(
                                    (m) =>
                                        allMaterials.contains(m) &&
                                        bounds.containsKey(m),
                                  )
                                  .map(
                                    (m) => _MaterialToggle(
                                      label: m,
                                      isSelected: _selectedMaterial == m,
                                      onTap: () => _selectMaterial(m, bounds),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],

                        if (_selectedMaterial != null &&
                            selectedBounds != null &&
                            _range != null) ...[
                          const SizedBox(height: 28),
                          const Divider(),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  _selectedMaterial!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A1A1B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_fmt(_range!.start, selectedBounds.unit)} – ${_fmt(_range!.end, selectedBounds.unit)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFB87333),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFFB87333),
                              inactiveTrackColor: const Color(0xFFE0C9A6),
                              thumbColor: const Color(0xFFB87333),
                              overlayColor: const Color(
                                0xFFB87333,
                              ).withValues(alpha: 0.12),
                              valueIndicatorColor: const Color(0xFFB87333),
                              valueIndicatorTextStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              rangeThumbShape: const RoundRangeSliderThumbShape(
                                enabledThumbRadius: 10,
                              ),
                              trackHeight: 4,
                            ),
                            child: RangeSlider(
                              values: RangeValues(
                                math.max(_range!.start, selectedBounds.min),
                                math.min(_range!.end, selectedBounds.max),
                              ),
                              min: selectedBounds.min,
                              max: selectedBounds.max,
                              labels: RangeLabels(
                                _fmt(_range!.start, selectedBounds.unit),
                                _fmt(_range!.end, selectedBounds.unit),
                              ),
                              onChanged: (v) => setState(() => _range = v),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _fmt(selectedBounds.min, selectedBounds.unit),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFA0A0A2),
                                ),
                              ),
                              Text(
                                _fmt(selectedBounds.max, selectedBounds.unit),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFA0A0A2),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Shows shops whose ${_selectedMaterial!.toLowerCase()} price range overlaps with your selection.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFA0A0A2),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),

              Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  MediaQuery.of(context).padding.bottom + 12,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Color(0xFFEEEEEE), width: 1),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isActive
                          ? const Color(0xFFB87333)
                          : const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isActive ? 'Apply Price Filter' : 'Show All Shops',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MaterialToggle extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MaterialToggle({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFB87333) : const Color(0xFFF5F0EB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFB87333)
                : const Color(0xFFE0C9A6),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 13, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF7A4F1E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
