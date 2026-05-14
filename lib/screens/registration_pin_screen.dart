import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../providers/registration_provider.dart';
import 'registration_form_screen.dart';

class RegistrationPinScreen extends ConsumerStatefulWidget {
  final LatLng initialLocation;
  const RegistrationPinScreen({super.key, required this.initialLocation});

  @override
  ConsumerState<RegistrationPinScreen> createState() =>
      _RegistrationPinScreenState();
}

class _RegistrationPinScreenState extends ConsumerState<RegistrationPinScreen> {
  late final MapController _mapController;
  late final ValueNotifier<LatLng> _centerNotifier;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _centerNotifier = ValueNotifier(widget.initialLocation);
    // Listen to map move events to update coordinate readout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.mapEventStream.listen((event) {
        if (event is MapEventMove || event is MapEventMoveEnd) {
          _centerNotifier.value = _mapController.camera.center;
        }
      });
    });
  }

  @override
  void dispose() {
    _centerNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1B),
      body: Stack(
        children: [
          // ── Full-screen map ──────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialLocation,
              initialZoom: 17,
              minZoom: 8,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
            ],
          ),

          // ── Fixed center pin ─────────────────────────────────────────────
          // The pin tip visually lands at the map center. The SizedBox below
          // the icon offsets the column so the tip (bottom of the icon) aligns
          // with the true center point rather than the icon's bounding-box center.
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_pin, color: Color(0xFFB87333), size: 48),
                SizedBox(height: 24),
              ],
            ),
          ),

          // ── Top bar ──────────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        ref.read(registrationProvider.notifier).cancelFlow();
                        Navigator.of(context).pop();
                      },
                    ),
                    const Text(
                      'Place Your Shop Pin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Coordinate readout + Confirm button ──────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Coordinate display — updates live as the map pans.
                    ValueListenableBuilder<LatLng>(
                      valueListenable: _centerNotifier,
                      builder: (_, center, __) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          // Requirement 2.3: 5 decimal places.
                          '${center.latitude.toStringAsFixed(5)}, '
                          '${center.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Confirm button — always active; pin coordinates = map center.
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB87333),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          // Requirement 2.6: record final pin coordinates and
                          // advance the state machine to the form step.
                          final loc = _centerNotifier.value;
                          ref
                              .read(registrationProvider.notifier)
                              .confirmPin(loc);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const RegistrationFormScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Confirm Location',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
