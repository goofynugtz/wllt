import 'package:flutter/material.dart';
import '../models/models.dart';
import 'category_icon_widget.dart';

/// A self-contained circular badge that renders a category's colored icon.
///
/// Adapts automatically to light/dark mode:
/// - Light: `category.bg` tinted container + `category.color` icon
/// - Dark:  `category.color` at low opacity container + `category.color` icon
///
/// Replaces all inline "colored circle + CategoryIconWidget" blocks so that
/// every screen stays visually consistent without duplication.
class CategoryIconBadge extends StatelessWidget {
  final Category category;

  /// Diameter of the circular badge.
  final double size;

  /// Size of the icon glyph inside the badge. Defaults to ~45% of [size].
  final double? iconSize;

  const CategoryIconBadge({
    super.key,
    required this.category,
    this.size = 40,
    this.iconSize,
  });

  Color get _accentColor => Color(
        int.parse(category.color.substring(1), radix: 16) + 0xFF000000,
      );

  Color get _bgColor => Color(
        int.parse(category.bg.substring(1), radix: 16) + 0xFF000000,
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerColor =
        isDark ? _accentColor.withValues(alpha: 0.18) : _bgColor;
    final iconColor = _accentColor;
    final resolvedIconSize = iconSize ?? size * 0.45;

    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: containerColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Center(
        child: CategoryIconWidget(
          category: category,
          size: resolvedIconSize,
          color: iconColor,
        ),
      ),
    );
  }
}
