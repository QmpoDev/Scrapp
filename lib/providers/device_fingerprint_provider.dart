import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeviceFingerprintException implements Exception {
  final String message;
  const DeviceFingerprintException(this.message);
  @override
  String toString() => 'DeviceFingerprintException: $message';
}

final deviceFingerprintProvider = FutureProvider<String>((ref) async {
  final info = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    final android = await info.androidInfo;
    final id = android.id; // stable Android ID
    if (id.isEmpty) {
      throw const DeviceFingerprintException('Android ID is empty');
    }
    return id;
  } else if (Platform.isIOS) {
    final ios = await info.iosInfo;
    final id = ios.identifierForVendor;
    if (id == null || id.isEmpty) {
      throw const DeviceFingerprintException('identifierForVendor is null');
    }
    return id;
  }
  throw const DeviceFingerprintException('Unsupported platform');
});
