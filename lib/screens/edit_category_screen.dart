import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/user_preferences_provider.dart';
import '../widgets/category_icon_widget.dart';

class EditCategoryScreen extends StatefulWidget {
  final Category category;

  const EditCategoryScreen({super.key, required this.category});

  @override
  State<EditCategoryScreen> createState() => _EditCategoryScreenState();
}

class _EditCategoryScreenState extends State<EditCategoryScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _budgetController;
  late String _selectedColor;
  late IconData _selectedIcon;

  static const _palette = [
    '#EBA9A9', '#E2B932', '#74A1DB', '#9D85E5', '#70C01F', '#86D9BC', '#8FC9E2',
    '#F4A261', '#E76F51', '#2A9D8F', '#FFB703', '#C77DFF', '#06D6A0', '#FB8500',
    '#FF6B6B', '#4CC9F0', '#A8DADC', '#E63946', '#457B9D', '#1D3557',
  ];

  static const _icons = [
    // Shopping & Finance
    LucideIcons.shoppingBag,  LucideIcons.shoppingCart, LucideIcons.creditCard,
    LucideIcons.wallet,       LucideIcons.banknote,     LucideIcons.coins,
    LucideIcons.receipt,      LucideIcons.tag,          LucideIcons.store,
    LucideIcons.gift,         LucideIcons.package,      LucideIcons.landmark,
    LucideIcons.indianRupee,  LucideIcons.piggyBank,
    // Work & Tech
    LucideIcons.briefcase,    LucideIcons.laptop,
    LucideIcons.monitor,      LucideIcons.cpu,          LucideIcons.printer,
    LucideIcons.mail,         LucideIcons.phone,        LucideIcons.smartphone,
    LucideIcons.building,     LucideIcons.building2,
    // Food & Drink
    LucideIcons.coffee,       LucideIcons.utensils,
    LucideIcons.pizza,        LucideIcons.beer,         LucideIcons.wine,
    LucideIcons.apple,        LucideIcons.banana,       LucideIcons.egg,
    LucideIcons.cookie,       LucideIcons.candy,        LucideIcons.fish,
    LucideIcons.milk,         LucideIcons.drumstick,    LucideIcons.cake,
    LucideIcons.beef,         LucideIcons.iceCream,     LucideIcons.croissant,
    LucideIcons.sandwich,
    // Transport
    LucideIcons.car,          LucideIcons.bus,
    LucideIcons.bike,         LucideIcons.plane,        LucideIcons.train,
    LucideIcons.ship,         LucideIcons.truck,        LucideIcons.fuel,
    LucideIcons.navigation,
    // Health & Fitness
    LucideIcons.activity,     LucideIcons.dumbbell,
    LucideIcons.heartPulse,   LucideIcons.stethoscope,  LucideIcons.pill,
    LucideIcons.thermometer,  LucideIcons.cross,        LucideIcons.baby,
    LucideIcons.heart,
    // Entertainment
    LucideIcons.film,         LucideIcons.music,
    LucideIcons.headphones,   LucideIcons.camera,       LucideIcons.mic,
    LucideIcons.gamepad2,     LucideIcons.tv,           LucideIcons.star,
    LucideIcons.trophy,       LucideIcons.award,
    // Home & Utilities
    LucideIcons.home,         LucideIcons.lamp,
    LucideIcons.armchair,     LucideIcons.bed,          LucideIcons.bath,
    LucideIcons.wrench,       LucideIcons.hammer,       LucideIcons.plug,
    LucideIcons.zap,          LucideIcons.wifi,
    // Education & Knowledge
    LucideIcons.bookOpen,     LucideIcons.graduationCap,
    LucideIcons.library,      LucideIcons.microscope,   LucideIcons.pencil,
    LucideIcons.school,       LucideIcons.newspaper,
    // Travel & Outdoors
    LucideIcons.luggage,      LucideIcons.hotel,
    LucideIcons.mapPin,       LucideIcons.compass,      LucideIcons.globe,
    LucideIcons.flag,         LucideIcons.mountain,     LucideIcons.sun,
    LucideIcons.umbrella,
    // Nature & Misc
    LucideIcons.gem,          LucideIcons.diamond,
    LucideIcons.crown,        LucideIcons.leaf,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category.name);
    _selectedColor = widget.category.color.toUpperCase();
    _selectedIcon = widget.category.lucideIcon ?? LucideIcons.tag;

    final budget = Budget.budgets.cast<Budget?>().firstWhere(
      (b) => b?.categoryId == widget.category.id,
      orElse: () => null,
    );
    _budgetController = TextEditingController(
      text: budget != null ? budget.budget.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) => Color(
        int.parse(hex.replaceFirst('#', ''), radix: 16) + 0xFF000000,
      );

  Future<void> _deleteCategory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Delete "${widget.category.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context
        .read<UserPreferencesProvider>()
        .deleteCustomCategory(widget.category.id);
    if (mounted) Navigator.of(context).pop('deleted');
  }

  Future<void> _saveCategory() async {
    final name = _nameController.text.trim();
    final updated = Category(
      id: widget.category.id,
      name: name.isEmpty ? widget.category.name : name,
      lucideIcon: _selectedIcon,
      color: _selectedColor,
      bg: widget.category.bg.isNotEmpty ? widget.category.bg : _selectedColor,
    );
    await context.read<UserPreferencesProvider>().saveCustomCategory(updated);
    if (mounted) Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accentColor = _parseColor(_selectedColor);

    final previewCategory = Category(
      id: widget.category.id,
      name: _nameController.text,
      lucideIcon: _selectedIcon,
      color: _selectedColor,
      bg: widget.category.bg,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          LucideIcons.chevronLeft,
                          size: 22,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      'Edit Category',
                      style: TextStyle(
                        fontSize: 16,
                        color: cs.onSurface,
                      ),
                    ),
                    GestureDetector(
                      onTap: _saveCategory,
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: cs.onSurface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.check, size: 14, color: cs.surface),
                            const SizedBox(width: 6),
                            Text(
                              'Save',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: cs.surface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Scrollable body ────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Live preview ───────────────────────────────────────
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: accentColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.12),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: CategoryIconWidget(
                                  category: previewCategory,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _nameController.text.isEmpty
                                  ? widget.category.name
                                  : _nameController.text,
                              style: TextStyle(
                                fontSize: 18,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Category Name ──────────────────────────────────────
                    _SectionLabel('Category Name'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _nameController,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(
                          fontSize: 17,
                          color: cs.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Category name',
                          hintStyle: TextStyle(
                            fontSize: 17,
                            color: cs.onSurfaceVariant,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Color picker ───────────────────────────────────────
                    _SectionLabel('Color'),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 7,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      children: _palette.map((hex) {
                        final isSelected =
                            hex.toUpperCase() == _selectedColor.toUpperCase();
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedColor = hex.toUpperCase()),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _parseColor(hex),
                              shape: BoxShape.circle,
                            ),
                            child: isSelected
                                ? const Icon(
                                    LucideIcons.check,
                                    size: 15,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // ── Icon picker ────────────────────────────────────────
                    _SectionLabel('Icon'),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 6,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: _icons.map((icon) {
                        final isSelected = icon == _selectedIcon;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedIcon = icon),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            decoration: BoxDecoration(
                              color: isSelected ? accentColor : cs.surface,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected
                                      ? accentColor.withOpacity(0.30)
                                      : Colors.black.withOpacity(0.07),
                                  blurRadius: isSelected ? 10 : 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                icon,
                                size: 20,
                                color: isSelected
                                    ? Colors.white
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // ── Monthly Budget ─────────────────────────────────────
                    Row(
                      children: [
                        _SectionLabel('Monthly Budget'),
                        const SizedBox(width: 6),
                        Text(
                          '(optional)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 18),
                            child: Icon(
                              LucideIcons.indianRupee,
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _budgetController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: TextStyle(
                                fontSize: 17,
                                color: cs.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText: '0',
                                hintStyle: TextStyle(
                                  fontSize: 17,
                                  color: cs.onSurfaceVariant,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        'Set a monthly spending limit for this category',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Save Changes ───────────────────────────────────────
                    GestureDetector(
                      onTap: _saveCategory,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: cs.onSurface,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.20),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.check, size: 20, color: cs.surface),
                            const SizedBox(width: 8),
                            Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: cs.surface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Delete Category ────────────────────────────────────
                    GestureDetector(
                      onTap: _deleteCategory,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.trash2, size: 20, color: Colors.red),
                            const SizedBox(width: 8),
                            Text(
                              'Delete Category',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
      ),
    );
  }
}
