import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/shop_provider.dart';

class MaterialFilterSheet extends ConsumerStatefulWidget {
  const MaterialFilterSheet({super.key});

  @override
  ConsumerState<MaterialFilterSheet> createState() =>
      _MaterialFilterSheetState();
}

class _MaterialFilterSheetState extends ConsumerState<MaterialFilterSheet> {
  late Set<String> _selected;

  // Names match accepted_materials values in junkshops.json.
  static const Map<String, List<String>> _categories = {
    'Ferrous Metals': ['Steel', 'Tin Cans', 'Metal Roofing'],
    'Non-Ferrous Metals': ['Aluminum', 'Copper', 'Brass', 'Stainless Steel'],
    'Recyclables': ['Plastics', 'Paper', 'Cardboard'],
    'Glass': [
      'Glass Bottles (2x2 Gin)',
      'Glass Bottles (Longneck Emperador)',
      'Glass Bottles (Ketchup)',
    ],
    'Electronics': ['Motherboard', 'IC', 'TV Board'],
  };

  @override
  void initState() {
    super.initState();
    _selected = Set.from(ref.read(shopProvider).selectedMaterials);
  }

  void _toggle(String material) {
    setState(() {
      if (_selected.contains(material)) {
        _selected.remove(material);
      } else {
        _selected.add(material);
      }
    });
  }

  void _apply() {
    ref.read(shopProvider.notifier).setSelectedMaterials(Set.from(_selected));
    Navigator.of(context).pop();
  }

  void _clear() => setState(() => _selected.clear());

  @override
  Widget build(BuildContext context) {
    // Filtered to materials that actually exist in the loaded shop data.
    final allMaterials = ref.watch(allMaterialsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDDDDD),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.filter_list,
                      color: Color(0xFFB87333),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Filter by Material',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1B),
                        ),
                      ),
                    ),
                    if (_selected.isNotEmpty)
                      TextButton(
                        onPressed: _clear,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF9E9E9E),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Clear all',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),

              if (_selected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    '${_selected.length} material${_selected.length == 1 ? '' : 's'} selected'
                    ' — showing shops that accept all of them',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB87333),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

              const Divider(height: 1),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  children: [
                    for (final entry in _categories.entries)
                      if (entry.value.any((m) => allMaterials.contains(m))) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 8),
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB87333),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: entry.value
                              .where((m) => allMaterials.contains(m))
                              .map(
                                (m) => _MaterialToggle(
                                  label: m,
                                  isSelected: _selected.contains(m),
                                  onTap: () => _toggle(m),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                  ],
                ),
              ),

              Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  MediaQuery.of(context).padding.bottom + 12,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Color(0xFFEEEEEE), width: 1),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _selected.isEmpty
                          ? 'Show All Shops'
                          : 'Apply Filter (${_selected.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MaterialToggle extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MaterialToggle({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFB87333) : const Color(0xFFF5F0EB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFB87333)
                : const Color(0xFFE0C9A6),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 13, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF7A4F1E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
