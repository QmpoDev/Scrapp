class MaterialPrice {
  final String material;
  final String unit; // "kg" or "piece"
  final double? min;
  final double? max;
  final String? note;

  const MaterialPrice({
    required this.material,
    required this.unit,
    this.min,
    this.max,
    this.note,
  });

  factory MaterialPrice.fromJson(Map<String, dynamic> json) {
    return MaterialPrice(
      material: json['material'] as String? ?? '',
      unit: json['unit'] as String? ?? 'kg',
      min: (json['min'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'material': material,
    'unit': unit,
    if (min != null) 'min': min,
    if (max != null) 'max': max,
    if (note != null) 'note': note,
  };

  // Formats as "₱12.50–14/kg". Falls back to note when no price is defined.
  String get displayPrice {
    if (note != null && min == null) return note!;
    if (min != null && max != null) {
      final minStr = min! % 1 == 0
          ? min!.toInt().toString()
          : min!.toStringAsFixed(2);
      final maxStr = max! % 1 == 0
          ? max!.toInt().toString()
          : max!.toStringAsFixed(2);
      return '₱$minStr–$maxStr/$unit';
    }
    return 'Ask shop';
  }
}

class JunkshopModel {
  final String id;
  final String name;
  final String address;
  final String municipality;
  final double lat;
  final double lng;
  final String category;
  final String schedule;
  final String phone;
  final List<String> acceptedMaterials;
  final List<MaterialPrice> prices;

  const JunkshopModel({
    required this.id,
    required this.name,
    required this.address,
    required this.municipality,
    required this.lat,
    required this.lng,
    required this.category,
    required this.schedule,
    this.phone = '',
    this.acceptedMaterials = const [],
    this.prices = const [],
  });

  factory JunkshopModel.fromJson(Map<String, dynamic> json) {
    _requireField(json, 'id');
    _requireField(json, 'name');
    _requireField(json, 'address');
    _requireField(json, 'lat');
    _requireField(json, 'lng');
    _requireField(json, 'category');
    _requireField(json, 'schedule');

    return JunkshopModel(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      municipality: (json['municipality'] as String?) ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      category: json['category'] as String,
      schedule: json['schedule'] as String,
      phone: (json['phone'] as String?) ?? '',
      acceptedMaterials:
          (json['accepted_materials'] as List<dynamic>?)?.cast<String>() ??
          const [],
      prices:
          (json['prices'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(MaterialPrice.fromJson)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'municipality': municipality,
    'lat': lat,
    'lng': lng,
    'category': category,
    'schedule': schedule,
    'phone': phone,
    'accepted_materials': acceptedMaterials,
    'prices': prices.map((p) => p.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! JunkshopModel) return false;
    return id == other.id && name == other.name;
  }

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() =>
      'JunkshopModel(id: $id, name: $name, municipality: $municipality)';

  static void _requireField(Map<String, dynamic> json, String key) {
    if (!json.containsKey(key)) {
      throw FormatException('Missing required field: $key');
    }
  }
}
