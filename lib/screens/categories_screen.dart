import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon_widget.dart';
import 'category_detail_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late List<Category> _categories;

  @override
  void initState() {
    super.initState();
    _categories = List.of(Category.categories);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F6),
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
                      const Text(
                        'Categories',
                        style: TextStyle(
                                                    fontSize: 28,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.7,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_categories.length} categories',
                        style: const TextStyle(
                                                    fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Divider
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Divider(color: AppTheme.borderColor, height: 1),
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
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withOpacity(0.13 * t),
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
                    },
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      return _CategoryListTile(
                        key: ValueKey(category.id),
                        category: category,
                        index: index,
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
                onTap: () {
                  // TODO: open add-category sheet
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.textPrimary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.28),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    LucideIcons.plus,
                    color: Colors.white,
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

  const _CategoryListTile({
    required super.key,
    required this.category,
    required this.index,
  });

  @override
  State<_CategoryListTile> createState() => _CategoryListTileState();
}

class _CategoryListTileState extends State<_CategoryListTile> {
  bool _pressed = false;

  Color get _accentColor => Color(
        int.parse(widget.category.color.substring(1), radix: 16) + 0xFF000000,
      );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryDetailScreen(category: widget.category),
          ),
        );
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                    color: _accentColor.withOpacity(0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
          color: _pressed ? Colors.white : const Color(0xFFFFF8F6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Category icon circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _accentColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Center(
                  child: CategoryIconWidget(
                    category: widget.category,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Name
              Expanded(
                child: Text(
                  widget.category.name,
                  style: const TextStyle(
                                        fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),

              // Drag handle
              ReorderableDragStartListener(
                index: widget.index,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    LucideIcons.gripVertical,
                    size: 18,
                    color: AppTheme.textTertiary,
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
