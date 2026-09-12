import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/user_preferences_provider.dart';
import '../utils/helpers.dart';
import 'category_selection_grid.dart';

/// Opens the category filter popup (checkboxes + Select All / Deselect All)
/// that lets the user pick which expense categories show in the spending
/// breakdown views.
Future<void> showCategoryFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const CategoryFilterSheet(),
  );
}

class CategoryFilterSheet extends StatefulWidget {
  const CategoryFilterSheet({super.key});

  /// `activeCategories` is a single flat list shared with income and custom
  /// categories, and an empty list conventionally means "everything active".
  /// This merges just the expense-category subset back in, so saving from
  /// this (expense-only) popup never drops income/custom ids that other
  /// screens still depend on.
  static List<String> mergeSelection({
    required List<String> current,
    required Set<String> selectedExpenseIds,
    required Set<String> allExpenseIds,
    required Set<String> allOtherIds,
  }) {
    final otherActive = current.isEmpty
        ? allOtherIds
        : current.where((id) => !allExpenseIds.contains(id)).toSet();
    return {...otherActive, ...selectedExpenseIds}.toList();
  }

  @override
  State<CategoryFilterSheet> createState() => _CategoryFilterSheetState();
}

class _CategoryFilterSheetState extends State<CategoryFilterSheet> {
  final List<Category> _expenseCategories = Helpers.getExpenseCategories();
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    final active = context.read<UserPreferencesProvider>().activeCategories.toSet();
    _selected = active.isEmpty
        ? _expenseCategories.map((c) => c.id).toSet()
        : _expenseCategories.map((c) => c.id).where(active.contains).toSet();
  }

  void _toggle(String id) => setState(() {
        if (_selected.contains(id)) {
          _selected.remove(id);
        } else {
          _selected.add(id);
        }
      });

  void _selectAll() =>
      setState(() => _selected = _expenseCategories.map((c) => c.id).toSet());

  void _deselectAll() => setState(() => _selected.clear());

  Future<void> _save() async {
    final prefs = context.read<UserPreferencesProvider>();
    final allExpenseIds = _expenseCategories.map((c) => c.id).toSet();
    final allOtherIds = {
      ...Helpers.getIncomeCategories().map((c) => c.id),
      ...prefs.customCategories.map((c) => c.id),
    };
    final merged = CategoryFilterSheet.mergeSelection(
      current: prefs.activeCategories,
      selectedExpenseIds: _selected,
      allExpenseIds: allExpenseIds,
      allOtherIds: allOtherIds,
    );
    await prefs.setCategories(merged);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allSelected = _selected.length == _expenseCategories.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filter Categories',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, color: cs.onSurfaceVariant),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selected.length} selected',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                  GestureDetector(
                    onTap: allSelected ? _deselectAll : _selectAll,
                    child: Text(
                      allSelected ? 'Deselect all' : 'Select all',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: CategorySelectionGrid(
                  categories: _expenseCategories,
                  selectedIds: _selected,
                  onToggle: _toggle,
                  scrollController: scrollController,
                  clipBehavior: Clip.hardEdge,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(color: cs.surface),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _selected.isEmpty ? null : _save,
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
