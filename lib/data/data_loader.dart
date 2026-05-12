import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../models/junkshop.dart';
import 'pricing_repository.dart';

/// Loads junkshops.json and injects randomised per-shop prices from PricingRepository.

class DataLoader {
  const DataLoader._();

  static const String _shopsAssetPath = 'assets/data/junkshops.json';

  static Future<List<JunkshopModel>> load(AssetBundle bundle) async {
    final boundsMap = await PricingRepository.load(bundle);
    final rawList = await _loadRawShops(bundle);
    final rng = Random();

    return rawList
        .whereType<Map<String, dynamic>>()
        .map((record) => _buildShop(record, boundsMap, rng))
        .whereType<JunkshopModel>()
        .toList();
  }

  static Future<List<dynamic>> _loadRawShops(AssetBundle bundle) async {
    final jsonString = await bundle.loadString(_shopsAssetPath);
    final decoded = jsonDecode(jsonString);

    if (decoded is List) return decoded;

    if (decoded is Map<String, dynamic> && decoded.containsKey('junk_shops')) {
      return (decoded['junk_shops'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(_normalize)
          .toList();
    }

    throw const FormatException(
      'Unrecognised junkshops.json format: '
      'expected a JSON array or an object with a "junk_shops" key.',
    );
  }

  // Returns null on malformed records so the caller can skip them silently.
  static JunkshopModel? _buildShop(
    Map<String, dynamic> record,
    Map<String, PricingBounds> boundsMap,
    Random rng,
  ) {
    try {
      final materials =
          (record['accepted_materials'] as List<dynamic>?)?.cast<String>() ??
          const <String>[];

      return JunkshopModel.fromJson({
        ...record,
        'prices': _generatePrices(
          materials,
          boundsMap,
          rng,
        ).map((p) => p.toJson()).toList(),
      });
    } catch (_) {
      return null;
    }
  }

  // Randomises a sub-range within standard bounds for each material.
  // randomMin sits in the lower half; randomMax sits between randomMin and max.
  // Both are rounded to 2dp and clamped so min ≤ max ≤ bounds.max.
  static List<MaterialPrice> _generatePrices(
    List<String> materials,
    Map<String, PricingBounds> boundsMap,
    Random rng,
  ) {
    return materials.map((name) {
      final pricingKey = kMaterialToPricingKey[name];
      final bounds = pricingKey != null ? boundsMap[pricingKey] : null;

      if (bounds == null) {
        return MaterialPrice(
          material: name,
          unit: 'kg',
          note: 'No definite price, discuss with junkshop',
        );
      }

      final range = bounds.max - bounds.min;
      var randomMin = bounds.min + rng.nextDouble() * range * 0.5;
      var randomMax = randomMin + rng.nextDouble() * (bounds.max - randomMin);

      randomMin = _round2(randomMin).clamp(bounds.min, bounds.max);
      randomMax = _round2(randomMax).clamp(randomMin, bounds.max);

      return MaterialPrice(
        material: name,
        unit: bounds.unit,
        min: randomMin,
        max: randomMax,
      );
    }).toList();
  }

  static double _round2(double value) => (value * 100).round() / 100;

  // Normalises wrapped-format records to the flat schema JunkshopModel.fromJson expects.
  static Map<String, dynamic> _normalize(Map<String, dynamic> r) {
    final coords = r['coordinates'] as Map<String, dynamic>?;
    return {
      'id': r['id']?.toString() ?? r['name']?.toString() ?? '',
      'name': r['name'] ?? '',
      'address': r['address'] ?? r['location'] ?? '',
      'municipality': r['municipality'] ?? '',
      'lat': (coords?['latitude'] as num?)?.toDouble() ?? 0.0,
      'lng': (coords?['longitude'] as num?)?.toDouble() ?? 0.0,
      'category': r['category'] ?? 'General Scrap',
      'schedule': r['schedule'] ?? '',
      'phone': r['phone'] ?? '',
      'accepted_materials': r['accepted_materials'] ?? <String>[],
      'prices': <Map<String, dynamic>>[],
    };
  }
}
