import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:multiavatar/multiavatar.dart';
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
import '../widgets/feedback_sheet.dart';
import '../screens/category_breakdown_screen.dart';
import '../services/user_service.dart';
import '../screens/settings_screen.dart';
import '../screens/add_account_screen.dart';
import '../providers/app_settings_provider.dart';
import '../providers/sms_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../models/models.dart';
import '../screens/onboarding/onboarding_flow.dart';
import '../services/data_export_service.dart';
import '../utils/helpers.dart';
import '../widgets/sms_inbox_sheet.dart';

class LayoutScreen extends StatefulWidget {
  const LayoutScreen({super.key});

  @override
  State<LayoutScreen> createState() => _LayoutScreenState();
}

class _LayoutScreenState extends State<LayoutScreen> {
  int _currentIndex = 0;
  bool _bannerAdDismissed = false;
  late DateTime _selectedMonth;
  int _lastTxCount = 0;

  late final PageController _pageController;
  final ValueNotifier<bool> _pageScrollEnabled = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    AdConfigService.instance.fetch();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().addListener(_checkTransactionMilestone);
      _upsertUser();
    });
  }

  @override
  void dispose() {
    context.read<TransactionProvider>().removeListener(_checkTransactionMilestone);
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

  void _checkTransactionMilestone() {
    final prefs = context.read<UserPreferencesProvider>();
    if (prefs.feedbackAutoShown) return;
    final txCount = context.read<TransactionProvider>().transactions.length;
    if (txCount >= 10 && _lastTxCount < 10) {
      prefs.setFeedbackAutoShown();
      _showFeedbackSheet('transaction_milestone');
    }
    _lastTxCount = txCount;
  }

  Future<void> _handleCategoryBreakdownTap() async {
    final prefs = context.read<UserPreferencesProvider>();
    if (!prefs.feedbackAutoShown) {
      await prefs.setFeedbackAutoShown();
      await _showFeedbackSheet('insight_milestone');
    }
    if (!mounted) return;
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => CategoryBreakdownScreen(
          selectedMonth: _selectedMonth,
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _showFeedbackSheet(String trigger) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FeedbackSheet(trigger: trigger),
    );
  }

  void _upsertUser() {
    final prefs = context.read<UserPreferencesProvider>();
    UserService.upsertUser(
      authMode: prefs.authMode,
      email: prefs.googleEmail,
      displayName: prefs.displayName,
    );
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
        ? Builder(builder: (ctx) {
            final prefs = ctx.watch<UserPreferencesProvider>();
            final authService = ctx.read<AuthService>();
            final String displayName;
            if (prefs.authMode == 'google') {
              final googleName = authService.currentUser?.displayName;
              displayName = googleName?.split(' ').first ?? prefs.displayName ?? 'there';
            } else {
              displayName = prefs.displayName?.split(' ').first ?? 'there';
            }
            return RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 22,
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
                children: [
                  const TextSpan(
                    text: 'Hi ',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  TextSpan(
                    text: displayName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            );
          })
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
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                        width: 0.5,
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
              if (!kIsWeb) Consumer<SmsProvider>(
                builder: (ctx, sms, _) {
                  final prefs = ctx.watch<UserPreferencesProvider>();
                  return FutureBuilder<PermissionStatus>(
                    future: defaultTargetPlatform == TargetPlatform.android
                        ? Permission.sms.status
                        : Future.value(PermissionStatus.granted),
                    builder: (_, snap) {
                      final status = snap.data;
                      final hidden = defaultTargetPlatform == TargetPlatform.android &&
                          (!prefs.smsFeatureEnabled || status == PermissionStatus.permanentlyDenied);
                      if (hidden) return const SizedBox.shrink();
                      final count = sms.pendingCount;
                      return GestureDetector(
                        onTap: () => _showSmsInbox(ctx),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
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
                            if (count > 0)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                  child: Text(
                                    count > 99 ? '99+' : '$count',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
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
    final prefs = context.read<UserPreferencesProvider>();
    final photoUrl = user?.photoURL;
    final avatarSeed = prefs.avatarSeed;
    final storedName = prefs.displayName;
    final initials = (user?.displayName?.isNotEmpty == true)
        ? user!.displayName![0].toUpperCase()
        : (user?.email?.isNotEmpty == true)
            ? user!.email![0].toUpperCase()
            : (storedName?.isNotEmpty == true)
                ? storedName![0].toUpperCase()
                : '?';

    // Priority: Google photo > selected avatar > initials
    if (photoUrl != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: NetworkImage(photoUrl),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    if (avatarSeed != null) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: SvgPicture.string(
            multiavatar(avatarSeed),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppTheme.primaryColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _showSmsInbox(BuildContext ctx) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.sms.status;
      if (status.isDenied) {
        final result = await Permission.sms.request();
        if (!result.isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SMS permission required to detect transactions'),
            ),
          );
          return;
        }
      }
    }
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const SmsInboxSheet(),
    );
  }

  void _showAccountSheet(BuildContext context) {
    final prefs = context.read<UserPreferencesProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ProfileAccountSheet(
        authMode: prefs.authMode,
        initialName: prefs.displayName ?? '',
        initialSeed: prefs.avatarSeed,
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
    final isPro = context.watch<SubscriptionProvider>().isPro;
    final isWide = MediaQuery.of(context).size.width >= 768;
    return isWide ? _buildWideScaffold(context) : _buildNarrowScaffold(context, isPro);
  }

  Widget _buildDemoBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Text(
        'Demo mode — data is not saved. Sign in to keep your transactions.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _buildSideRail(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 88,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          right: BorderSide(
            color: Colors.black.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            ..._navItems.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final isActive = _currentIndex == i;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: GestureDetector(
                  onTap: () => _navigateToTab(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isActive ? cs.primaryContainer : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          size: 20,
                          color: isActive ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isActive ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPages() => [
    HomeScreen(
      selectedMonth: _selectedMonth,
      onMonthChanged: _changeMonth,
      onNavigateToHistory: () => _navigateToTab(1),
      pageScrollEnabled: _pageScrollEnabled,
      onCategoryBreakdownTap: _handleCategoryBreakdownTap,
    ),
    TransactionsScreen(selectedMonth: _selectedMonth),
    const AccountsScreen(),
    const SettingsScreen(),
  ];

  Widget _buildWideScaffold(BuildContext context) {
    final demoMode = context.watch<AppSettingsProvider>().demoMode;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          _buildSideRail(context),
          Expanded(
            child: Column(
              children: [
                _buildTopHeader(context),
                if (demoMode) _buildDemoBanner(context),
                Expanded(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _pageScrollEnabled,
                    builder: (_, enabled, __) => PageView(
                      controller: _pageController,
                      physics: enabled
                          ? const PageScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      onPageChanged: (index) => setState(() => _currentIndex = index),
                      children: _buildPages(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildNarrowScaffold(BuildContext context, bool isPro) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopHeader(context),
            if (context.watch<AppSettingsProvider>().demoMode) _buildDemoBanner(context),
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: _pageScrollEnabled,
                builder: (_, enabled, __) => PageView(
                  controller: _pageController,
                  physics: enabled
                      ? const PageScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) => setState(() => _currentIndex = index),
                  children: _buildPages(),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: ValueListenableBuilder<AdConfig>(
        valueListenable: AdConfigService.instance.config,
        builder: (_, cfg, __) {
          final showBanner = !kIsWeb && cfg.showBannerAd && !_bannerAdDismissed && !isPro;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showBanner)
                AdBanner(
                  onDismiss: () => setState(() => _bannerAdDismissed = true),
                ),
              Container(
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

// ── Avatar seeds ──────────────────────────────────────────────────────────────

const List<String> _kAvatarSeeds = [
  'Felix', 'Luna', 'Zara', 'Kai', 'Nova', 'Orion',
  'Ivy', 'Rex', 'Maya', 'Axel', 'Sora', 'Echo',
];

// ── Profile / Account bottom sheet ────────────────────────────────────────────

class _ProfileAccountSheet extends StatefulWidget {
  final String authMode;
  final String initialName;
  final String? initialSeed;

  const _ProfileAccountSheet({
    required this.authMode,
    required this.initialName,
    this.initialSeed,
  });

  @override
  State<_ProfileAccountSheet> createState() => _ProfileAccountSheetState();
}

class _ProfileAccountSheetState extends State<_ProfileAccountSheet> {
  late final TextEditingController _nameCtrl;
  late String? _selectedSeed;
  bool _saving = false;

  static final Map<String, String> _svgCache = {
    for (final s in _kAvatarSeeds) s: multiavatar(s),
  };

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _selectedSeed = widget.initialSeed;
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    final prefs = context.read<UserPreferencesProvider>();
    await prefs.setDisplayName(name);
    if (_selectedSeed != null) await prefs.setAvatarSeed(_selectedSeed!);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _handleOfflineSignOut() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Signing out will permanently delete all your local data. '
          'Export a CSV backup first?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('export'),
            child: const Text('Export & Sign Out'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('signout'),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Color(0xFFB3261E)),
            ),
          ),
        ],
      ),
    );

    if (result == null || result == 'cancel') return;
    if (!mounted) return;

    if (result == 'export') {
      final txProvider = context.read<TransactionProvider>();
      final prefs = context.read<UserPreferencesProvider>();
      final allCategories = [...Category.categories, ...prefs.customCategories];
      try {
        await DataExportService.exportTransactions(
          transactions: txProvider.transactions,
          allCategories: allCategories,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Export failed: $e')),
          );
        }
        return;
      }
      if (!mounted) return;
    }

    final navigator = Navigator.of(context);
    final settings = context.read<AppSettingsProvider>();
    navigator.pop();
    await settings.resetAllData();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingFlow()),
      (_) => false,
    );
  }

  Future<void> _handleGoogleSignOut() async {
    Navigator.of(context).pop();
    await context.read<AuthService>().signOut();
  }

  Future<void> _handleSwitchAccount() async {
    Navigator.of(context).pop();
    await context.read<AuthService>().switchAccount();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: widget.authMode == 'offline'
            ? _buildOfflineContent(cs)
            : _buildGoogleContent(cs),
      ),
    );
  }

  Widget _buildDragHandle(ColorScheme cs) => Center(
        child: Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: cs.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _buildOfflineContent(ColorScheme cs) {
    final canSave = _nameCtrl.text.trim().isNotEmpty && !_saving;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDragHandle(cs),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Text(
            'Edit Profile',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.5),
            ),
            child: TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              style: TextStyle(fontSize: 15, color: cs.onSurface),
              decoration: InputDecoration(
                hintText: 'Your name',
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                prefixIcon: Icon(LucideIcons.user, size: 16, color: cs.onSurfaceVariant),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'CHOOSE AVATAR',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.8,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _kAvatarSeeds.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final seed = _kAvatarSeeds[i];
              final selected = _selectedSeed == seed;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedSeed = selected ? null : seed;
                }),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    width: 58,
                    height: 58,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.5),
                        width: selected ? 2.5 : 0.5,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: cs.primary.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: SvgPicture.string(
                      _svgCache[seed]!,
                      width: 58,
                      height: 58,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Opacity(
            opacity: canSave ? 1.0 : 0.4,
            child: GestureDetector(
              onTap: canSave ? _save : null,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: cs.inverseSurface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(
                  child: _saving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onInverseSurface,
                          ),
                        )
                      : Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: cs.onInverseSurface,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: GestureDetector(
            onTap: _handleOfflineSignOut,
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Center(
                child: Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleContent(ColorScheme cs) {
    final user = context.read<AuthService>().currentUser;
    final prefs = context.read<UserPreferencesProvider>();
    final photoUrl = user?.photoURL;
    final avatarSeed = prefs.avatarSeed;
    final name = user?.displayName ?? prefs.displayName;
    final email = user?.email;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDragHandle(cs),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Row(
            children: [
              _buildAvatarWidget(photoUrl, avatarSeed, name, 48, cs),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name != null)
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    if (email != null)
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: _buildActionTile(
            cs: cs,
            icon: LucideIcons.refreshCw,
            label: 'Switch Accounts',
            onTap: _handleSwitchAccount,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: _buildActionTile(
            cs: cs,
            icon: LucideIcons.logOut,
            label: 'Sign Out',
            isDestructive: true,
            onTap: _handleGoogleSignOut,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarWidget(
    String? photoUrl,
    String? avatarSeed,
    String? name,
    double size,
    ColorScheme cs,
  ) {
    if (photoUrl != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover),
        ),
      );
    }
    if (avatarSeed != null) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: SvgPicture.string(multiavatar(avatarSeed), fit: BoxFit.cover),
        ),
      );
    }
    final initial = name?.isNotEmpty == true ? name![0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w600,
            color: cs.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required ColorScheme cs,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red.withValues(alpha: 0.10) : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isDestructive ? Colors.red : cs.onSurface,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDestructive ? Colors.red : cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
