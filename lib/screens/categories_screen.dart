import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/user_preferences_provider.dart';
import '../widgets/category_icon_badge.dart';
import 'add_category_screen.dart';
import 'category_detail_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late List<Category> _categories;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadCategories();
    }
  }

  void _loadCategories() {
    final prefs = context.read<UserPreferencesProvider>();
    final activeIds = prefs.activeCategories.toSet();
    final customMap = {for (final c in prefs.customCategories) c.id: c};
    final builtinIds = Category.categories.map((c) => c.id).toSet();
    _categories = [
      // Built-in categories, using custom overrides (edits) if saved
      ...Category.categories
          .where((c) => activeIds.isEmpty || activeIds.contains(c.id))
          .map((c) => customMap[c.id] ?? c),
      // Pure custom (user-created, not overriding a built-in)
      ...prefs.customCategories.where((c) => !builtinIds.contains(c.id)),
    ];
  }

  void _reloadCategories() {
    if (!mounted) return;
    setState(_loadCategories);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Categories',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                          letterSpacing: -0.7,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_categories.length} ${_categories.length == 1 ? 'category' : 'categories'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Divider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Divider(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    height: 1,
                  ),
                ),

                const SizedBox(height: 9),

                // Reorderable category list
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    buildDefaultDragHandles: false,
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) {
                          final t = CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          ).value;
                          return Transform.scale(
                            scale: 1.0 + 0.02 * t,
                            child: Material(
                              color: Colors.transparent,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.13 * t),
                                      blurRadius: 16 * t,
                                      offset: Offset(0, 6 * t),
                                    ),
                                  ],
                                ),
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: child,
                      );
                    },
                    itemCount: _categories.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _categories.removeAt(oldIndex);
                        _categories.insert(newIndex, item);
                      });
                      context.read<UserPreferencesProvider>().saveCategoryOrder(
                        _categories.map((c) => c.id).toList(),
                      );
                    },
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      return _CategoryListTile(
                        key: ValueKey(category.id),
                        category: category,
                        index: index,
                        onReturn: _reloadCategories,
                      );
                    },
                  ),
                ),
              ],
            ),

            // FAB — add new category
            Positioned(
              right: 24,
              bottom: 24,
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddCategoryScreen(),
                  ),
                ).then((_) => _reloadCategories()),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    LucideIcons.plus,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 28,
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

class _CategoryListTile extends StatefulWidget {
  final Category category;
  final int index;
  final VoidCallback? onReturn;

  const _CategoryListTile({
    required super.key,
    required this.category,
    required this.index,
    this.onReturn,
  });

  @override
  State<_CategoryListTile> createState() => _CategoryListTileState();
}

class _CategoryListTileState extends State<_CategoryListTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryDetailScreen(category: widget.category),
          ),
        ).then((_) {
          if (mounted) setState(() => _pressed = false);
          widget.onReturn?.call();
        });
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _pressed
              ? Theme.of(context).colorScheme.surface
              : Colors.transparent,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Category icon circle
              CategoryIconBadge(
                category: widget.category,
                size: 48,
                iconSize: 22,
              ),

              const SizedBox(width: 14),

              // Name
              Expanded(
                child: Text(
                  widget.category.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),

              // Drag handle
              ReorderableDragStartListener(
                index: widget.index,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    LucideIcons.gripVertical,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
