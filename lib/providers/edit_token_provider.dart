import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'token_store_provider.dart';

/// Returns the locally-stored edit token for [shopId], or null if none exists.
/// Used by [JunkshopBottomSheet] to decide whether to show the "Edit" button.
final editTokenProvider = FutureProvider.family<String?, String>((ref, shopId) {
  final store = ref.watch(tokenStoreProvider);
  return store.read(shopId);
});
