import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/models.dart';

/// Renders a category's icon as either an SVG asset or a Lucide icon.
/// The caller controls size and color — this widget only renders the icon shape.
class CategoryIconWidget extends StatelessWidget {
  final Category category;
  final double size;
  final Color color;

  const CategoryIconWidget({
    super.key,
    required this.category,
    this.size = 18,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (category.isLucideIcon) {
      return Icon(category.lucideIcon, size: size, color: color);
    }
    return SvgPicture.asset(
      category.iconPath!,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
