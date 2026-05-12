import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/shop_provider.dart';

class MunicipalityFilterSheet extends ConsumerStatefulWidget {
  final List<String> places;
  final Map<String, int> shopCounts;

  const MunicipalityFilterSheet({
    super.key,
    required this.places,
    required this.shopCounts,
  });

  @override
  ConsumerState<MunicipalityFilterSheet> createState() =>
      _MunicipalityFilterSheetState();
}

class _MunicipalityFilterSheetState
    extends ConsumerState<MunicipalityFilterSheet> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = ref.read(shopProvider).selectedMunicipality;
  }

  void _apply() {
    ref.read(shopProvider.notifier).setMunicipality(_selected);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Places with shops float to the top; both groups sorted alphabetically.
    final withShops =
        widget.places.where((p) => (widget.shopCounts[p] ?? 0) > 0).toList()
          ..sort();
    final withoutShops =
        widget.places.where((p) => (widget.shopCounts[p] ?? 0) == 0).toList()
          ..sort();

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
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
                      Icons.location_on_outlined,
                      color: Color(0xFFB87333),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Filter by Municipality',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A1B),
                        ),
                      ),
                    ),
                    if (_selected != null)
                      TextButton(
                        onPressed: () => setState(() => _selected = null),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF9E9E9E),
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Clear',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),

              const Divider(height: 1),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    _MunicipalityTile(
                      label: 'All Municipalities',
                      count: widget.shopCounts.values.fold(0, (a, b) => a + b),
                      isSelected: _selected == null,
                      onTap: () => setState(() => _selected = null),
                      showAll: true,
                    ),
                    const SizedBox(height: 4),
                    if (withShops.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 4,
                          top: 12,
                          bottom: 6,
                        ),
                        child: Text(
                          'HAS JUNKSHOPS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade500,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      ...withShops.map(
                        (p) => _MunicipalityTile(
                          label: p,
                          count: widget.shopCounts[p] ?? 0,
                          isSelected: _selected == p,
                          onTap: () => setState(
                            () => _selected = _selected == p ? null : p,
                          ),
                        ),
                      ),
                    ],
                    if (withoutShops.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 4,
                          top: 16,
                          bottom: 6,
                        ),
                        child: Text(
                          'NO LISTINGS YET',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade400,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      ...withoutShops.map(
                        (p) => _MunicipalityTile(
                          label: p,
                          count: 0,
                          isSelected: _selected == p,
                          onTap: () => setState(
                            () => _selected = _selected == p ? null : p,
                          ),
                          muted: true,
                        ),
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
                      _selected == null ? 'Show All' : 'Show $_selected',
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

class _MunicipalityTile extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final bool muted;
  final bool showAll;

  const _MunicipalityTile({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.muted = false,
    this.showAll = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFB87333).withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFB87333) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              showAll ? Icons.public : Icons.location_city_outlined,
              size: 18,
              color: isSelected
                  ? const Color(0xFFB87333)
                  : muted
                  ? const Color(0xFFCCCCCC)
                  : const Color(0xFF9E9E9E),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFFB87333)
                      : muted
                      ? const Color(0xFFBBBBBB)
                      : const Color(0xFF1A1A1B),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFB87333)
                    : count > 0
                    ? const Color(0xFFF5F0EB)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : count > 0
                      ? const Color(0xFFB87333)
                      : const Color(0xFFBBBBBB),
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.check_circle,
                size: 16,
                color: Color(0xFFB87333),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
