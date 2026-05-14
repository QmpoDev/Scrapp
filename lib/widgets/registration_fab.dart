import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/registration_provider.dart';

/// Amber "+" FAB that initiates the shop registration flow.
///
/// Requirements: 1.1, 1.3
class RegistrationFab extends ConsumerWidget {
  const RegistrationFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(registrationProvider).step;
    final isAcquiring = step == RegistrationStep.acquiringGps;
    final isActive =
        step != RegistrationStep.idle && step != RegistrationStep.error;

    return Opacity(
      opacity: isActive ? 0.5 : 1.0,
      child: SizedBox(
        width: 56,
        height: 56,
        child: FloatingActionButton(
          heroTag: 'registration_fab',
          backgroundColor: const Color(0xFFFFA000),
          onPressed: isActive
              ? null
              : () => ref.read(registrationProvider.notifier).startFlow(),
          child: isAcquiring
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
