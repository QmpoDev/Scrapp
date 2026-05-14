import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:lottie/lottie.dart' hide Marker;

import '../models/junkshop.dart';
import '../providers/shop_provider.dart';
import '../screens/shop_detail_screen.dart';
import '../utils/app_animations.dart';
import '../utils/distance_calculator.dart' show GeoDistance;
import '../widgets/animated_marker.dart';
import '../widgets/glass_container.dart';
import '../widgets/junkshop_bottom_sheet.dart';
import '../widgets/material_filter_sheet.dart';
import '../widgets/municipality_filter_sheet.dart';
import '../widgets/price_filter_sheet.dart';
import '../widgets/welcome_modal.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_shop_repository.dart';
import '../providers/edit_token_provider.dart';
import '../providers/registration_provider.dart';
import '../widgets/registration_fab.dart';
import 'claim_shop_screen.dart';
import 'registration_pin_screen.dart';
import 'shop_edit_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  bool _isSheetOpen = false;
  List<String> _places = [];
  LatLng? _userLocation;
  bool _locating = false;

  /// Whether labels should be shown — true when zoom ≥ [_labelZoomThreshold].
  /// Kept as a separate bool so [setState] is only called when the threshold
  /// is crossed, not on every pan/zoom event.
  bool _showLabels = _initialZoom >= _labelZoomThreshold;

  final MapController _mapController = MapController();

  /// Cache of built [Marker] widgets keyed by `'${shop.id}_${isSelected}_$showLabels'`.
  /// Avoids rebuilding identical markers on every frame.
  final Map<String, Marker> _markerCache = {};

  /// ID of the shop whose bottom sheet is currently open.
  /// Used to highlight the corresponding marker (isSelected = true).
  String? _selectedShopId;

  // Labels appear at zoom ≥ 14 — markers are spread enough to avoid overlap.
  static const double _labelZoomThreshold = 14.0;

  static const String _tileUrl =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
  static const LatLng _initialCenter = LatLng(16.6159, 120.3209);
  static const double _initialZoom = 11.5;
  static const double _minZoom = 8.0;
  static const double _maxZoom = 18.0;

  @override
  void initState() {
    super.initState();
    _loadMunicipalities();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Welcome modal first — avoids two system dialogs stacking on first launch.
      await showWelcomeModalIfNeeded(context);
      if (mounted) _initLocation();
    });
    // Track zoom so labels appear/disappear at the threshold without rebuilding on every pan.
    // setState is only called when the label threshold is crossed — not on every pan/zoom event.
    _mapController.mapEventStream.listen((event) {
      if (!mounted || event is! MapEventMove) return;
      final newZoom = event.camera.zoom;
      final newShowLabels = newZoom >= _labelZoomThreshold;
      if (newShowLabels != _showLabels) {
        setState(() => _showLabels = newShowLabels);
      }
    });
  }

  Future<void> _initLocation() async {
    // silent: false so the permission dialog fires on startup.
    final pos = await _fetchLocation(silent: false);
    if (pos != null && mounted) {
      setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
      _mapController.move(_userLocation!, 13.0);
    }
  }

  Future<void> _onLocateTap() async {
    if (_locating) return;
    setState(() => _locating = true);
    final pos = await _fetchLocation(silent: false);
    if (!mounted) return;
    setState(() => _locating = false);
    if (pos != null) {
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() => _userLocation = loc);
      _mapController.move(loc, 14.0);
    }
  }

  Future<Position?> _fetchLocation({required bool silent}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!silent && mounted) _showSnack('Location services are disabled.');
        return null;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (silent) return null;
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) _showSnack('Location permission denied.');
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (!silent && mounted) {
          _showSnack(
            'Location permission permanently denied. Enable it in Settings.',
          );
        }
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── Municipalities ────────────────────────────────────────────────────────

  Future<void> _loadMunicipalities() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/data/la_union_municipalities.json',
      );
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final laUnion = data['LaUnion'] as Map<String, dynamic>;
      final cities = (laUnion['City'] as List<dynamic>).cast<String>();
      final municipalities = (laUnion['Municipalities'] as List<dynamic>)
          .cast<String>();
      if (mounted) setState(() => _places = [...cities, ...municipalities]);
    } catch (_) {}
  }

  // ── Bottom sheet ──────────────────────────────────────────────────────────

  Future<void> _showShopSheet(JunkshopModel shop) async {
    if (_isSheetOpen) Navigator.of(context).pop();
    setState(() {
      _isSheetOpen = true;
      _selectedShopId = shop.id;
    });

    double? distanceKm;
    if (_userLocation != null) {
      distanceKm = GeoDistance.km(_userLocation!, LatLng(shop.lat, shop.lng));
    }

    final String? editToken = await ref.read(editTokenProvider(shop.id).future);
    final bool hasEditToken = editToken != null;

    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => JunkshopBottomSheet(
        shop: shop,
        distanceKm: distanceKm,
        hasEditToken: hasEditToken,
        onEdit: hasEditToken
            ? () async {
                Navigator.of(context).pop(); // close bottom sheet
                final token = await ref.read(editTokenProvider(shop.id).future);
                if (token == null) return;
                try {
                  final repo = SupabaseShopRepository(Supabase.instance.client);
                  final valid = await repo.validateToken(shop.id, token);
                  if (!mounted) return;
                  if (valid) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ShopEditScreen(shop: shop, editToken: token),
                      ),
                    );
                  } else {
                    _showSnack('Edit token is invalid');
                  }
                } catch (e) {
                  if (mounted) _showSnack(e.toString());
                }
              }
            : null,
        onClaim: () async {
          Navigator.of(context).pop(); // close bottom sheet
          final newToken = await Navigator.of(context).push<String>(
            MaterialPageRoute(builder: (_) => ClaimShopScreen(shop: shop)),
          );
          if (newToken != null && mounted) {
            // Token already persisted by ClaimShopScreen; push edit screen
            final freshShop = await SupabaseShopRepository(
              Supabase.instance.client,
            ).fetchShop(shop.id);
            if (!mounted) return;
            if (freshShop != null) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ShopEditScreen(shop: freshShop, editToken: newToken),
                ),
              );
            }
          }
        },
      ),
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _isSheetOpen = false;
          _selectedShopId = null;
        });
      }
    });
  }

  // ── Marker builder ────────────────────────────────────────────────────────

  /// Builds a single [Marker] for [entry] with the given display state.
  /// Extracted so the two-pass cache in [build] can call it cleanly.
  Marker _buildMarker(
    MapEntry<int, JunkshopModel> entry,
    bool showLabels,
    bool isSelected,
  ) {
    final shop = entry.value;
    return Marker(
      width: 100,
      height: showLabels ? 68 : 44,
      point: LatLng(shop.lat, shop.lng),
      child: RepaintBoundary(
        child:
            AnimatedMarker(
                  onTap: () => _showShopSheet(shop),
                  label: shop.name,
                  showLabel: showLabels,
                  isSelected: isSelected,
                )
                .animate()
                .scale(
                  begin: const Offset(0, 0),
                  end: const Offset(1, 1),
                  delay: AppAnimations.markerStaggerStep * entry.key,
                  duration: AppAnimations.markerEntrance,
                  curve: AppAnimations.elasticOut,
                )
                .fadeIn(
                  delay: AppAnimations.markerStaggerStep * entry.key,
                  duration: AppAnimations.markerEntranceFade,
                ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final shopState = ref.watch(shopProvider);
    final filteredShops = ref.watch(filteredShopsProvider);
    final selectedMunicipality = shopState.selectedMunicipality;
    final allShops = shopState.shops;
    final openNowOnly = shopState.openNowOnly;
    final selectedMaterials = shopState.selectedMaterials;
    final priceFilterMaterial = shopState.priceFilterMaterial;
    final hasPriceFilter =
        priceFilterMaterial != null && shopState.priceFilterRange != null;

    if (shopState.errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFF2E7D32), // Forest Green
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load junkshop data',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  shopState.errorMessage!,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final Map<String, int> shopCounts = {};
    for (final shop in allShops) {
      if (shop.municipality.isNotEmpty) {
        shopCounts[shop.municipality] =
            (shopCounts[shop.municipality] ?? 0) + 1;
      }
    }

    // Staggered entrance animation — delay scales with marker index.
    // Two-pass cache: build only markers whose key has changed, prune stale entries.
    final newCache = <String, Marker>{};
    final markers = filteredShops.asMap().entries.map((entry) {
      final shop = entry.value;
      final isSelected = _selectedShopId == shop.id;
      final cacheKey = '${shop.id}_${isSelected}_$_showLabels';
      newCache[cacheKey] = _markerCache.putIfAbsent(
        cacheKey,
        () => _buildMarker(entry, _showLabels, isSelected),
      );
      return newCache[cacheKey]!;
    }).toList();
    // Replace cache with only the markers used this frame (prunes stale entries).
    _markerCache
      ..clear()
      ..addAll(newCache);

    // User location marker
    final userMarkers = _userLocation == null
        ? <Marker>[]
        : [
            Marker(
              width: 48,
              height: 48,
              point: _userLocation!,
              child: RepaintBoundary(child: const UserLocationMarker()),
            ),
          ];

    final showNoResults =
        filteredShops.isEmpty &&
        (shopState.searchQuery.trim().isNotEmpty ||
            shopState.hasActiveFilters ||
            shopState.selectedMunicipality != null);
    final topPadding = MediaQuery.of(context).padding.top;

    ref.listen<RegistrationState>(registrationProvider, (previous, next) {
      if (next.step == RegistrationStep.pinPlacement &&
          previous?.step != RegistrationStep.pinPlacement &&
          next.pinLocation != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                RegistrationPinScreen(initialLocation: next.pinLocation!),
          ),
        );
      }
    });

    return Scaffold(
      body: GestureDetector(
        // Dismiss keyboard and dropdown when tapping the map.
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // ── Map ──────────────────────────────────────────────────────────
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialCenter,
                initialZoom: _initialZoom,
                minZoom: _minZoom,
                maxZoom: _maxZoom,
              ),
              children: [
                TileLayer(
                  urlTemplate: _tileUrl,
                  subdomains: const ['a', 'b', 'c', 'd'],
                  retinaMode: RetinaMode.isHighDensity(context),
                  tileBuilder: (context, tileWidget, tile) {
                    if (tile.loadError) {
                      return Container(
                        color: const Color(0xFFF5F5F5),
                        child: const Center(
                          child: Text(
                            'Tiles unavailable',
                            style: TextStyle(
                              color: Color(0xFF9E9E9E),
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return tileWidget;
                  },
                ),
                MarkerLayer(markers: userMarkers),
                MarkerLayer(markers: markers),
              ],
            ),

            // ── Top overlay ───────────────────────────────────────────────────
            Positioned(
              top: topPadding + 12,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Animated search bar entry
                  _AnimatedSearchBar(
                        onChanged: (q) =>
                            ref.read(shopProvider.notifier).setQuery(q),
                        onClear: () {
                          ref.read(shopProvider.notifier).setQuery('');
                        },
                        query: shopState.searchQuery,
                      )
                      .animate()
                      .slideY(
                        begin: -0.4,
                        end: 0,
                        duration: AppAnimations.emphasisSlow,
                        curve: AppAnimations.easeOutCubic,
                      )
                      .fadeIn(duration: AppAnimations.standardSlow),

                  if (_places.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    GlassContainer(
                          borderRadius: 12,
                          opacity: 0.92,
                          blurSigma: _isSheetOpen ? 18.0 : 12.0,
                          animationDuration: AppAnimations.emphasis,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.tune,
                                size: 13,
                                color: Color(0xFF4E5963),
                              ),
                              const SizedBox(width: 6),
                              // Fade edge signals the row is horizontally scrollable.
                              Expanded(
                                child: ShaderMask(
                                  shaderCallback: (bounds) => LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.white,
                                      Colors.white,
                                      Colors.white.withValues(alpha: 0),
                                    ],
                                    stops: const [0.0, 0.82, 1.0],
                                  ).createShader(bounds),
                                  blendMode: BlendMode.dstIn,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    // Extra right padding so the last chip clears the fade.
                                    padding: const EdgeInsets.only(right: 20),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _ToggleButton(
                                          label:
                                              selectedMunicipality ??
                                              'Location',
                                          icon: Icons.location_on_outlined,
                                          isActive:
                                              selectedMunicipality != null,
                                          onTap: () => showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (_) =>
                                                MunicipalityFilterSheet(
                                                  places: _places,
                                                  shopCounts: shopCounts,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        _ToggleButton(
                                          label: 'Open Now',
                                          icon: Icons.access_time,
                                          isActive: openNowOnly,
                                          onTap: () => ref
                                              .read(shopProvider.notifier)
                                              .setOpenNowOnly(!openNowOnly),
                                        ),
                                        const SizedBox(width: 6),
                                        _ToggleButton(
                                          label: selectedMaterials.isEmpty
                                              ? 'Material'
                                              : '${selectedMaterials.length} Mat.',
                                          icon: Icons.category_outlined,
                                          isActive:
                                              selectedMaterials.isNotEmpty,
                                          onTap: () => showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (_) =>
                                                const MaterialFilterSheet(),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        _ToggleButton(
                                          label: _truncateLabel(
                                            priceFilterMaterial ?? 'Price',
                                          ),
                                          icon: Icons.price_change_outlined,
                                          isActive: hasPriceFilter,
                                          onTap: () => showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (_) =>
                                                const PriceFilterSheet(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                        .animate()
                        .slideY(
                          begin: -0.3,
                          end: 0,
                          delay: const Duration(milliseconds: 80),
                          duration: AppAnimations.emphasis,
                          curve: AppAnimations.easeOutCubic,
                        )
                        .fadeIn(
                          delay: const Duration(milliseconds: 80),
                          duration: AppAnimations.standardFade,
                        ),
                    if (shopState.hasActiveFilters ||
                        selectedMunicipality != null) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _ClearButton(
                          onTap: () =>
                              ref.read(shopProvider.notifier).clearAllFilters(),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            // ── Locate FAB ────────────────────────────────────────────────────
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              right: 16,
              child:
                  _PressScaleFAB(
                    onTap: _onLocateTap,
                    child: _locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF2E7D32), // Forest Green
                            ),
                          )
                        : const Icon(
                            Icons.my_location,
                            size: 20,
                            color: Color(0xFF2E7D32), // Forest Green
                          ),
                  ).animate().scale(
                    begin: const Offset(0, 0),
                    end: const Offset(1, 1),
                    delay: const Duration(milliseconds: 500),
                    duration: AppAnimations.emphasisSlow,
                    curve: AppAnimations.elasticOut,
                  ),
            ),

            // ── Registration FAB ──────────────────────────────────────────────────
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 16,
              child: const RegistrationFab(),
            ),

            // ── No results overlay ────────────────────────────────────────────
            if (showNoResults)
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    // Responsive motion: shift the overlay up when the keyboard
                    // is open so it stays visible above the IME (Phase 3).
                    alignment: MediaQuery.of(context).viewInsets.bottom > 0
                        ? const Alignment(0, -0.3)
                        : const Alignment(0, 0.15),
                    child: const _NoResultsOverlay()
                        .animate()
                        .scale(
                          begin: const Offset(0.8, 0.8),
                          end: const Offset(1, 1),
                          duration: AppAnimations.standardSlow,
                          curve: AppAnimations.easeOutBack,
                        )
                        .fadeIn(duration: AppAnimations.standardFade),
                  ),
                ),
              ),

            // ── Search dropdown — LAST child so it paints above everything ────
            if (shopState.searchQuery.trim().isNotEmpty &&
                filteredShops.isNotEmpty)
              Positioned(
                top: topPadding + 12 + 52 + 4,
                left: 16,
                right: 16,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        (MediaQuery.of(context).size.height -
                                MediaQuery.of(context).viewInsets.bottom -
                                (topPadding + 12 + 52 + 4) -
                                MediaQuery.of(context).padding.bottom -
                                16)
                            .clamp(120.0, 320.0),
                  ),
                  child: _SearchDropdown(
                    shops: filteredShops,
                    onSelected: (shop) {
                      FocusScope.of(context).unfocus();
                      ref.read(shopProvider.notifier).setQuery('');
                      Navigator.of(context).push(
                        PageRouteBuilder<void>(
                          pageBuilder: (_, __, ___) => ShopDetailScreen(
                            shop: shop,
                            distanceKm: _userLocation != null
                                ? GeoDistance.km(
                                    _userLocation!,
                                    LatLng(shop.lat, shop.lng),
                                  )
                                : null,
                          ),
                          transitionsBuilder: (_, animation, __, child) {
                            final isReverse =
                                animation.status == AnimationStatus.reverse;
                            final curved = CurvedAnimation(
                              parent: animation,
                              curve: AppAnimations.easeInOutCubic,
                            );
                            if (isReverse) {
                              return FadeTransition(
                                opacity: curved,
                                child: child,
                              );
                            }
                            return FadeTransition(
                              opacity: curved,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.06),
                                  end: Offset.zero,
                                ).animate(curved),
                                child: child,
                              ),
                            );
                          },
                          transitionDuration: AppAnimations.emphasis,
                          reverseTransitionDuration: const Duration(
                            milliseconds: 250,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Animated Search Bar ───────────────────────────────────────────────────────

class _AnimatedSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String query;

  const _AnimatedSearchBar({
    required this.onChanged,
    required this.onClear,
    required this.query,
  });

  @override
  State<_AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<_AnimatedSearchBar> {
  bool _focused = false;
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
    _controller.text = widget.query;
  }

  @override
  void didUpdateWidget(_AnimatedSearchBar old) {
    super.didUpdateWidget(old);
    if (widget.query != _controller.text) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Search input ──────────────────────────────────────────────────
        GlassContainer(
          borderRadius: 14,
          opacity: 0.94,
          child: AnimatedContainer(
            duration: AppAnimations.standardMid,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _focused
                    ? const Color(0xFFB87333)
                    : const Color(0xFF4E5963).withValues(alpha: 0.18),
                width: _focused ? 1.5 : 1,
              ),
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              onChanged: widget.onChanged,
              style: const TextStyle(
                color: Color(0xFF1A1A1B),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Find junkshops near you',
                hintStyle: const TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 14,
                ),
                prefixIcon: AnimatedSwitcher(
                  duration: AppAnimations.standard,
                  child: Icon(
                    Icons.search,
                    key: ValueKey(_focused),
                    color: _focused
                        ? const Color(0xFFB87333)
                        : const Color(0xFF9E9E9E),
                    size: 20,
                  ),
                ),
                suffixIcon: widget.query.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _controller.clear();
                          widget.onClear();
                        },
                        child: const Icon(
                          Icons.close,
                          color: Color(0xFF9E9E9E),
                          size: 18,
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Search Dropdown ───────────────────────────────────────────────────────────

class _SearchDropdown extends StatelessWidget {
  final List<JunkshopModel> shops;
  final ValueChanged<JunkshopModel> onSelected;

  const _SearchDropdown({required this.shops, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    // Cap at 5 visible results; the list is scrollable if more match.
    final results = shops.take(5).toList();

    return GlassContainer(
          borderRadius: 14,
          opacity: 0.97,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: results.length + (shops.length > 5 ? 1 : 0),
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: Color(0xFFEEEEEE),
              ),
              itemBuilder: (context, i) {
                if (i == results.length) {
                  // Footer row
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: Text(
                      '+${shops.length - 5} more results on map',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFA0A0A2),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  );
                }
                return _SearchResultTile(
                  shop: results[i],
                  onTap: () => onSelected(results[i]),
                );
              },
            ),
          ),
        )
        .animate()
        .fadeIn(duration: AppAnimations.microMedium)
        .slideY(
          begin: -0.08,
          end: 0,
          duration: AppAnimations.chipMicro,
          curve: AppAnimations.easeOutCubic,
        );
  }
}

class _SearchResultTile extends StatefulWidget {
  final JunkshopModel shop;
  final VoidCallback onTap;

  const _SearchResultTile({required this.shop, required this.onTap});

  @override
  State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile> {
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
      child: AnimatedContainer(
        duration: AppAnimations.micro,
        color: _pressed
            ? const Color(0xFFB87333).withValues(alpha: 0.06)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFB87333).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.storefront_outlined,
                size: 16,
                color: Color(0xFFB87333),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.shop.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    widget.shop.municipality.isNotEmpty
                        ? '${widget.shop.category} · ${widget.shop.municipality}'
                        : widget.shop.category,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFA0A0A2),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }
}

// ── Press-Scale FAB ───────────────────────────────────────────────────────────

class _PressScaleFAB extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressScaleFAB({required this.child, required this.onTap});

  @override
  State<_PressScaleFAB> createState() => _PressScaleFABState();
}

class _PressScaleFABState extends State<_PressScaleFAB> {
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
        scale: _pressed ? 0.88 : 1.0,
        duration: AppAnimations.micro,
        child: GlassContainer(
          borderRadius: 14,
          opacity: 0.96,
          padding: const EdgeInsets.all(12),
          child: widget.child,
        ),
      ),
    );
  }
}

// ── Label truncation helper ───────────────────────────────────────────────────

/// Shortens long material names for the active price chip.
/// e.g. "Glass Bottles (Longneck Emperador)" → "Glass (Longneck)"
String _truncateLabel(String label) {
  if (label.length <= 14) return label;
  final parenMatch = RegExp(r'^(\w+)[^(]*\(([^)]+)\)').firstMatch(label);
  if (parenMatch != null) {
    final first = parenMatch.group(1)!;
    final inner = parenMatch.group(2)!;
    final innerShort = inner.split(' ').first;
    final candidate = '$first ($innerShort)';
    return candidate.length <= 16 ? candidate : '${label.substring(0, 13)}…';
  }
  return '${label.substring(0, 13)}…';
}

// ── Toggle Button ────────────────────────────────────────────────────────

class _ToggleButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends State<_ToggleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF2E7D32);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque, // 44px minimum touch target
      child: SizedBox(
        height: 44,
        child: Center(
          child: AnimatedScale(
            scale: _pressed ? 0.92 : 1.0,
            duration: AppAnimations.micro,
            child: AnimatedContainer(
              duration: AppAnimations.chipMicro,
              decoration: BoxDecoration(
                color: widget.isActive ? activeColor : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isActive
                      ? activeColor
                      : const Color(0xFF4E5963).withValues(alpha: 0.25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.isActive
                        ? activeColor.withValues(alpha: _pressed ? 0.15 : 0.3)
                        : Colors.black.withValues(
                            alpha: _pressed ? 0.03 : 0.06,
                          ),
                    blurRadius: widget.isActive ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: AnimatedPadding(
                padding: widget.isActive
                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                    : const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                duration: AppAnimations.chipMicro,
                curve: AppAnimations.easeOutCubic,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedOpacity(
                      opacity: widget.isActive ? 1.0 : 0.6,
                      duration: AppAnimations.chipMicro,
                      curve: AppAnimations.easeOutCubic,
                      child: Icon(
                        widget.icon,
                        size: 13,
                        color: widget.isActive
                            ? Colors.white
                            : const Color(0xFF4E5963),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: widget.isActive
                            ? Colors.white
                            : const Color(0xFF1A1A1B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Clear Button ──────────────────────────────────────────────────────────────

class _ClearButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ClearButton({required this.onTap});

  @override
  State<_ClearButton> createState() => _ClearButtonState();
}

class _ClearButtonState extends State<_ClearButton> {
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
        scale: _pressed ? 0.92 : 1.0,
        duration: AppAnimations.micro,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: _pressed ? const Color(0xFFFFDDC0) : const Color(0xFFFFEEE0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFB87333), width: 1),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close, size: 11, color: Color(0xFFB87333)),
              SizedBox(width: 3),
              Text(
                'Clear Filters',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB87333),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── No Results Overlay ────────────────────────────────────────────────────────

class _NoResultsOverlay extends StatelessWidget {
  const _NoResultsOverlay();

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 16,
      opacity: 0.96,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Lottie empty-state animation replaces the static icon.
          // Falls back to a plain icon if the asset fails to load.
          SizedBox(
            width: 56,
            height: 56,
            child: Lottie.asset(
              'assets/lottie/empty_state.json',
              width: 56,
              height: 56,
              fit: BoxFit.contain,
              repeat: true,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.search_off,
                color: Color(0xFF9E9E9E),
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No results found',
            style: TextStyle(
              color: Color(0xFF757575),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Try adjusting your filters',
            style: TextStyle(color: Color(0xFFA0A0A2), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
