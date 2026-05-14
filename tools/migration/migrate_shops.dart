/// migrate_shops.dart
///
/// Standalone Dart CLI script that seeds existing local JSON shop records
/// from assets/data/junkshops.json into Supabase.
///
/// Usage:
///   dart run migrate_shops.dart
///
/// Required environment variables:
///   SUPABASE_URL              – e.g. https://xyzxyz.supabase.co
///   SUPABASE_SERVICE_ROLE_KEY – service-role JWT (never expose to clients)
///
/// The script derives a stable UUID v5 for each shop by hashing
/// `name + '|' + municipality` with SHA-1, then formatting the first 16 bytes
/// as a UUID with version 5 and RFC-4122 variant bits set.
///
/// Re-running the script is safe: it upserts on the `id` column so no
/// duplicate records are created (Requirement 13.5).

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// UUID v5 derivation
// ---------------------------------------------------------------------------

/// Derives a stable UUID v5 from [input] using SHA-1.
///
/// Steps:
///   1. Compute SHA-1 of the UTF-8 encoded [input].
///   2. Take the first 16 bytes of the digest.
///   3. Set version bits: byte[6] = (byte[6] & 0x0F) | 0x50  (version 5)
///   4. Set variant bits: byte[8] = (byte[8] & 0x3F) | 0x80  (RFC-4122)
///   5. Format as xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
String uuidV5FromString(String input) {
  final digest = sha1.convert(utf8.encode(input));
  final bytes = List<int>.from(digest.bytes.take(16));

  // Set version 5 (0101xxxx) in the high nibble of byte 6
  bytes[6] = (bytes[6] & 0x0F) | 0x50;

  // Set RFC-4122 variant (10xxxxxx) in byte 8
  bytes[8] = (bytes[8] & 0x3F) | 0x80;

  String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');

  final b = bytes.map(hex).toList();
  return '${b[0]}${b[1]}${b[2]}${b[3]}'
      '-${b[4]}${b[5]}'
      '-${b[6]}${b[7]}'
      '-${b[8]}${b[9]}'
      '-${b[10]}${b[11]}${b[12]}${b[13]}${b[14]}${b[15]}';
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

Future<void> main() async {
  // ── Read environment variables ──────────────────────────────────────────
  final supabaseUrl = Platform.environment['SUPABASE_URL'];
  final serviceRoleKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];

  if (supabaseUrl == null || supabaseUrl.isEmpty) {
    stderr.writeln('ERROR: SUPABASE_URL environment variable is not set.');
    exit(1);
  }
  if (serviceRoleKey == null || serviceRoleKey.isEmpty) {
    stderr.writeln(
        'ERROR: SUPABASE_SERVICE_ROLE_KEY environment variable is not set.');
    exit(1);
  }

  // ── Locate and read junkshops.json ──────────────────────────────────────
  // The script is run from the project root, so the path is relative to cwd.
  final jsonFile = File('assets/data/junkshops.json');
  if (!jsonFile.existsSync()) {
    stderr.writeln('ERROR: Could not find assets/data/junkshops.json. '
        'Run this script from the project root.');
    exit(1);
  }

  final Map<String, dynamic> jsonData;
  try {
    jsonData = jsonDecode(jsonFile.readAsStringSync()) as Map<String, dynamic>;
  } catch (e) {
    stderr.writeln('ERROR: Failed to parse junkshops.json: $e');
    exit(1);
  }

  final shops =
      (jsonData['junk_shops'] as List<dynamic>).cast<Map<String, dynamic>>();

  print('Found ${shops.length} shop records in junkshops.json.');

  // ── Prepare migration timestamp ─────────────────────────────────────────
  final verifiedAt = DateTime.now().toUtc().toIso8601String();

  // ── Upsert endpoint ─────────────────────────────────────────────────────
  // POST to /rest/v1/junkshops?on_conflict=id  with Prefer: resolution=merge-duplicates
  final endpoint = Uri.parse('$supabaseUrl/rest/v1/junkshops?on_conflict=id');

  final headers = {
    'Authorization': 'Bearer $serviceRoleKey',
    'apikey': serviceRoleKey,
    'Content-Type': 'application/json',
    'Prefer': 'resolution=merge-duplicates,return=minimal',
  };

  // ── Process each shop ───────────────────────────────────────────────────
  int upserted = 0;
  int failed = 0;

  for (final shop in shops) {
    final name = (shop['name'] as String? ?? '').trim();
    final municipality = (shop['municipality'] as String? ?? '').trim();
    final address = (shop['address'] as String? ?? '').trim();
    final category = (shop['category'] as String? ?? 'General Scrap').trim();
    final schedule = (shop['schedule'] as String? ?? '').trim();
    final acceptedMaterials =
        (shop['accepted_materials'] as List<dynamic>? ?? [])
            .map((m) => m.toString())
            .toList();

    final coordinates = shop['coordinates'] as Map<String, dynamic>? ?? {};
    final lat = (coordinates['latitude'] as num?)?.toDouble();
    final lng = (coordinates['longitude'] as num?)?.toDouble();

    // Validate required fields
    if (name.isEmpty) {
      print('  SKIP  [unnamed shop] – missing name field');
      failed++;
      continue;
    }
    if (lat == null || lng == null) {
      print('  FAIL  [$name] – missing coordinates');
      failed++;
      continue;
    }

    // Derive stable UUID v5 from name + '|' + municipality
    final id = uuidV5FromString('$name|$municipality');

    // Build WKT point string (PostGIS expects "POINT(lng lat)")
    final location = 'POINT($lng $lat)';

    // Build upsert payload
    final payload = {
      'id': id,
      'name': name,
      'owner_name': 'Legacy Record',
      'contact_number': 'N/A',
      'address': address,
      'municipality': municipality,
      'location': location,
      'category': category,
      'schedule': schedule,
      'accepted_materials': acceptedMaterials,
      'status': 'verified',
      'verified_at': verifiedAt,
      'device_id': 'migration',
    };

    // Send upsert request
    try {
      final response = await http.post(
        endpoint,
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('  OK    [$name] (id: $id)');
        upserted++;
      } else {
        final reason = _extractErrorReason(response);
        print('  FAIL  [$name] – HTTP ${response.statusCode}: $reason');
        failed++;
      }
    } catch (e) {
      print('  FAIL  [$name] – Network error: $e');
      failed++;
    }
  }

  // ── Summary ─────────────────────────────────────────────────────────────
  print('');
  print('Migration complete.');
  print('  Upserted : $upserted');
  print('  Failed   : $failed');
  print('  Total    : ${shops.length}');
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Extracts a human-readable error reason from a Supabase REST error response.
String _extractErrorReason(http.Response response) {
  try {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['message'] as String? ??
        body['error'] as String? ??
        response.body;
  } catch (_) {
    return response.body.isEmpty ? '(empty body)' : response.body;
  }
}
