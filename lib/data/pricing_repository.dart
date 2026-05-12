import 'dart:convert';

import 'package:flutter/services.dart';

// Maps junkshop accepted_materials names to keys in scrap_standard_pricing.json.
// Single source of truth — both DataLoader and pricingBoundsProvider use this.
const Map<String, String> kMaterialToPricingKey = {
  'Steel': 'Steel',
  'Tin Cans': 'Tin Cans',
  'Metal Roofing': 'Metal Roofing',
  'Aluminum': 'Aluminum',
  'Copper': 'Copper',
  'Brass': 'Brass',
  'Stainless Steel': 'Stainless Steel',
  'Plastics': 'Plastics',
  'Paper': 'Paper',
  'Cardboard': 'Cardboard',
  'Glass Bottles (2x2 Gin)': 'Glass Bottle (2x2 Gin)',
  'Glass Bottles (Longneck Emperador)': 'Glass Bottle (Longneck Emperador)',
  'Glass Bottles (Ketchup)': 'Glass Bottle (Ketchup)',
  'Motherboard': 'Motherboard',
  'IC': 'IC',
  'TV Board': 'TV Board',
};

class PricingBounds {
  final double min;
  final double max;
  final String unit; // "kg" or "piece"

  const PricingBounds({
    required this.min,
    required this.max,
    required this.unit,
  });

  // Returns null on missing/wrong-type fields rather than throwing.
  static PricingBounds? fromJson(Map<String, dynamic> json) {
    final min = (json['min'] as num?)?.toDouble();
    final max = (json['max'] as num?)?.toDouble();
    final unit = json['unit'] as String?;
    if (min == null || max == null || unit == null) return null;
    return PricingBounds(min: min, max: max, unit: unit);
  }
}

class PricingRepository {
  const PricingRepository._();

  static const String _assetPath = 'assets/data/scrap_standard_pricing.json';

  static Future<Map<String, PricingBounds>> load(AssetBundle bundle) async {
    final raw = await bundle.loadString(_assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final scraps = json['JunkshopScraps'] as Map<String, dynamic>? ?? {};
    return _flatten(scraps);
  }

  // Recursively walks the nested JSON, collecting leaf bound objects.
  static Map<String, PricingBounds> _flatten(Map<String, dynamic> node) {
    final result = <String, PricingBounds>{};
    for (final entry in node.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;

      if (value.containsKey('min') && value.containsKey('max')) {
        final bounds = PricingBounds.fromJson(value);
        if (bounds != null) result[entry.key] = bounds;
      } else {
        result.addAll(_flatten(value));
      }
    }
    return result;
  }
}
