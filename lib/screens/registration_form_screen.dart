// RegistrationFormScreen — shop registration form presented as a bottom sheet.
//
// Requirements: 3.1–3.7, 4.1–4.8

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/registration_provider.dart';
import '../services/photo_service.dart';
import 'registration_success_screen.dart';

class RegistrationFormScreen extends ConsumerStatefulWidget {
  const RegistrationFormScreen({super.key});

  @override
  ConsumerState<RegistrationFormScreen> createState() =>
      _RegistrationFormScreenState();
}

class _RegistrationFormScreenState
    extends ConsumerState<RegistrationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _contactController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  // ── Validators ────────────────────────────────────────────────────────────────

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

  // ── Submit handler ────────────────────────────────────────────────────────────

  Future<void> _onNext() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final notifier = ref.read(registrationProvider.notifier);

    // Store form data in the notifier state before submitting.
    notifier.setFormData(
      shopName: _shopNameController.text.trim(),
      ownerName: _ownerNameController.text.trim(),
      contactNumber: _contactController.text.trim(),
    );

    // Capture storefront photo (Requirement 4.1–4.2).
    final photo = await PhotoService().captureStorefront();
    if (!mounted) return;

    if (photo == null) {
      // User dismissed camera without capturing (Requirement 4.8).
      setState(() => _submitting = false);
      return;
    }

    notifier.setPhoto(photo);

    // Run the full submission pipeline (GPS re-check, geofence, rate-limit,
    // photo upload, DB insert, token persist).
    await notifier.submit();
    if (!mounted) return;

    final state = ref.read(registrationProvider);
    setState(() => _submitting = false);

    if (state.step == RegistrationStep.success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RegistrationSuccessScreen(
            shopName: _shopNameController.text.trim(),
          ),
        ),
      );
    } else if (state.step == RegistrationStep.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.errorMessage ?? 'Submission failed')),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          ref.read(registrationProvider.notifier).cancelFlow();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  children: [
                    // Grab handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Text(
                      'Register Your Shop',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Fill in the details below. All fields are required.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF757575)),
                    ),
                    const SizedBox(height: 24),

                    // Shop Name (Requirement 3.2)
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

                    // Owner Full Name (Requirement 3.3)
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

                    // Contact Number (Requirement 3.4)
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
                    const SizedBox(height: 32),

                    // Next — Take Photo button (Requirement 3.5, 4.1)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB87333),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _submitting ? null : _onNext,
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Next — Take Photo',
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
            );
          },
        ),
      ),
    );
  }
}
