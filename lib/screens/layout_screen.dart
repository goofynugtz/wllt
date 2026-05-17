import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/ad_config.dart';
import '../services/ad_config_service.dart';
import '../services/auth_service.dart';
import '../screens/home_screen.dart';
import '../screens/transactions_screen.dart';
import '../screens/accounts_screen.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/ad_banner.dart';
import '../screens/settings_screen.dart';
import '../screens/add_account_screen.dart';
import '../utils/helpers.dart';

class LayoutScreen extends StatefulWidget {
  const LayoutScreen({super.key});

  @override
  State<LayoutScreen> createState() => _LayoutScreenState();
}

class _LayoutScreenState extends State<LayoutScreen> {
  int _currentIndex = 0;
  bool _bannerAdDismissed = false;
  late DateTime _selectedMonth;

  late final PageController _pageController;
  final ValueNotifier<bool> _pageScrollEnabled = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    AdConfigService.instance.fetch();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pageScrollEnabled.dispose();
    super.dispose();
  }

  void _navigateToTab(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
        1,
      );
    });
  }

  void _showMonthPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MonthPickerSheet(
        selected: _selectedMonth,
        onSelected: (m) => setState(() => _selectedMonth = m),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    final showMonthPicker = _currentIndex <= 1;
    final monthLabel =
        '${Helpers.months[_selectedMonth.month - 1]} ${_selectedMonth.year}';

    final Widget titleWidget = _currentIndex == 0
        ? RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 22,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              children: const [
                TextSpan(
                  text: 'Hi ',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                TextSpan(
                  text: 'Ranjan',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          )
        : Text(
            const [
              '',
              'Transactions',
              'Accounts',
              'Settings',
            ][_currentIndex],
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: showMonthPicker
          ? (details) {
              final v = details.primaryVelocity ?? 0;
              if (v < -100) { _changeMonth(1); }
              else if (v > 100) { _changeMonth(-1); }
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            titleWidget,
            Row(
              children: [
              if (showMonthPicker) ...[
                GestureDetector(
                  onTap: () => _showMonthPicker(context),
                  child: Container(
                    width: 96,
                    height: 36,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      monthLabel,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.bell,
                  size: 16,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showAccountSheet(context),
                child: _buildAvatarCircle(context, size: 36),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildAvatarCircle(BuildContext context, {double size = 36}) {
    final user = context.read<AuthService>().currentUser;
    final photoUrl = user?.photoURL;
    final initials = (user?.displayName?.isNotEmpty == true)
        ? user!.displayName![0].toUpperCase()
        : (user?.email?.isNotEmpty == true)
            ? user!.email![0].toUpperCase()
            : 'R';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        shape: BoxShape.circle,
        image: photoUrl != null
            ? DecorationImage(
                image: NetworkImage(photoUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: photoUrl == null
          ? Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
    );
  }

  void _showAccountSheet(BuildContext context) {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Account info row
            Row(
              children: [
                _buildAvatarCircle(context, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (user?.displayName != null)
                        Text(
                          user!.displayName!,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      if (user?.email != null)
                        Text(
                          user!.email!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Switch account
            _buildAccountSheetAction(
              context: context,
              icon: LucideIcons.refreshCw,
              label: 'Switch account',
              onTap: () async {
                Navigator.pop(sheetCtx);
                await authService.switchAccount();
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 12),
            // Sign out
            _buildAccountSheetAction(
              context: context,
              icon: LucideIcons.logOut,
              label: 'Sign out',
              color: Colors.red,
              onTap: () async {
                Navigator.pop(sheetCtx);
                await authService.signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSheetAction({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final effectiveColor =
        color ?? Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: effectiveColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: effectiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildFab() {
    // Settings — no FAB
    if (_currentIndex == 3) return null;

    // Accounts — navigate to add account
    if (_currentIndex == 2) {
      return FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddAccountScreen()),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 8,
        child: Icon(LucideIcons.plus, size: 24, color: Theme.of(context).colorScheme.onPrimary),
      );
    }

    // Home + Transactions — directly open add transaction
    return FloatingActionButton(
      onPressed: () => _handleAddTransaction(AddTransactionMethod.expense),
      backgroundColor: Theme.of(context).colorScheme.primary,
      elevation: 8,
      child: Icon(LucideIcons.plus, size: 24, color: Theme.of(context).colorScheme.onPrimary),
    );
  }

  final List<NavItem> _navItems = [
    const NavItem(icon: LucideIcons.layoutDashboard, label: 'Home'),
    const NavItem(icon: LucideIcons.arrowLeftRight, label: 'History'),
    const NavItem(icon: LucideIcons.wallet, label: 'Accounts'),
    const NavItem(icon: LucideIcons.settings, label: 'Settings'),
  ];

  void _handleAddTransaction(AddTransactionMethod method) {
    switch (method) {
      case AddTransactionMethod.expense:
      case AddTransactionMethod.income:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AddTransactionPage(method: method),
          ),
        );
        break;
      case AddTransactionMethod.transfer:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transfer coming soon!')));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopHeader(context),
              Expanded(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _pageScrollEnabled,
                  builder: (_, enabled, _) => PageView(
                    controller: _pageController,
                    physics: enabled
                        ? const PageScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) => setState(() {
                      _currentIndex = index;
                    }),
                    children: [
                      HomeScreen(
                        selectedMonth: _selectedMonth,
                        onMonthChanged: _changeMonth,
                        onNavigateToHistory: () => _navigateToTab(1),
                        pageScrollEnabled: _pageScrollEnabled,
                      ),
                      TransactionsScreen(selectedMonth: _selectedMonth),
                      const AccountsScreen(),
                      const SettingsScreen(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: ValueListenableBuilder<AdConfig>(
        valueListenable: AdConfigService.instance.config,
        builder: (_, cfg, child) {
          final showBanner = cfg.showBannerAd && !_bannerAdDismissed;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showBanner)
                AdBanner(
                  onDismiss: () => setState(() => _bannerAdDismissed = true),
                ),
              Container(
                constraints: const BoxConstraints(maxWidth: 430),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: Colors.black.withValues(alpha: 0.08),
                      width: 0.5,
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: _navItems.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      final isActive = _currentIndex == i;
                      final cs = Theme.of(context).colorScheme;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _navigateToTab(i),
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            height: 63,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  width: isActive ? 60 : 36,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? cs.primaryContainer
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    item.icon,
                                    size: 20,
                                    color: isActive
                                        ? cs.onPrimaryContainer
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: isActive
                                        ? cs.onPrimaryContainer
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class NavItem {
  final IconData icon;
  final String label;

  const NavItem({required this.icon, required this.label});
}

enum AddTransactionMethod { expense, income, transfer }

// ── Month picker bottom sheet ─────────────────────────────────────────────────

class _MonthPickerSheet extends StatefulWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  const _MonthPickerSheet({required this.selected, required this.onSelected});

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  static const int _firstYear = 2000;
  static final int _lastYear = DateTime.now().year + 5;
  static const double _itemWidth = 68.0;
  static const double _pillHeight = 32.0;

  late int _year;
  PageController? _pageController;

  @override
  void initState() {
    super.initState();
    _year = widget.selected.year;
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _goToYear(int year) {
    setState(() => _year = year);
    _pageController?.animateToPage(
      year - _firstYear,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Year strip — fixed pill, PageView snaps reliably
          SizedBox(
            height: _pillHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _pageController ??= PageController(
                  initialPage: _year - _firstYear,
                  viewportFraction: _itemWidth / constraints.maxWidth,
                );
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Fixed pill — never moves
                    IgnorePointer(
                      child: Container(
                        width: _itemWidth - 8,
                        height: _pillHeight,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    // PageView — built-in snap, onPageChanged fires reliably
                    AnimatedBuilder(
                      animation: _pageController!,
                      builder: (context, _) {
                        final page = _pageController!.hasClients &&
                                _pageController!.position.hasContentDimensions
                            ? (_pageController!.page ?? _year - _firstYear)
                            : (_year - _firstYear).toDouble();
                        return PageView.builder(
                          controller: _pageController!,
                          itemCount: _lastYear - _firstYear + 1,
                          onPageChanged: (index) {
                            HapticFeedback.selectionClick();
                            setState(() => _year = _firstYear + index);
                          },
                          itemBuilder: (context, index) {
                            final year = _firstYear + index;
                            final isCenter = (page - index).abs() < 0.5;
                            return GestureDetector(
                              onTap: () => _goToYear(year),
                              child: Center(
                                child: Text(
                                  '$year',
                                  style: TextStyle(
                                    fontSize: isCenter ? 14 : 12,
                                    fontWeight: isCenter
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: isCenter
                                        ? Colors.white
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Month grid (3 columns × 4 rows)
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.6,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(12, (i) {
              final m = DateTime(_year, i + 1, 1);
              final isSelected = m.month == widget.selected.month &&
                  m.year == widget.selected.year;
              return GestureDetector(
                onTap: () {
                  widget.onSelected(m);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    Helpers.months[i],
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

