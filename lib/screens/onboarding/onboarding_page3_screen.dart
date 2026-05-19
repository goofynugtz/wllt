import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/user_preferences_provider.dart';
import '../../widgets/category_icon_widget.dart';
import 'onboarding_shared_widgets.dart';

// Shared horizontal inset used by header, counter row, and grid — keeps all
// content edges visually flush.
const double _kHPad = 24.0;

class OnboardingPage3Screen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onGetStarted;

  const OnboardingPage3Screen({
    super.key,
    required this.onBack,
    required this.onGetStarted,
  });

  @override
  State<OnboardingPage3Screen> createState() => _OnboardingPage3ScreenState();
}

class _OnboardingPage3ScreenState extends State<OnboardingPage3Screen> {
  late Set<String> _selected;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-select first 8 categories (matches the Figma design's default state)
    _selected = Category.categories.take(8).map((c) => c.id).toSet();
  }

  void _toggle(String id) => setState(() {
        if (_selected.contains(id)) {
          _selected.remove(id);
        } else {
          _selected.add(id);
        }
      });

  void _selectAll() => setState(() {
        _selected = Category.categories.map((c) => c.id).toSet();
      });

  void _deselectAll() => setState(() => _selected.clear());

  Future<void> _handleGetStarted() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    final prefs = context.read<UserPreferencesProvider>();
    await prefs.setCategories(_selected.toList());
    if (!mounted) return;
    setState(() => _isLoading = false);
    widget.onGetStarted();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isOffline =
        context.read<UserPreferencesProvider>().authMode == 'offline';

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Fixed width matches the "3 of 3" side so the bar is
                  // truly centered on screen.
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(LucideIcons.chevronLeft),
                      onPressed: widget.onBack,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OnboardingProgressBar(
                      current: 2,
                      total: isOffline ? 3 : 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 40,
                    child: Text(
                      isOffline ? '2 of 3' : '2 of 2',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // ── Heading — same _kHPad as the grid below ───────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kHPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose your categories',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.65,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select the categories you use most. You can always add or remove them later.',
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                      height: 1.43,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Counter row — same _kHPad ─────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kHPad),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurface,
                      ),
                      children: [
                        TextSpan(
                          text: '${_selected.length}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: ' selected',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _selected.length == Category.categories.length
                        ? _deselectAll
                        : _selectAll,
                    child: Text(
                      _selected.length == Category.categories.length
                          ? 'Deselect all'
                          : 'Select all',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // ── Category grid — same _kHPad ───────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _kHPad),
                child: GridView.builder(
                  // Clip.none lets BoxShadow bleed into inter-cell gaps and
                  // past the grid edges without being hard-clipped.
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 215 / 68,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: Category.categories.length,
                  itemBuilder: (context, i) {
                    final cat = Category.categories[i];
                    return _CategoryChip(
                      category: cat,
                      isSelected: _selected.contains(cat.id),
                      onTap: () => _toggle(cat.id),
                    );
                  },
                ),
              ),
            ),
            // ── Get Started button ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 8, 30, 24),
              child: Opacity(
                opacity: (_selected.isEmpty || _isLoading) ? 0.4 : 1.0,
                child: GestureDetector(
                  onTap: (_selected.isEmpty || _isLoading)
                      ? null
                      : _handleGetStarted,
                  child: Builder(
                    builder: (context) {
                      final cs = Theme.of(context).colorScheme;
                      return Container(
                        height: 64,
                        decoration: BoxDecoration(
                          color: cs.inverseSurface,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 20,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.sparkles,
                                        size: 18, color: cs.onInverseSurface),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Get Started',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: cs.onInverseSurface,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      );
                    },
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

class _CategoryChip extends StatelessWidget {
  final Category category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  Color get _color {
    final hex = category.color.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                          ? _color
                          : _color.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: CategoryIconWidget(
                        category: category,
                        size: 18,
                        color: isSelected ? Colors.white : _color,
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
                        color: isSelected ? cs.onSurface : cs.onSurfaceVariant,
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
                    color: _color,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.check,
                      size: 11, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
