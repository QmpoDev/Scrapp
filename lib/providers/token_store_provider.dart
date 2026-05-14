import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/token_store.dart';

/// Provides the [TokenStore] singleton used to persist edit tokens.
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());
