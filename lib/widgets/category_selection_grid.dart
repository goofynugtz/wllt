import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/models.dart';
import 'category_icon_widget.dart';

/// Two-column grid of toggleable category chips. Shared by onboarding's
/// category picker and the category filter popup so both keep the same look.
class CategorySelectionGrid extends StatelessWidget {
  final List<Category> categories;
  final Set<String> selectedIds;
  final Set<String> lockedIds;
  final ValueChanged<String> onToggle;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry padding;

  /// Clip.none (onboarding's default) lets BoxShadow bleed into inter-cell
  /// gaps without being hard-clipped, but it also lets the last row bleed
  /// past the grid's own bounds into whatever sits below it — pass
  /// Clip.hardEdge when the grid shares a screen with sibling content
  /// underneath (e.g. footer buttons in a bottom sheet).
  final Clip clipBehavior;

  const CategorySelectionGrid({
    super.key,
    required this.categories,
    required this.selectedIds,
    this.lockedIds = const {},
    required this.onToggle,
    this.scrollController,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: scrollController,
      clipBehavior: clipBehavior,
      padding: padding,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 215 / 68,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: categories.length,
      itemBuilder: (context, i) {
        final cat = categories[i];
        return _CategoryChip(
          category: cat,
          isSelected: selectedIds.contains(cat.id),
          isLocked: lockedIds.contains(cat.id),
          onTap: () => onToggle(cat.id),
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final Category category;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.category,
    required this.isSelected,
    this.isLocked = false,
    required this.onTap,
  });

  Color get _color {
    final hex = category.color.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = isLocked ? cs.onSurfaceVariant : _color;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected
              ? cs.surfaceContainerHigh
              : cs.surfaceContainerLow.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? cs.outlineVariant
                : cs.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 12,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        // centerStart: non-positioned children (the Row) are centered
        // vertically and anchored left, matching the 68px card height.
        child: Stack(
          alignment: AlignmentDirectional.centerStart,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accent
                          : accent.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: CategoryIconWidget(
                        category: category,
                        size: 18,
                        color: isSelected ? Colors.white : accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      category.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isLocked
                            ? cs.onSurfaceVariant
                            : (isSelected ? cs.onSurface : cs.onSurfaceVariant),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Always rendered — AnimatedOpacity fades the badge in/out so
            // there is no hard pop when toggling selection.
            Positioned(
              top: 8,
              right: 8,
              child: AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isLocked ? LucideIcons.lock : LucideIcons.check,
                    size: 11,
                    color: Colors.white,
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
