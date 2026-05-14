// RegistrationProvider — full registration flow state machine.
//
// Requirements: 1.2–1.8, 5.1–5.6, 6.1–6.7, 7.1–7.7

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../data/supabase_shop_repository.dart';
import '../data/token_store.dart';
import '../providers/device_fingerprint_provider.dart';
import '../providers/supabase_provider.dart';
import '../providers/token_store_provider.dart';
import '../services/geofence_service.dart';
import '../services/photo_service.dart';

// ── Step enum ──────────────────────────────────────────────────────────────────

/// Represents each discrete step in the registration flow state machine.
enum RegistrationStep {
  idle,
  acquiringGps,
  pinPlacement,
  form,
  camera,
  submitting,
  success,
  error,
}

// ── State ──────────────────────────────────────────────────────────────────────

/// Immutable state for the registration flow.
class RegistrationState {
  const RegistrationState({
    this.step = RegistrationStep.idle,
    this.pinLocation,
    this.shopName = '',
    this.ownerName = '',
    this.contactNumber = '',
    this.photo,
    this.submittedShopId,
    this.errorMessage,
    this.isRetryingUpload = false,
    this.isRetryingSubmission = false,
    this.uploadedPhotoUrl,
  });

  final RegistrationStep step;
  final LatLng? pinLocation;
  final String shopName;
  final String ownerName;
  final String contactNumber;
  final XFile? photo;
  final String? submittedShopId;
  final String? errorMessage;
  final bool isRetryingUpload;
  final bool isRetryingSubmission;
  final String? uploadedPhotoUrl;

  RegistrationState copyWith({
    RegistrationStep? step,
    LatLng? pinLocation,
    String? shopName,
    String? ownerName,
    String? contactNumber,
    XFile? photo,
    String? submittedShopId,
    String? errorMessage,
    bool? isRetryingUpload,
    bool? isRetryingSubmission,
    String? uploadedPhotoUrl,
    // Sentinel values to allow explicit null assignment
    bool clearPinLocation = false,
    bool clearPhoto = false,
    bool clearSubmittedShopId = false,
    bool clearErrorMessage = false,
    bool clearUploadedPhotoUrl = false,
  }) {
    return RegistrationState(
      step: step ?? this.step,
      pinLocation: clearPinLocation ? null : (pinLocation ?? this.pinLocation),
      shopName: shopName ?? this.shopName,
      ownerName: ownerName ?? this.ownerName,
      contactNumber: contactNumber ?? this.contactNumber,
      photo: clearPhoto ? null : (photo ?? this.photo),
      submittedShopId: clearSubmittedShopId
          ? null
          : (submittedShopId ?? this.submittedShopId),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      isRetryingUpload: isRetryingUpload ?? this.isRetryingUpload,
      isRetryingSubmission: isRetryingSubmission ?? this.isRetryingSubmission,
      uploadedPhotoUrl: clearUploadedPhotoUrl
          ? null
          : (uploadedPhotoUrl ?? this.uploadedPhotoUrl),
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────────────────────

/// Manages the full registration flow state machine.
///
/// Transitions:
///   idle → acquiringGps → pinPlacement → form → camera → submitting → success
///                                                                    ↘ error
class RegistrationNotifier extends StateNotifier<RegistrationState> {
  RegistrationNotifier({
    required SupabaseShopRepository repository,
    required TokenStore tokenStore,
    required Ref ref,
  }) : _repository = repository,
       _tokenStore = tokenStore,
       _ref = ref,
       super(const RegistrationState());

  final SupabaseShopRepository _repository;
  final TokenStore _tokenStore;
  final Ref _ref;

  // ── 1. startFlow ─────────────────────────────────────────────────────────────

  /// Begins the registration flow by acquiring a high-accuracy GPS fix.
  ///
  /// Requirements 1.2–1.8:
  /// - Requests high-accuracy GPS with a 15-second timeout.
  /// - If accuracy > 20 m on first attempt, retries once more.
  /// - On success: transitions to [RegistrationStep.pinPlacement].
  /// - On timeout or service disabled: transitions to [RegistrationStep.error].
  /// - On permission denied: transitions to [RegistrationStep.error].
  Future<void> startFlow() async {
    state = state.copyWith(step: RegistrationStep.acquiringGps);

    try {
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 15));

      // Requirement 1.5: if accuracy > 20 m, retry once more within the same
      // 15-second window.
      if (pos.accuracy > 20.0) {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        ).timeout(const Duration(seconds: 15));
      }

      state = state.copyWith(
        pinLocation: LatLng(pos.latitude, pos.longitude),
        step: RegistrationStep.pinPlacement,
        clearErrorMessage: true,
      );
    } on TimeoutException {
      state = state.copyWith(
        step: RegistrationStep.error,
        errorMessage: 'Could not obtain a GPS fix. Please try again.',
      );
    } on LocationServiceDisabledException {
      state = state.copyWith(
        step: RegistrationStep.error,
        errorMessage: 'Could not obtain a GPS fix. Please try again.',
      );
    } on PermissionDeniedException {
      state = state.copyWith(
        step: RegistrationStep.error,
        errorMessage: 'Location permission is required to register a shop.',
      );
    } catch (e) {
      state = state.copyWith(
        step: RegistrationStep.error,
        errorMessage: e.toString(),
      );
    }
  }

  // ── 2. confirmPin ─────────────────────────────────────────────────────────────

  /// Records the final pin [location] and advances to the form step.
  ///
  /// Requirement 2.6.
  void confirmPin(LatLng location) {
    state = state.copyWith(pinLocation: location, step: RegistrationStep.form);
  }

  // ── 3. cancelFlow ─────────────────────────────────────────────────────────────

  /// Resets the entire flow back to the initial idle state.
  ///
  /// Requirements 3.7, 1.3.
  void cancelFlow() {
    state = const RegistrationState();
  }

  // ── 4. setFormData ────────────────────────────────────────────────────────────

  /// Stores the form field values from the registration form screen.
  ///
  /// Requirements 3.1–3.6.
  void setFormData({
    required String shopName,
    required String ownerName,
    required String contactNumber,
  }) {
    state = state.copyWith(
      shopName: shopName,
      ownerName: ownerName,
      contactNumber: contactNumber,
    );
  }

  // ── 5. setPhoto ───────────────────────────────────────────────────────────────

  /// Stores the captured [photo] without advancing the step.
  ///
  /// The UI is responsible for advancing to the next step after calling this.
  void setPhoto(XFile photo) {
    state = state.copyWith(photo: photo);
  }

  // ── 5. submit ─────────────────────────────────────────────────────────────────

  /// Executes the full submission pipeline:
  ///
  /// 1. Fresh GPS fix (≤10 s, accuracy ≤50 m)  — Requirements 5.1, 5.4, 5.5
  /// 2. Haversine geofence check (< 50 m)       — Requirements 5.2, 5.3, 5.6
  /// 3. Device fingerprint                       — Requirements 6.1, 6.7
  /// 4. Rate-limit check (24 h window)           — Requirements 6.2–6.4, 6.6
  /// 5. Photo compression                        — Requirement 4.5
  /// 6. Photo upload → Supabase Storage          — Requirement 7.1
  /// 7. DB insert → receive edit_token           — Requirements 7.2, 7.3
  /// 8. Persist edit_token                       — Requirement 7.4
  /// 9. Transition to success                    — Requirement 7.5
  Future<void> submit() async {
    state = state.copyWith(step: RegistrationStep.submitting);

    try {
      final pin = state.pinLocation!;

      // ── Step 1: Fresh GPS fix ──────────────────────────────────────────────
      Position freshPos;
      try {
        freshPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        ).timeout(const Duration(seconds: 10));
      } on TimeoutException {
        state = state.copyWith(
          step: RegistrationStep.error,
          errorMessage:
              'Could not obtain a GPS fix. Please wait for a GPS fix or move to an area with better signal.',
        );
        return;
      } on LocationServiceDisabledException {
        state = state.copyWith(
          step: RegistrationStep.error,
          errorMessage:
              'Could not obtain a GPS fix. Please wait for a GPS fix or move to an area with better signal.',
        );
        return;
      }

      // Requirement 5.5: accuracy must be ≤ 50 m.
      if (freshPos.accuracy > 50.0) {
        state = state.copyWith(
          step: RegistrationStep.error,
          errorMessage:
              'GPS accuracy is insufficient to verify physical presence.',
        );
        return;
      }

      // ── Step 2: Geofence check ─────────────────────────────────────────────
      final currentLatLng = LatLng(freshPos.latitude, freshPos.longitude);
      final withinFence = GeofenceService.checkGeofence(pin, currentLatLng);
      if (!withinFence) {
        state = state.copyWith(
          step: RegistrationStep.error,
          errorMessage: 'You must be within 50 metres of the pin location.',
        );
        return;
      }

      // ── Step 3: Device fingerprint ─────────────────────────────────────────
      final String deviceId;
      try {
        deviceId = await _ref.read(deviceFingerprintProvider.future);
      } on DeviceFingerprintException catch (e) {
        state = state.copyWith(
          step: RegistrationStep.error,
          errorMessage: e.message,
        );
        return;
      }

      // ── Step 4: Rate-limit check ───────────────────────────────────────────
      final bool rateLimited;
      try {
        rateLimited = await _repository.checkRateLimit(deviceId);
      } catch (e) {
        state = state.copyWith(
          step: RegistrationStep.error,
          errorMessage:
              'The rate-limit check could not be completed. Please try again.',
        );
        return;
      }

      if (rateLimited) {
        state = state.copyWith(
          step: RegistrationStep.error,
          errorMessage: 'One submission per device per 24 hours is allowed.',
        );
        return;
      }

      // ── Step 5: Compress photo ─────────────────────────────────────────────
      final compressed = await PhotoService().compressToLimit(state.photo!);
      if (compressed == null) {
        state = state.copyWith(
          step: RegistrationStep.error,
          errorMessage: 'Photo could not be processed. Please retake.',
        );
        return;
      }

      // ── Step 6: Upload photo ───────────────────────────────────────────────
      final String photoUrl;
      try {
        photoUrl = await _repository.uploadPhoto(
          'temp_${DateTime.now().millisecondsSinceEpoch}',
          compressed,
        );
      } catch (e) {
        // Store compressed photo reference so retryUpload() can use it.
        state = state.copyWith(
          step: RegistrationStep.error,
          errorMessage: 'Photo upload failed: ${e.toString()}',
        );
        return;
      }

      state = state.copyWith(uploadedPhotoUrl: photoUrl);

      // ── Step 7: Insert shop record ─────────────────────────────────────────
      final payload = _buildPayload(
        pin: pin,
        photoUrl: photoUrl,
        deviceId: deviceId,
      );

      final ({String id, String editToken}) result;
      try {
        result = await _repository.insertShop(payload);
      } catch (e) {
        state = state.copyWith(
          step: RegistrationStep.error,
          errorMessage: 'Submission failed: ${e.toString()}',
        );
        return;
      }

      // ── Step 8: Persist edit token ─────────────────────────────────────────
      try {
        await _tokenStore.write(result.id, result.editToken);
      } catch (e) {
        // Requirement 7.4: show token-save error but still transition to
        // success so the user can use the Claim flow to recover.
        state = state.copyWith(
          step: RegistrationStep.success,
          submittedShopId: result.id,
          errorMessage:
              'Your shop was submitted but the edit token could not be saved. '
              'Use the "Claim This Shop" flow to recover edit access.',
        );
        return;
      }

      // ── Step 9: Success ────────────────────────────────────────────────────
      state = state.copyWith(
        step: RegistrationStep.success,
        submittedShopId: result.id,
        clearErrorMessage: true,
      );
    } catch (e) {
      state = state.copyWith(
        step: RegistrationStep.error,
        errorMessage: e.toString(),
      );
    }
  }

  // ── 6. retryUpload ────────────────────────────────────────────────────────────

  /// Re-attempts the photo upload using the already-captured photo.
  ///
  /// Requirement 7.6.
  Future<void> retryUpload() async {
    state = state.copyWith(isRetryingUpload: true);

    try {
      final compressed = await PhotoService().compressToLimit(state.photo!);
      if (compressed == null) {
        state = state.copyWith(
          isRetryingUpload: false,
          step: RegistrationStep.error,
          errorMessage: 'Photo could not be processed. Please retake.',
        );
        return;
      }

      final photoUrl = await _repository.uploadPhoto(
        'temp_${DateTime.now().millisecondsSinceEpoch}',
        compressed,
      );

      state = state.copyWith(
        uploadedPhotoUrl: photoUrl,
        isRetryingUpload: false,
      );

      // Proceed to insert after successful upload.
      await _insertAfterUpload(photoUrl);
    } catch (e) {
      state = state.copyWith(
        isRetryingUpload: false,
        step: RegistrationStep.error,
        errorMessage: 'Photo upload failed: ${e.toString()}',
      );
    }
  }

  // ── 7. retrySubmission ────────────────────────────────────────────────────────

  /// Re-attempts the DB insert using the already-uploaded photo URL.
  ///
  /// Requirement 7.7.
  Future<void> retrySubmission() async {
    state = state.copyWith(isRetryingSubmission: true);

    try {
      await _insertAfterUpload(state.uploadedPhotoUrl!);
    } catch (e) {
      state = state.copyWith(
        isRetryingSubmission: false,
        step: RegistrationStep.error,
        errorMessage: 'Submission failed: ${e.toString()}',
      );
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────────

  /// Builds the insert payload map from current state.
  Map<String, dynamic> _buildPayload({
    required LatLng pin,
    required String photoUrl,
    required String deviceId,
  }) {
    return {
      'name': state.shopName,
      'owner_name': state.ownerName,
      'contact_number': state.contactNumber,
      'location': 'POINT(${pin.longitude} ${pin.latitude})',
      'status': 'pending',
      'device_id': deviceId,
      'storefront_photo_url': photoUrl,
    };
  }

  /// Shared insert + token-persist logic used by both [retryUpload] and
  /// [retrySubmission].
  Future<void> _insertAfterUpload(String photoUrl) async {
    final pin = state.pinLocation!;

    // We need the device ID again for the payload.
    final String deviceId;
    try {
      deviceId = await _ref.read(deviceFingerprintProvider.future);
    } on DeviceFingerprintException catch (e) {
      state = state.copyWith(
        isRetryingUpload: false,
        isRetryingSubmission: false,
        step: RegistrationStep.error,
        errorMessage: e.message,
      );
      return;
    }

    final payload = _buildPayload(
      pin: pin,
      photoUrl: photoUrl,
      deviceId: deviceId,
    );

    final result = await _repository.insertShop(payload);

    try {
      await _tokenStore.write(result.id, result.editToken);
    } catch (_) {
      // Token save failed — still show success with recovery message.
      state = state.copyWith(
        isRetryingUpload: false,
        isRetryingSubmission: false,
        step: RegistrationStep.success,
        submittedShopId: result.id,
        errorMessage:
            'Your shop was submitted but the edit token could not be saved. '
            'Use the "Claim This Shop" flow to recover edit access.',
      );
      return;
    }

    state = state.copyWith(
      isRetryingUpload: false,
      isRetryingSubmission: false,
      step: RegistrationStep.success,
      submittedShopId: result.id,
      clearErrorMessage: true,
    );
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────

/// Riverpod provider for the registration flow state machine.
final registrationProvider =
    StateNotifierProvider<RegistrationNotifier, RegistrationState>((ref) {
      final client = ref.watch(supabaseProvider);
      final tokenStore = ref.watch(tokenStoreProvider);
      return RegistrationNotifier(
        repository: SupabaseShopRepository(client),
        tokenStore: tokenStore,
        ref: ref,
      );
    });
