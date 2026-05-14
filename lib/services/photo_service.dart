// PhotoService — camera capture and size-limit enforcement for storefront photos.
//
// Requirements: 4.1, 4.2, 4.5, 4.6, 4.7

import 'package:image_picker/image_picker.dart';

/// Maximum allowed file size for a storefront photo: 2 MB (2,097,152 bytes).
const int kMaxPhotoBytes = 2 * 1024 * 1024; // 2,097,152

/// Service responsible for capturing and validating storefront photos.
///
/// - [captureStorefront] opens the live device camera (never the gallery) and
///   returns the captured [XFile], or `null` if the user dismisses without
///   capturing (Requirement 4.8).
/// - [compressToLimit] checks whether the captured photo is within the 2 MB
///   limit. If it already is, it is returned as-is. If it exceeds the limit,
///   `null` is returned so the caller can show the retake error described in
///   Requirement 4.7.
///
/// Note: This service enforces [ImageSource.camera] exclusively and never
/// exposes [ImageSource.gallery], satisfying Requirements 4.1 and 4.2.
class PhotoService {
  PhotoService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Opens the live device camera and returns the captured [XFile].
  ///
  /// - Captures with `imageQuality: 85` to reduce initial file size while
  ///   maintaining acceptable visual quality.
  /// - Returns `null` if the user dismisses the camera without capturing a
  ///   photo (Requirement 4.8).
  /// - Throws if the camera is unavailable or permission is denied; callers
  ///   should catch [PlatformException] and show the Settings-redirect error
  ///   described in Requirement 4.6.
  Future<XFile?> captureStorefront() async {
    return _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );
  }

  /// Checks whether [photo] is within the 2 MB size limit.
  ///
  /// - If the file is already ≤ [kMaxPhotoBytes] bytes, returns [photo]
  ///   unchanged.
  /// - If the file exceeds [kMaxPhotoBytes] bytes, returns `null`. The caller
  ///   is responsible for showing the retake error and re-enabling the
  ///   "Retake" button (Requirement 4.7).
  ///
  /// The initial capture in [captureStorefront] uses `imageQuality: 85` which
  /// handles most cases. If the resulting file still exceeds 2 MB (e.g. a
  /// very high-resolution sensor), this method signals the failure so the
  /// user can retake with better framing or lighting.
  Future<XFile?> compressToLimit(XFile photo) async {
    final bytes = await photo.readAsBytes();
    if (bytes.length <= kMaxPhotoBytes) {
      return photo;
    }
    // File exceeds 2 MB after initial quality reduction — signal failure.
    return null;
  }
}
