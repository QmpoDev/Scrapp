import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data_loader.dart';
import '../data/pricing_repository.dart';
import '../models/junkshop.dart';
import '../utils/schedule_parser.dart';

// ---------------------------------------------------------------------------
// ShopState
// ---------------------------------------------------------------------------

// Immutable value object. All mutations go through copyWith, which makes
// state transitions explicit and easy to trace.
class ShopState {
  final List<JunkshopModel> shops;
  final String searchQuery;
  final String? selectedMunicipality;
  final bool openNowOnly;
  final Set<String> selectedMaterials;
  final String? priceFilterMaterial;
  final RangeValues? priceFilterRange;
  final bool isLoading;
  final String? errorMessage;

  const ShopState({
    this.shops = const [],
    this.searchQuery = '',
    this.selectedMunicipality,
    this.openNowOnly = false,
    this.selectedMaterials = const {},
    this.priceFilterMaterial,
    this.priceFilterRange,
    this.isLoading = true,
    this.errorMessage,
  });

  bool get hasActiveFilters =>
      openNowOnly ||
      selectedMaterials.isNotEmpty ||
      (priceFilterMaterial != null && priceFilterRange != null);

  ShopState copyWith({
    List<JunkshopModel>? shops,
    String? searchQuery,
    Object? selectedMunicipality = _sentinel,
    bool? openNowOnly,
    Set<String>? selectedMaterials,
    Object? priceFilterMaterial = _sentinel,
    Object? priceFilterRange = _sentinel,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ShopState(
      shops: shops ?? this.shops,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedMunicipality: selectedMunicipality == _sentinel
          ? this.selectedMunicipality
          : selectedMunicipality as String?,
      openNowOnly: openNowOnly ?? this.openNowOnly,
      selectedMaterials: selectedMaterials ?? this.selectedMaterials,
      priceFilterMaterial: priceFilterMaterial == _sentinel
          ? this.priceFilterMaterial
          : priceFilterMaterial as String?,
      priceFilterRange: priceFilterRange == _sentinel
          ? this.priceFilterRange
          : priceFilterRange as RangeValues?,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// Distinguishes "not provided" from explicit null in copyWith nullable params.
const Object _sentinel = Object();

// ---------------------------------------------------------------------------
// ShopNotifier
// ---------------------------------------------------------------------------

// ViewModel — owns all business logic, exposes intent-based methods.
// UI calls setQuery/setMunicipality/etc. rather than mutating state directly.
class ShopNotifier extends StateNotifier<ShopState> {
  ShopNotifier(this._bundle) : super(const ShopState()) {
    _loadShops();
  }

  final AssetBundle _bundle;

  Future<void> _loadShops() async {
    try {
      final shops = await DataLoader.load(_bundle);
      state = state.copyWith(shops: shops, isLoading: false, clearError: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setQuery(String query) => state = state.copyWith(searchQuery: query);

  void setMunicipality(String? municipality) =>
      state = state.copyWith(selectedMunicipality: municipality);

  void setOpenNowOnly(bool value) => state = state.copyWith(openNowOnly: value);

  void setSelectedMaterials(Set<String> materials) =>
      state = state.copyWith(selectedMaterials: materials);

  void setPriceFilter(String material, RangeValues range) => state = state
      .copyWith(priceFilterMaterial: material, priceFilterRange: range);

  void clearPriceFilter() =>
      state = state.copyWith(priceFilterMaterial: null, priceFilterRange: null);

  void clearAllFilters() => state = state.copyWith(
    selectedMunicipality: null,
    openNowOnly: false,
    selectedMaterials: {},
    priceFilterMaterial: null,
    priceFilterRange: null,
  );
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

// rootBundle injected here so tests can substitute a mock bundle.
final shopProvider = StateNotifierProvider<ShopNotifier, ShopState>(
  (ref) => ShopNotifier(rootBundle),
);

// All unique material names present in the loaded data — drives filter panels.
final allMaterialsProvider = Provider<List<String>>((ref) {
  final shops = ref.watch(shopProvider).shops;
  final seen = <String>{};
  for (final shop in shops) {
    seen.addAll(shop.acceptedMaterials);
  }
  return seen.toList()..sort();
});

// Pricing bounds keyed by junkshop material name (after applying kMaterialToPricingKey).
// FutureProvider because it reads an asset asynchronously.
final pricingBoundsProvider =
    FutureProvider<Map<String, ({double min, double max, String unit})>>((
      ref,
    ) async {
      final rawBounds = await PricingRepository.load(rootBundle);

      return {
        for (final entry in kMaterialToPricingKey.entries)
          if (rawBounds.containsKey(entry.value))
            entry.key: (
              min: rawBounds[entry.value]!.min,
              max: rawBounds[entry.value]!.max,
              unit: rawBounds[entry.value]!.unit,
            ),
      };
    });

// Applies all active filters in order. Synchronous because all inputs are
// already in ShopState — no async needed.
final filteredShopsProvider = Provider<List<JunkshopModel>>((ref) {
  final state = ref.watch(shopProvider);
  var shops = state.shops;

  // 1. Municipality
  final municipality = state.selectedMunicipality;
  if (municipality != null) {
    shops = shops
        .where(
          (s) => s.municipality.toLowerCase() == municipality.toLowerCase(),
        )
        .toList();
  }

  // 2. Open Now
  if (state.openNowOnly) {
    final now = TimeOfDay.now();
    shops = shops.where((s) {
      final parsed = ScheduleParser.parse(s.schedule);
      if (parsed == null) return false;
      return ScheduleParser.isOpen(parsed.open, parsed.close, now);
    }).toList();
  }

  // 3. Material — shop must accept ALL selected materials
  if (state.selectedMaterials.isNotEmpty) {
    shops = shops.where((s) {
      final shopMaterials = s.acceptedMaterials
          .map((m) => m.toLowerCase())
          .toSet();
      return state.selectedMaterials.every(
        (m) => shopMaterials.contains(m.toLowerCase()),
      );
    }).toList();
  }

  // 4. Price — shop's price range must overlap the filter range
  final priceMaterial = state.priceFilterMaterial;
  final priceRange = state.priceFilterRange;
  if (priceMaterial != null && priceRange != null) {
    shops = shops.where((s) {
      final match = s.prices
          .where((p) => p.material.toLowerCase() == priceMaterial.toLowerCase())
          .firstOrNull;
      if (match == null || match.min == null) return false;
      final shopMax = match.max ?? match.min!;
      return match.min! <= priceRange.end && shopMax >= priceRange.start;
    }).toList();
  }

  // 5. Text search — name or category
  final query = state.searchQuery.trim();
  if (query.isNotEmpty) {
    final lower = query.toLowerCase();
    shops = shops
        .where(
          (s) =>
              s.name.toLowerCase().contains(lower) ||
              s.category.toLowerCase().contains(lower),
        )
        .toList();
  }

  return shops;
});
