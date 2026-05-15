// OwnerShopManageScreen — lets an approved shop owner manage their shop's
// schedule, accepted materials, and per-material prices.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_shop_repository.dart';
import '../models/junkshop.dart';
import '../providers/reference_data_provider.dart';
import '../providers/supabase_provider.dart';
import '../providers/user_shops_provider.dart';
import '../theme.dart';
import 'shop_location_picker_screen.dart';
import 'package:latlong2/latlong.dart';

// ── Material list (matches kMaterialToPricingKey keys) ───────────────────────

const _kAllMaterials = [
  'Steel',
  'Tin Cans',
  'Metal Roofing',
  'Aluminum',
  'Copper',
  'Brass',
  'Stainless Steel',
  'Plastics',
  'Paper',
  'Cardboard',
  'Glass Bottles (2x2 Gin)',
  'Glass Bottles (Longneck Emperador)',
  'Glass Bottles (Ketchup)',
  'Motherboard',
  'IC',
  'TV Board',
];

// ── Screen ────────────────────────────────────────────────────────────────────

class OwnerShopManageScreen extends ConsumerStatefulWidget {
  final JunkshopModel shop;

  const OwnerShopManageScreen({super.key, required this.shop});

  @override
  ConsumerState<OwnerShopManageScreen> createState() =>
      _OwnerShopManageScreenState();
}

class _OwnerShopManageScreenState extends ConsumerState<OwnerShopManageScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ownerNameCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _scheduleCtrl;

  // Materials: which are selected + their price entries
  late Set<String> _selectedMaterials;
  late Map<String, _PriceEntry> _priceEntries;

  bool _saving = false;

  // Per-section edit states
  bool _isInfoEditing = false;
  bool _isMaterialsEditing = false;
  bool _isScheduleEditing = false;

  LatLng? _updatedLocation;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.shop.name);
    _ownerNameCtrl = TextEditingController(text: widget.shop.ownerName);
    _contactCtrl = TextEditingController(text: widget.shop.contactNumber);
    _scheduleCtrl = TextEditingController(text: widget.shop.schedule);

    // ── DEBUG ──────────────────────────────────────────────────────────────
    debugPrint(
      '[OwnerShopManageScreen.initState] shop="${widget.shop.name}" '
      'status=${widget.shop.status} '
      'acceptedMaterials=${widget.shop.acceptedMaterials} '
      'pricesCount=${widget.shop.prices.length} '
      'prices=${widget.shop.prices.map((p) => "${p.material}:${p.min}-${p.max}").toList()}',
    );
    // ──────────────────────────────────────────────────────────────────────

    _selectedMaterials = Set<String>.from(widget.shop.acceptedMaterials);

    // Pre-populate price entries from existing shop data
    _priceEntries = {};
    for (final p in widget.shop.prices) {
      _priceEntries[p.material] = _PriceEntry(
        minCtrl: TextEditingController(text: p.min != null ? _fmt(p.min!) : ''),
        maxCtrl: TextEditingController(text: p.max != null ? _fmt(p.max!) : ''),
        unit: p.unit,
      );
    }
    // Ensure every selected material has an entry
    for (final m in _selectedMaterials) {
      _priceEntries.putIfAbsent(
        m,
        () => _PriceEntry(
          minCtrl: TextEditingController(),
          maxCtrl: TextEditingController(),
          unit: 'kg',
        ),
      );
    }

    // Default: nothing is editable unless resubmitting a rejected shop
    if (widget.shop.status == ShopStatus.rejected) {
      _isInfoEditing = true;
      _isMaterialsEditing = true;
      _isScheduleEditing = true;
    }
  }

  String _fmt(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _contactCtrl.dispose();
    _scheduleCtrl.dispose();
    for (final e in _priceEntries.values) {
      e.minCtrl.dispose();
      e.maxCtrl.dispose();
    }
    super.dispose();
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final client = ref.read(supabaseProvider);
      final repo = SupabaseShopRepository(client);

      // Build prices list from selected materials
      final prices = <Map<String, dynamic>>[];
      for (final material in _selectedMaterials) {
        final entry = _priceEntries[material];
        if (entry == null) continue;
        final min = double.tryParse(entry.minCtrl.text.trim());
        final max = double.tryParse(entry.maxCtrl.text.trim());
        prices.add({
          'material': material,
          'unit': entry.unit,
          if (min != null) 'min': min,
          if (max != null) 'max': max,
        });
      }

      final isRejected = widget.shop.status == ShopStatus.rejected;

      await repo.updateShopOperational(
        shopId: widget.shop.id,
        name: _nameCtrl.text.trim(),
        ownerName: _ownerNameCtrl.text.trim(),
        contactNumber: _contactCtrl.text.trim(),
        schedule: _scheduleCtrl.text.trim(),
        acceptedMaterials: _selectedMaterials.toList(),
        prices: prices,
        isResubmitting: isRejected,
        latitude: _updatedLocation?.latitude,
        longitude: _updatedLocation?.longitude,
      );

      // Invalidate so MyShopsScreen refreshes
      ref.invalidate(userShopsProvider);

      setState(() {
        _isInfoEditing = false;
        _isMaterialsEditing = false;
        _isScheduleEditing = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRejected
                ? 'Shop resubmitted successfully.'
                : 'Shop updated successfully.',
          ),
          backgroundColor: AppTheme.primary,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Save failed: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
          action: SnackBarAction(label: 'Retry', onPressed: _save),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isPending = widget.shop.status == ShopStatus.pending;
    final isApproved = widget.shop.status == ShopStatus.verified || widget.shop.status == ShopStatus.active;
    final isRejected = widget.shop.status == ShopStatus.rejected;
    final isAnyEditing =
        _isInfoEditing ||
        _isMaterialsEditing ||
        _isScheduleEditing ||
        _updatedLocation != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          isAnyEditing ? 'Edit Shop' : widget.shop.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        actions: [const SizedBox(width: 8)],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ── Basic Info ─────────────────────────────────────────────
                  _SectionCard(
                    title: 'Shop Information',
                    icon: Icons.storefront_outlined,
                    showEdit: isApproved && !_isInfoEditing,
                    onEdit: () => setState(() => _isInfoEditing = true),
                    onSave: _isInfoEditing ? _save : null,
                    onCancel: _isInfoEditing
                        ? () => setState(() => _isInfoEditing = false)
                        : null,
                    children: [
                      _buildTextField(
                        controller: _nameCtrl,
                        label: 'Shop Name',
                        isEditable: _isInfoEditing,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _ownerNameCtrl,
                        label: 'Owner Name',
                        isEditable: _isInfoEditing,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _contactCtrl,
                        label: 'Contact Number',
                        isEditable: _isInfoEditing,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _SectionCard(
                    title: 'Schedule',
                    icon: Icons.access_time_outlined,
                    showEdit: isApproved && !_isScheduleEditing,
                    onEdit: () => setState(() => _isScheduleEditing = true),
                    onSave: _isScheduleEditing ? _save : null,
                    onCancel: _isScheduleEditing
                        ? () => setState(() => _isScheduleEditing = false)
                        : null,
                    children: [
                      Text(
                        _scheduleCtrl.text.isEmpty
                            ? 'Not set'
                            : _scheduleCtrl.text,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (_isScheduleEditing) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _showSchedulePicker,
                            icon: const Icon(
                              Icons.edit_calendar_outlined,
                              size: 18,
                            ),
                            label: const Text('Change Schedule'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              side: const BorderSide(color: AppTheme.primary),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Materials & Prices ─────────────────────────────────────
                  _SectionCard(
                    title: 'Accepted Materials & Prices',
                    icon: Icons.recycling_outlined,
                    subtitle:
                        'Update what you buy and your current price range.',
                    showEdit: isApproved && !_isMaterialsEditing,
                    onEdit: () => setState(() => _isMaterialsEditing = true),
                    onSave: _isMaterialsEditing ? _save : null,
                    onCancel: _isMaterialsEditing
                        ? () => setState(() => _isMaterialsEditing = false)
                        : null,
                    children: [
                      // VIEW MODE: render directly from shop data — no need to
                      // cross-reference the materialsProvider reference list.
                      if (!_isMaterialsEditing) ...[
                        if (_selectedMaterials.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No materials selected yet.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  mainAxisExtent: 70,
                                ),
                            itemCount: _selectedMaterials.length,
                            itemBuilder: (context, index) {
                              final name = _selectedMaterials.elementAt(index);
                              final entry = _priceEntries[name];

                              String priceStr = 'Price not set';
                              if (entry != null &&
                                  entry.minCtrl.text.isNotEmpty) {
                                priceStr = '₱${entry.minCtrl.text}';
                                if (entry.maxCtrl.text.isNotEmpty) {
                                  priceStr += ' – ₱${entry.maxCtrl.text}';
                                }
                                priceStr += ' / ${entry.unit}';
                              }

                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      priceStr,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ] else
                        ref
                            .watch(materialsProvider)
                            .when(
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (e, _) =>
                                  Text('Error loading materials: $e'),
                              data: (materials) {
                                // EDIT MODE: Group materials by category name and show full list
                                final grouped =
                                    <String, List<Map<String, dynamic>>>{};
                                for (final mat in materials) {
                                  final catName =
                                      (mat['categories']
                                              as Map<String, dynamic>?)?['name']
                                          as String? ??
                                      'Other';
                                  grouped
                                      .putIfAbsent(catName, () => [])
                                      .add(mat);
                                }

                                return Column(
                                  children: grouped.entries.map((entry) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 16,
                                            bottom: 8,
                                          ),
                                          child: Text(
                                            entry.key.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.grey.shade500,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ),
                                        ...entry.value.map((mat) {
                                          final materialName =
                                              mat['name'] as String;
                                          final isSelected = _selectedMaterials
                                              .contains(materialName);
                                          final priceEntry =
                                              _priceEntries[materialName];
                                          return _MaterialPriceTile(
                                            material: materialName,
                                            isSelected: isSelected,
                                            isEditable: _isMaterialsEditing,
                                            entry: priceEntry,
                                            onToggle: (val) {
                                              setState(() {
                                                if (val) {
                                                  _selectedMaterials.add(
                                                    materialName,
                                                  );
                                                  _priceEntries.putIfAbsent(
                                                    materialName,
                                                    () => _PriceEntry(
                                                      minCtrl:
                                                          TextEditingController(),
                                                      maxCtrl:
                                                          TextEditingController(),
                                                      unit: 'kg',
                                                    ),
                                                  );
                                                } else {
                                                  _selectedMaterials.remove(
                                                    materialName,
                                                  );
                                                }
                                              });
                                            },
                                            onUnitChanged: (unit) {
                                              setState(() {
                                                if (priceEntry != null)
                                                  priceEntry.unit = unit;
                                              });
                                            },
                                          );
                                        }),
                                      ],
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  if (isApproved || isRejected)
                    _SectionCard(
                      title: 'Shop Location',
                      icon: Icons.location_on_outlined,
                      showEdit: false,
                      onSave: _updatedLocation != null ? _save : null,
                      onCancel: _updatedLocation != null
                          ? () => setState(() => _updatedLocation = null)
                          : null,
                      children: [
                        const Text(
                          'Update the map pin if your shop has moved or the location is inaccurate.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final newLoc = await Navigator.push<LatLng>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ShopLocationPickerScreen(
                                    initialLocation: LatLng(
                                      widget.shop.lat,
                                      widget.shop.lng,
                                    ),
                                  ),
                                ),
                              );
                              if (newLoc != null) {
                                setState(() => _updatedLocation = newLoc);
                              }
                            },
                            icon: const Icon(Icons.map_outlined, size: 18),
                            label: Text(
                              _updatedLocation == null
                                  ? 'Update Location'
                                  : 'Location Updated',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              side: const BorderSide(color: AppTheme.primary),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),

                  if (isAnyEditing) ...[
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isRejected ? 'Resubmit Shop' : 'Save Changes',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSchedulePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _SchedulePickerContent(
          initialValue: _scheduleCtrl.text,
          onChanged: (val) {
            setState(() => _scheduleCtrl.text = val);
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required bool isEditable,
    String? hint,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      readOnly: !isEditable,
    );
  }
}

// ── Price entry state ─────────────────────────────────────────────────────────

class _PriceEntry {
  final TextEditingController minCtrl;
  final TextEditingController maxCtrl;
  String unit;

  _PriceEntry({
    required this.minCtrl,
    required this.maxCtrl,
    required this.unit,
  });
}

// ── Material + price tile ─────────────────────────────────────────────────────

class _MaterialPriceTile extends StatelessWidget {
  final String material;
  final bool isSelected;
  final bool isEditable;
  final _PriceEntry? entry;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onUnitChanged;

  const _MaterialPriceTile({
    required this.material,
    required this.isSelected,
    required this.isEditable,
    required this.entry,
    required this.onToggle,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: isEditable ? () => onToggle(!isSelected) : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primary
                          : Colors.grey.shade400,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    material,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isSelected
                          ? AppTheme.textPrimary
                          : AppTheme.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isSelected && entry != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 34, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: _PriceField(
                    controller: entry!.minCtrl,
                    label: 'Min ₱',
                    enabled: isEditable,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PriceField(
                    controller: entry!.maxCtrl,
                    label: 'Max ₱',
                    enabled: isEditable,
                  ),
                ),
                const SizedBox(width: 8),
                // Unit toggle
                GestureDetector(
                  onTap: isEditable
                      ? () =>
                            onUnitChanged(entry!.unit == 'kg' ? 'piece' : 'kg')
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isEditable
                          ? AppTheme.secondary.withValues(alpha: 0.1)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isEditable
                            ? AppTheme.secondary.withValues(alpha: 0.3)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Text(
                      entry!.unit,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isEditable
                            ? AppTheme.secondary
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Divider(height: 1, color: Colors.grey.shade100),
      ],
    );
  }
}

class _PriceField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool enabled;

  const _PriceField({
    required this.controller,
    required this.label,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primary),
        ),
      ),
      readOnly: !enabled,
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final List<Widget> children;
  final VoidCallback? onEdit;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;
  final bool showEdit;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.subtitle,
    required this.children,
    this.onEdit,
    this.onSave,
    this.onCancel,
    this.showEdit = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (showEdit)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: onEdit,
                    color: AppTheme.primary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (onCancel != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onCancel,
                    color: Colors.grey,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (onSave != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.check, size: 18),
                    onPressed: onSave,
                    color: AppTheme.primary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _SchedulePickerContent extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;

  const _SchedulePickerContent({
    required this.initialValue,
    required this.onChanged,
  });

  @override
  State<_SchedulePickerContent> createState() => _SchedulePickerContentState();
}

class _SchedulePickerContentState extends State<_SchedulePickerContent> {
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final Set<int> _activeDays = {};
  TimeOfDay _openTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 17, minute: 0);

  @override
  void initState() {
    super.initState();
    _parseInitial();
  }

  void _parseInitial() {
    try {
      final parts = widget.initialValue.split(':');
      if (parts.length < 2) {
        _activeDays.addAll([0, 1, 2, 3, 4, 5]);
        return;
      }

      final daysPart = parts[0];
      for (int i = 0; i < _days.length; i++) {
        if (daysPart.contains(_days[i])) _activeDays.add(i);
      }

      final times = parts[1].split('–');
      if (times.length == 2) {
        _openTime = _parseTime(times[0].trim()) ?? _openTime;
        _closeTime = _parseTime(times[1].trim()) ?? _closeTime;
      }
    } catch (_) {
      _activeDays.addAll([0, 1, 2, 3, 4, 5]);
    }
  }

  TimeOfDay? _parseTime(String s) {
    try {
      final match = RegExp(
        r'(\d+):(\d+)\s*(AM|PM)',
        caseSensitive: false,
      ).firstMatch(s);
      if (match == null) return null;
      int hour = int.parse(match.group(1)!);
      final int min = int.parse(match.group(2)!);
      final isPm = match.group(3)!.toUpperCase() == 'PM';
      if (isPm && hour < 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: min);
    } catch (_) {
      return null;
    }
  }

  String _fmt(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final min = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$min $period';
  }

  String _buildDayRanges() {
    if (_activeDays.isEmpty) return '';
    final sorted = _activeDays.toList()..sort();
    final ranges = <String>[];
    int start = sorted[0];
    int prev = sorted[0];

    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i] == prev + 1) {
        prev = sorted[i];
      } else {
        ranges.add(
          start == prev ? _days[start] : '${_days[start]}–${_days[prev]}',
        );
        start = sorted[i];
        prev = sorted[i];
      }
    }
    ranges.add(start == prev ? _days[start] : '${_days[start]}–${_days[prev]}');
    return ranges.join(', ');
  }

  void _sync() {
    if (_activeDays.isEmpty) return;
    widget.onChanged(
      '${_buildDayRanges()}: ${_fmt(_openTime)} – ${_fmt(_closeTime)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Operating Schedule',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'OPEN DAYS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_days.length, (i) {
              final active = _activeDays.contains(i);
              return GestureDetector(
                onTap: () {
                  setState(
                    () => active ? _activeDays.remove(i) : _activeDays.add(i),
                  );
                  _sync();
                },
                child: Container(
                  width: 40,
                  height: 48,
                  decoration: BoxDecoration(
                    color: active ? AppTheme.primary : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      _days[i].substring(0, 1),
                      style: TextStyle(
                        color: active ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          const Text(
            'OPERATING HOURS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TimeTile(
                  label: 'Open',
                  time: _fmt(_openTime),
                  onTap: () => _pickTime(true),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
              ),
              Expanded(
                child: _TimeTile(
                  label: 'Close',
                  time: _fmt(_closeTime),
                  onTap: () => _pickTime(false),
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Confirm Schedule',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }

  Future<void> _pickTime(bool isOpen) async {
    final t = await showTimePicker(
      context: context,
      initialTime: isOpen ? _openTime : _closeTime,
    );
    if (t != null) {
      setState(() => isOpen ? _openTime = t : _closeTime = t);
      _sync();
    }
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;
  const _TimeTile({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
