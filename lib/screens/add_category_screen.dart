import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/user_preferences_provider.dart';

class AddCategoryScreen extends StatefulWidget {
  const AddCategoryScreen({super.key});

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _budgetController;
  String _selectedColor = '#EBA9A9';
  IconData? _selectedIcon;

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty && _selectedIcon != null;

  Future<void> _saveCategory() async {
    if (!_canSave) return;
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final accent = _parseColor(_selectedColor);
    final category = Category(
      id: id,
      name: _nameController.text.trim(),
      lucideIcon: _selectedIcon,
      color: _selectedColor,
      bg: _colorToHex(_bgColor(accent)),
    );
    await context.read<UserPreferencesProvider>().saveCustomCategory(category);
    if (mounted) Navigator.of(context).pop();
  }

  static const _palette = [
    '#EBA9A9', '#E2B932', '#74A1DB', '#9D85E5', '#70C01F', '#86D9BC', '#8FC9E2',
    '#F4A261', '#E76F51', '#2A9D8F', '#FFB703', '#C77DFF', '#06D6A0', '#FB8500',
    '#FF6B6B', '#4CC9F0', '#A8DADC', '#E63946', '#457B9D', '#1D3557',
  ];

  static const _icons = [
    LucideIcons.shoppingBag,  LucideIcons.shoppingCart, LucideIcons.creditCard,
    LucideIcons.wallet,       LucideIcons.banknote,     LucideIcons.coins,
    LucideIcons.receipt,      LucideIcons.tag,          LucideIcons.store,
    LucideIcons.gift,         LucideIcons.package,      LucideIcons.landmark,
    LucideIcons.indianRupee,  LucideIcons.piggyBank,
    LucideIcons.briefcase,    LucideIcons.laptop,
    LucideIcons.monitor,      LucideIcons.cpu,          LucideIcons.printer,
    LucideIcons.mail,         LucideIcons.phone,        LucideIcons.smartphone,
    LucideIcons.building,     LucideIcons.building2,
    LucideIcons.coffee,       LucideIcons.utensils,
    LucideIcons.pizza,        LucideIcons.beer,         LucideIcons.wine,
    LucideIcons.apple,        LucideIcons.banana,       LucideIcons.egg,
    LucideIcons.cookie,       LucideIcons.candy,        LucideIcons.fish,
    LucideIcons.milk,         LucideIcons.drumstick,    LucideIcons.cake,
    LucideIcons.beef,         LucideIcons.iceCream,     LucideIcons.croissant,
    LucideIcons.sandwich,
    LucideIcons.car,          LucideIcons.bus,
    LucideIcons.bike,         LucideIcons.plane,        LucideIcons.train,
    LucideIcons.ship,         LucideIcons.truck,        LucideIcons.fuel,
    LucideIcons.navigation,
    LucideIcons.activity,     LucideIcons.dumbbell,
    LucideIcons.heartPulse,   LucideIcons.stethoscope,  LucideIcons.pill,
    LucideIcons.thermometer,  LucideIcons.cross,        LucideIcons.baby,
    LucideIcons.heart,
    LucideIcons.film,         LucideIcons.music,
    LucideIcons.headphones,   LucideIcons.camera,       LucideIcons.mic,
    LucideIcons.gamepad2,     LucideIcons.tv,           LucideIcons.star,
    LucideIcons.trophy,       LucideIcons.award,
    LucideIcons.home,         LucideIcons.lamp,
    LucideIcons.armchair,     LucideIcons.bed,          LucideIcons.bath,
    LucideIcons.wrench,       LucideIcons.hammer,       LucideIcons.plug,
    LucideIcons.zap,          LucideIcons.wifi,
    LucideIcons.bookOpen,     LucideIcons.graduationCap,
    LucideIcons.library,      LucideIcons.microscope,   LucideIcons.pencil,
    LucideIcons.school,       LucideIcons.newspaper,
    LucideIcons.luggage,      LucideIcons.hotel,
    LucideIcons.mapPin,       LucideIcons.compass,      LucideIcons.globe,
    LucideIcons.flag,         LucideIcons.mountain,     LucideIcons.sun,
    LucideIcons.umbrella,
    LucideIcons.gem,          LucideIcons.diamond,
    LucideIcons.crown,        LucideIcons.leaf,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _budgetController = TextEditingController();
    _nameController.addListener(() => setState(() {}));
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

  Color _bgColor(Color accent) =>
      Color.alphaBlend(accent.withValues(alpha: 0.18), Colors.white);

  String _colorToHex(Color c) =>
      '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accentColor = _parseColor(_selectedColor);
    final name = _nameController.text.trim();

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
                      'New Category',
                      style: TextStyle(
                        fontSize: 16,
                        color: cs.onSurface,
                      ),
                    ),
                    Opacity(
                      opacity: _canSave ? 1.0 : 0.35,
                      child: GestureDetector(
                        onTap: _canSave ? _saveCategory : null,
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
                    ),
                  ],
                ),
              ),
            ),

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
                                color: _bgColor(accentColor),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.12),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _selectedIcon != null
                                    ? Icon(
                                        _selectedIcon,
                                        size: 40,
                                        color: accentColor,
                                      )
                                    : Icon(
                                        LucideIcons.plus,
                                        size: 36,
                                        color: accentColor.withOpacity(0.4),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              name.isEmpty ? 'New Category' : name,
                              style: TextStyle(
                                fontSize: 18,
                                color: name.isEmpty
                                    ? cs.onSurfaceVariant
                                    : cs.onSurface,
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

                    // ── Monthly Budget (optional) ──────────────────────────
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
                    Opacity(
                      opacity: _canSave ? 1.0 : 0.35,
                      child: GestureDetector(
                        onTap: _canSave ? _saveCategory : null,
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
                                'Save Category',
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
