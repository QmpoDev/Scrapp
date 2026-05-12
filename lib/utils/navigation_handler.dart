import 'package:url_launcher/url_launcher.dart';

/// Launches the device's native maps app at the given coordinates.
///
/// Tries geo: first (Android), falls back to maps.google.com (cross-platform).
/// Both use externalApplication mode — no in-app WebView.
class NavigationHandler {
  static Future<bool> launch(double lat, double lng) async {
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      return true;
    }

    final mapsUri = Uri.parse('https://maps.google.com/maps?q=$lat,$lng');
    if (await canLaunchUrl(mapsUri)) {
      await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
      return true;
    }

    return false;
  }
}
