import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provides the [SupabaseClient] singleton initialised in main().
final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
