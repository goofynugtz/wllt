import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/ad_config.dart';
import '../services/ad_config_service.dart';
import '../services/auth_service.dart';
import '../screens/home_screen.dart';
import '../screens/transactions_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/accounts_screen.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/ad_banner.dart';
import '../screens/settings_screen.dart';
import '../utils/helpers.dart';

class LayoutScreen extends StatefulWidget {
  const LayoutScreen({super.key});

  @override
  State<LayoutScreen> createState() => _LayoutScreenState();
}

class _LayoutScreenState extends State<LayoutScreen> {
  int _currentIndex = 0;
  bool _isFabExpanded = false;
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
    if (_isFabExpanded) setState(() => _isFabExpanded = false);
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
    final showMonthPicker = _currentIndex <= 2;
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
              'Analytics',
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
    // Analytics — nothing to add here
    if (_currentIndex == 2) return null;

    // Settings — no FAB
    if (_currentIndex == 4) return null;

    // Accounts — simple add-account button
    if (_currentIndex == 3) {
      return FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add account coming soon!')),
          );
        },
        backgroundColor: AppTheme.primaryColor,
        elevation: 8,
        child: const Icon(LucideIcons.plus, size: 24, color: Colors.white),
      );
    }

    // Home + Transactions — expandable transaction FAB
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isFabExpanded) ...[
          _buildFabOption(
            icon: LucideIcons.arrowLeftRight,
            label: 'Transfer',
            onTap: () {
              setState(() => _isFabExpanded = false);
              _handleAddTransaction(AddTransactionMethod.transfer);
            },
          ),
          const SizedBox(height: 12),
          _buildFabOption(
            icon: LucideIcons.trendingUp,
            label: 'Income',
            onTap: () {
              setState(() => _isFabExpanded = false);
              _handleAddTransaction(AddTransactionMethod.income);
            },
          ),
          const SizedBox(height: 12),
          _buildFabOption(
            icon: LucideIcons.trendingDown,
            label: 'Expense',
            onTap: () {
              setState(() => _isFabExpanded = false);
              _handleAddTransaction(AddTransactionMethod.expense);
            },
          ),
          const SizedBox(height: 12),
        ],
        FloatingActionButton(
          onPressed: () => setState(() => _isFabExpanded = !_isFabExpanded),
          backgroundColor: AppTheme.primaryColor,
          elevation: 8,
          child: AnimatedRotation(
            turns: _isFabExpanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(LucideIcons.plus, size: 24, color: Colors.white),
          ),
        ),
      ],
    );
  }

  final List<NavItem> _navItems = [
    const NavItem(icon: LucideIcons.layoutDashboard, label: 'Home'),
    const NavItem(icon: LucideIcons.arrowLeftRight, label: 'History'),
    const NavItem(icon: LucideIcons.barChart2, label: 'Analytics'),
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

  Widget _buildFabOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 56,
      child: FloatingActionButton.extended(
        onPressed: onTap,
        backgroundColor: Colors.white,
        elevation: 4,
        icon: Icon(icon, size: 18, color: AppTheme.textPrimary),
        label: Text(
          label,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
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
                      _isFabExpanded = false;
                    }),
                    children: [
                      HomeScreen(
                        selectedMonth: _selectedMonth,
                        onMonthChanged: _changeMonth,
                        onNavigateToHistory: () => _navigateToTab(1),
                        pageScrollEnabled: _pageScrollEnabled,
                      ),
                      TransactionsScreen(selectedMonth: _selectedMonth),
                      AnalyticsScreen(selectedMonth: _selectedMonth),
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
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                    ),
                    child: BottomNavigationBar(
                      currentIndex: _currentIndex,
                      onTap: _navigateToTab,
                      type: BottomNavigationBarType.fixed,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      selectedFontSize: 11,
                      unselectedFontSize: 11,
                      selectedItemColor: AppTheme.primaryColor,
                      unselectedItemColor: AppTheme.textSecondary,
                      items: _navItems.map((item) {
                        return BottomNavigationBarItem(
                          icon: Icon(item.icon, size: 22),
                          activeIcon: Icon(item.icon, size: 22, weight: 2.5),
                          label: item.label,
                        );
                      }).toList(),
                    ),
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
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.selected.year;
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

          // Year navigator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => setState(() => _year--),
                icon: const Icon(LucideIcons.chevronLeft, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Text(
                '$_year',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _year++),
                icon: const Icon(LucideIcons.chevronRight, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
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
