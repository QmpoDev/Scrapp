import 'package:flutter/material.dart';

/// Pill-shaped amber badge displayed in [JunkshopBottomSheet] for shops
/// with [ShopStatus.pending] status.
class PendingStatusBadge extends StatelessWidget {
  const PendingStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFA000),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Pending Verification',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
