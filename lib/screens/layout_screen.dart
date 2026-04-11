import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../screens/home_screen.dart';
import '../screens/transactions_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/accounts_screen.dart';
import '../widgets/add_expense_sheet.dart';

class LayoutScreen extends StatefulWidget {
  const LayoutScreen({super.key});

  @override
  State<LayoutScreen> createState() => _LayoutScreenState();
}

class _LayoutScreenState extends State<LayoutScreen> {
  int _currentIndex = 0;
  bool _isFabExpanded = false;

  late final PageController _pageController;
  late final List<Widget> _screens;
  final ValueNotifier<bool> _pageScrollEnabled = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _screens = [
      HomeScreen(
        onNavigateToHistory: () => _navigateToTab(1),
        pageScrollEnabled: _pageScrollEnabled,
      ),
      const TransactionsScreen(),
      const AnalyticsScreen(),
      const AccountsScreen(),
    ];
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

  Widget? _buildFab() {
    // Analytics — nothing to add here
    if (_currentIndex == 2) return null;

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
        // TODO: Implement transfer functionality
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
    return Container(
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
        decoration: const BoxDecoration(color: AppTheme.backgroundLight),
        child: ValueListenableBuilder<bool>(
          valueListenable: _pageScrollEnabled,
          builder: (_, enabled, __) => PageView(
            controller: _pageController,
            physics: enabled
                ? const PageScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            onPageChanged: (index) => setState(() {
              _currentIndex = index;
              _isFabExpanded = false;
            }),
            children: _screens,
          ),
        ),
      ),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        decoration: BoxDecoration(
          color: AppTheme.backgroundLight,
          border: Border(
            top: BorderSide(color: Colors.black.withOpacity(0.08), width: 0.5),
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
    );
  }
}

class NavItem {
  final IconData icon;
  final String label;

  const NavItem({required this.icon, required this.label});
}

enum AddTransactionMethod { expense, income, transfer }
