// MyShopsScreen — shows all shops registered by the logged-in owner.
// Each card shows the shop's approval status and the appropriate actions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/junkshop.dart';
import '../providers/user_shops_provider.dart';
import '../screens/owner_shop_manage_screen.dart';
import '../screens/registration_form_screen.dart';
import '../theme.dart';

class MyShopsScreen extends ConsumerWidget {
  const MyShopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(userShopsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Manage Junkshop',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(userShopsProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: shopsAsync.when(
              data: (shops) {
                if (shops.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.storefront_outlined,
                            size: 72,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No shops registered yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap "Add Shop" to register your first junkshop.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: shops.length,
                  itemBuilder: (context, index) => _ShopCard(shop: shops[index]),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      const Text(
                        'Failed to load shops',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        err.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(userShopsProvider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shop card ─────────────────────────────────────────────────────────────────

class _ShopCard extends StatelessWidget {
  final JunkshopModel shop;

  const _ShopCard({required this.shop});

  @override
  Widget build(BuildContext context) {
    final status = shop.status;
    final statusInfo = _statusInfo(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status banner ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: statusInfo.color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(statusInfo.icon, size: 16, color: statusInfo.color),
                const SizedBox(width: 8),
                Text(
                  statusInfo.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusInfo.color,
                    letterSpacing: 0.3,
                  ),
                ),
                if (status == ShopStatus.rejected &&
                    shop.status == ShopStatus.rejected) ...[
                  const Spacer(),
                  Text(
                    'Tap Edit & resubmit',
                    style: TextStyle(
                      fontSize: 11,
                      color: statusInfo.color.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Shop info ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shop.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _buildAddress(shop),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (shop.schedule.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_outlined,
                        size: 13,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        shop.schedule,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
                if (shop.acceptedMaterials.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ...shop.acceptedMaterials
                          .take(4)
                          .map(
                            (m) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F0EB),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFE0C9A6),
                                ),
                              ),
                              child: Text(
                                m,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF7A4F1E),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                      if (shop.acceptedMaterials.length > 4)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '+${shop.acceptedMaterials.length - 4} more',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Status-specific message ────────────────────────────────
          if (status == ShopStatus.pending)
            _InfoBanner(
              message:
                  'Your shop is under review. You\'ll be notified once it\'s approved.',
              color: Colors.orange,
            )
          else if (status == ShopStatus.rejected)
            _InfoBanner(
              message:
                  'REJECTED: ${shop.rejectionReason ?? "Your submission was rejected. Update your details and resubmit."}',
              color: Colors.red,
            ),

          // ── Actions ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status == ShopStatus.verified) ...[
                  _ActionButton(
                    label: 'Manage',
                    icon: Icons.settings_outlined,
                    color: AppTheme.primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OwnerShopManageScreen(shop: shop),
                      ),
                    ),
                  ),
                ] else if (status == ShopStatus.rejected) ...[
                  _ActionButton(
                    label: 'Edit & Resubmit',
                    icon: Icons.edit_outlined,
                    color: Colors.red.shade700,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RegistrationFormScreen(resubmitShop: shop),
                      ),
                    ),
                  ),
                ] else ...[
                  // Pending — view only
                  _ActionButton(
                    label: 'View Details',
                    icon: Icons.info_outline,
                    color: Colors.orange.shade700,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OwnerShopManageScreen(shop: shop),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildAddress(JunkshopModel shop) {
    final parts = <String>[];
    if (shop.barangay.isNotEmpty) parts.add(shop.barangay);
    if (shop.municipality.isNotEmpty) parts.add(shop.municipality);
    if (parts.isEmpty && shop.addressLine.isNotEmpty) {
      return shop.addressLine;
    }
    return parts.join(', ');
  }

  ({Color color, IconData icon, String label}) _statusInfo(ShopStatus status) {
    switch (status) {
      case ShopStatus.active:
      case ShopStatus.verified:
        return (
          color: AppTheme.primary,
          icon: Icons.verified_outlined,
          label: 'APPROVED — Live on map',
        );
      case ShopStatus.rejected:
        return (
          color: Colors.red.shade700,
          icon: Icons.cancel_outlined,
          label: 'REJECTED',
        );
      case ShopStatus.pending:
        return (
          color: Colors.orange.shade700,
          icon: Icons.hourglass_top_outlined,
          label: 'PENDING APPROVAL',
        );
    }
  }
}

// ── Info banner ───────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final String message;
  final Color color;

  const _InfoBanner({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: color,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}
