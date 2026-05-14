enum ShopStatus { pending, verified, rejected }

extension ShopStatusX on ShopStatus {
  static ShopStatus fromString(String? s) {
    switch (s) {
      case 'verified':
        return ShopStatus.verified;
      case 'rejected':
        return ShopStatus.rejected;
      default:
        return ShopStatus.pending;
    }
  }

  String get value => name; // 'pending', 'verified', 'rejected'
}

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

  // ── New fields ──────────────────────────────────────────────────────
  /// Verification lifecycle state. Defaults to [ShopStatus.verified] so
  /// existing local-JSON shops (which have no status field) appear as
  /// verified without any code changes in callers.
  final ShopStatus status;
  final String ownerName;
  final String contactNumber;
  final String? storefrontPhotoUrl;
  final String? deviceId;
  final DateTime? submittedAt;
  final DateTime? verifiedAt;

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
    this.status = ShopStatus.verified,
    this.ownerName = '',
    this.contactNumber = '',
    this.storefrontPhotoUrl,
    this.deviceId,
    this.submittedAt,
    this.verifiedAt,
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
      status: ShopStatusX.fromString(json['status'] as String?),
      ownerName: (json['owner_name'] as String?) ?? '',
      contactNumber: (json['contact_number'] as String?) ?? '',
      storefrontPhotoUrl: json['storefront_photo_url'] as String?,
      deviceId: json['device_id'] as String?,
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : null,
      verifiedAt: json['verified_at'] != null
          ? DateTime.parse(json['verified_at'] as String)
          : null,
    );
  }

  /// Maps a Supabase row (snake_case columns) to a [JunkshopModel].
  ///
  /// The repository is expected to project the PostGIS `location` column
  /// using `ST_Y(location::geometry) AS lat` and
  /// `ST_X(location::geometry) AS lng` so this factory receives plain
  /// float values for those two fields.
  factory JunkshopModel.fromSupabaseRow(Map<String, dynamic> row) {
    return JunkshopModel.fromJson(row);
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
    'status': status.value,
    'owner_name': ownerName,
    'contact_number': contactNumber,
    if (storefrontPhotoUrl != null) 'storefront_photo_url': storefrontPhotoUrl,
    if (deviceId != null) 'device_id': deviceId,
    if (submittedAt != null) 'submitted_at': submittedAt!.toIso8601String(),
    if (verifiedAt != null) 'verified_at': verifiedAt!.toIso8601String(),
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
      'JunkshopModel(id: $id, name: $name, municipality: $municipality, status: ${status.value})';

  static void _requireField(Map<String, dynamic> json, String key) {
    if (!json.containsKey(key)) {
      throw FormatException('Missing required field: $key');
    }
  }
}
