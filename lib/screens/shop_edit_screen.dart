// ShopEditScreen — pre-populated edit form for shop owners.
//
// Requirements: 9.5, 9.8, 9.9, 9.10, 9.11, 9.12, 9.13

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_shop_repository.dart';
import '../models/junkshop.dart';
import '../providers/shop_provider.dart';
import '../theme.dart';

class ShopEditScreen extends ConsumerStatefulWidget {
  const ShopEditScreen({
    super.key,
    required this.shop,
    required this.editToken,
  });

  final JunkshopModel shop;
  final String editToken;

  @override
  ConsumerState<ShopEditScreen> createState() => _ShopEditScreenState();
}

class _ShopEditScreenState extends ConsumerState<ShopEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _shopNameController;
  late final TextEditingController _ownerNameController;
  late final TextEditingController _contactController;
  late final TextEditingController _scheduleController;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _shopNameController = TextEditingController(text: widget.shop.name);
    _ownerNameController = TextEditingController(text: widget.shop.ownerName);
    _contactController = TextEditingController(text: widget.shop.contactNumber);
    _scheduleController = TextEditingController(text: widget.shop.schedule);
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _contactController.dispose();
    _scheduleController.dispose();
    super.dispose();
  }

  // ── Validators ────────────────────────────────────────────────────────────

  String? _validateShopName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Shop name is required';
    if (v.length > 100) return 'Maximum 100 characters';
    return null;
  }

  String? _validateOwnerName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Owner name is required';
    if (v.length > 100) return 'Maximum 100 characters';
    return null;
  }

  String? _validateContact(String? v) {
    if (v == null || v.trim().isEmpty) return 'Contact number is required';
    final digits = v.replaceAll('+', '');
    if (!RegExp(r'^\d+$').hasMatch(digits)) {
      return 'Digits only (optional leading +)';
    }
    if (digits.length < 10) return 'Minimum 10 digits';
    if (v.length > 15) return 'Maximum 15 characters';
    return null;
  }

  // Schedule is optional — no required validation, just length cap.
  String? _validateSchedule(String? v) {
    if (v != null && v.length > 50) return 'Maximum 50 characters';
    return null;
  }

  // ── Save handler ──────────────────────────────────────────────────────────

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final repo = SupabaseShopRepository(Supabase.instance.client);
      final success = await repo.updateShopWithToken(
        widget.shop.id,
        widget.editToken,
        name: _shopNameController.text.trim(),
        ownerName: _ownerNameController.text.trim(),
        contactNumber: _contactController.text.trim(),
        schedule: _scheduleController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        // Refresh the shop list so the map reflects the updated values
        // immediately without waiting for the realtime subscription.
        await ref.read(shopProvider.notifier).refresh();

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Changes saved')));
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid edit token')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: ${e.toString()}'),
          action: SnackBarAction(label: 'Retry', onPressed: _onSave),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Listing')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Shop Name (Requirement 9.5)
              TextFormField(
                controller: _shopNameController,
                validator: _validateShopName,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Shop Name',
                  hintText: "e.g. Juan's Junkshop",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Owner Full Name (Requirement 9.5)
              TextFormField(
                controller: _ownerNameController,
                validator: _validateOwnerName,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Owner Full Name',
                  hintText: 'e.g. Juan dela Cruz',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Contact Number (Requirement 9.5)
              TextFormField(
                controller: _contactController,
                validator: _validateContact,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                ],
                maxLength: 15,
                decoration: const InputDecoration(
                  labelText: 'Contact Number',
                  hintText: 'e.g. +639171234567',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Schedule — optional free text (Requirement 9.5)
              TextFormField(
                controller: _scheduleController,
                validator: _validateSchedule,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: 'Schedule',
                  hintText: 'e.g. Mon–Sat 8am–5pm',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),

              // Save Changes button (Requirement 9.8, 9.13)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary, // Copper #B87333
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _saving ? null : _onSave,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
