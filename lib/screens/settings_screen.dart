import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart'
    if (dart.library.html) '../platform/workmanager_web.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../config/app_flavor.dart';
import '../models/models.dart';
import '../providers/ai_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../screens/categories_screen.dart';
import '../screens/currency_picker_screen.dart';
import '../screens/model_lab_screen.dart';
import '../screens/onboarding/onboarding_flow.dart';
import '../screens/custom_paywall_screen.dart';
import '../screens/paywall_screen.dart';
import '../services/data_export_service.dart';
import '../theme/app_theme.dart';
import '../widgets/feedback_sheet.dart';

// ── Color scheme definitions ──────────────────────────────────────────────────

class _AppColorScheme {
  final String name;
  final Color seed;
  final Color container;
  final Color onContainer;

  const _AppColorScheme({
    required this.name,
    required this.seed,
    required this.container,
    required this.onContainer,
  });
}

const _kColorSchemes = [
  _AppColorScheme(
    name: 'Violet',
    seed: Color(0xFF6750A4),
    container: Color(0xFFEDE7F6),
    onContainer: Color(0xFF6750A4),
  ),
  _AppColorScheme(
    name: 'Rose',
    seed: Color(0xFFB5264C),
    container: Color(0xFFFFD9E2),
    onContainer: Color(0xFFB5264C),
  ),
  _AppColorScheme(
    name: 'Ocean',
    seed: Color(0xFF006874),
    container: Color(0xFFA2EFF8),
    onContainer: Color(0xFF006874),
  ),
  _AppColorScheme(
    name: 'Sage',
    seed: Color(0xFF386A20),
    container: Color(0xFFB3F397),
    onContainer: Color(0xFF386A20),
  ),
  _AppColorScheme(
    name: 'Amber',
    seed: Color(0xFF7D5700),
    container: Color(0xFFFFDEA3),
    onContainer: Color(0xFF7D5700),
  ),
  _AppColorScheme(
    name: 'Crimson',
    seed: Color(0xFF9C3425),
    container: Color(0xFFFFDAD5),
    onContainer: Color(0xFF9C3425),
  ),
  _AppColorScheme(
    name: 'Indigo',
    seed: Color(0xFF3951AD),
    container: Color(0xFFDCE2FF),
    onContainer: Color(0xFF3951AD),
  ),
  _AppColorScheme(
    name: 'Forest',
    seed: Color(0xFF256156),
    container: Color(0xFFA0F0E3),
    onContainer: Color(0xFF256156),
  ),
];

// ── Main screen ───────────────────────────────────────────────────────────────

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings      = context.watch<AppSettingsProvider>();
    final prefs         = context.watch<UserPreferencesProvider>();
    final subscription  = context.watch<SubscriptionProvider>();

    final activeScheme = _kColorSchemes.firstWhere(
      (s) => s.seed.toARGB32() == settings.colorSeed.toARGB32(),
      orElse: () => _kColorSchemes.first,
    );
    final paletteName = Theme.of(context).brightness == Brightness.dark
        ? 'Dark palette'
        : 'Light palette';

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: _buildSectionLabel(context, 'Appearance')),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(child: _buildAppearanceCard(context, settings)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildSectionLabel(context, 'Customize')),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: _buildColorSchemeCard(
                context, settings, activeScheme, paletteName,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildSectionLabel(context, 'Preferences')),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(child: _buildPreferencesCard(context, prefs)),
            if (defaultTargetPlatform == TargetPlatform.android) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(child: _buildSectionLabel(context, 'Privacy & Permissions')),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(child: _buildPrivacyCard(context, prefs)),
            ],
            if (!kIsWeb) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(child: _buildSectionLabel(context, 'Premium')),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(child: _buildPremiumCard(context, subscription)),
              if (subscription.isPro && kFlavor != AppFlavor.release) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                SliverToBoxAdapter(child: _buildSectionLabel(context, 'Experimental Labs')),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverToBoxAdapter(child: _buildLabsCard(context)),
              ],
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildSectionLabel(context, 'Account & Data')),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: _buildAccountCard(context, settings, prefs),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildSectionLabel(context, 'About')),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(child: _buildAboutCard(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  // ── Section builders ──────────────────────────────────────────────────────

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        label.toUpperCase(),
        style: AppTheme.trackingWide.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildAppearanceCard(
    BuildContext context,
    AppSettingsProvider settings,
  ) {
    final subtitle = switch (settings.themeMode) {
      ThemeMode.light  => 'Always light',
      ThemeMode.dark   => 'Always dark',
      ThemeMode.system => 'Follows system',
    };
    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsInfoRow(
            icon: LucideIcons.palette,
            label: 'App theme',
            subtitle: subtitle,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _ThemeModeToggle(
              current: settings.themeMode,
              onChanged: (mode) =>
                  context.read<AppSettingsProvider>().setThemeMode(mode),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSchemeCard(
    BuildContext context,
    AppSettingsProvider settings,
    _AppColorScheme activeScheme,
    String paletteName,
  ) {
    return _SettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsInfoRow(
            icon: LucideIcons.circle,
            iconColor: activeScheme.seed,
            label: 'Color scheme',
            subtitle: '${activeScheme.name} · $paletteName',
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _kColorSchemes.take(4).map((scheme) => _ColorSwatch(
                    scheme: scheme,
                    isSelected: scheme.seed.toARGB32() == settings.colorSeed.toARGB32(),
                    onTap: () => context.read<AppSettingsProvider>().setColorSeed(scheme.seed),
                  )).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _kColorSchemes.skip(4).map((scheme) => _ColorSwatch(
                    scheme: scheme,
                    isSelected: scheme.seed.toARGB32() == settings.colorSeed.toARGB32(),
                    onTap: () => context.read<AppSettingsProvider>().setColorSeed(scheme.seed),
                  )).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard(
    BuildContext context,
    UserPreferencesProvider prefs,
  ) {
    return _SettingsCard(
      child: Column(
        children: [
          _SettingsTappableRow(
            icon: LucideIcons.dollarSign,
            label: 'Currency',
            // prefs.currency is the global display currency code (e.g. "USD"); drives net worth and section totals in AccountsScreen.
            value: prefs.currency,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CurrencyPickerScreen()),
            ),
          ),
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
            indent: 16,
            endIndent: 16,
          ),
          _SettingsTappableRow(
            icon: LucideIcons.tag,
            label: 'Categories',
            value: '${prefs.activeCategories.length} categories',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CategoriesScreen()),
            ),
          ),
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
            indent: 16,
            endIndent: 16,
          ),
          _SettingsTappableRow(
            icon: LucideIcons.layers,
            label: 'Group transactions',
            value: prefs.groupTransactionsThreshold > 0
                ? 'Under ${prefs.groupTransactionsThreshold}/day'
                : 'Off',
            onTap: () => _showGroupTransactionsDialog(context, prefs),
          ),
        ],
      ),
    );
  }

  Future<void> _showGroupTransactionsDialog(
    BuildContext context,
    UserPreferencesProvider prefs,
  ) async {
    final controller = TextEditingController(
      text: prefs.groupTransactionsThreshold > 0
          ? prefs.groupTransactionsThreshold.toString()
          : '',
    );
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Group transactions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Days with fewer transactions than this number are grouped '
              'together in the transactions list. Set 0 to disable.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'e.g. 4'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim()) ?? 0;
              Navigator.of(ctx).pop(parsed < 0 ? 0 : parsed);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value != null) {
      await prefs.setGroupTransactionsThreshold(value);
    }
  }

  Widget _buildAccountCard(
    BuildContext context,
    AppSettingsProvider settings,
    UserPreferencesProvider prefs,
  ) {
    return _SettingsCard(
      child: Column(
        children: [
          _SettingsReadOnlyRow(
            icon: LucideIcons.refreshCw,
            label: 'Sync mode',
            value: prefs.authMode == 'offline' ? 'Offline' : 'Google',
          ),
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
            indent: 16,
            endIndent: 16,
          ),
          if (kFlavor != AppFlavor.release) ...[
            _SettingsSwitchRow(
              icon: LucideIcons.flaskConical,
              label: 'Dev mode',
              subtitle: 'Show sample data instead of real data',
              value: settings.devMode,
              onChanged: (v) => context.read<AppSettingsProvider>().setDevMode(v),
            ),
            Divider(
              height: 0.5,
              thickness: 0.5,
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
              indent: 16,
              endIndent: 16,
            ),
          ],
          if (!kIsWeb) ...[
            _SettingsTappableRow(
              icon: LucideIcons.download,
              label: 'Export data',
              value: 'CSV',
              onTap: () => _handleExport(context),
            ),
            Divider(
              height: 0.5,
              thickness: 0.5,
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
              indent: 16,
              endIndent: 16,
            ),
            _SettingsTappableRow(
              icon: LucideIcons.upload,
              label: 'Import data',
              value: 'CSV',
              onTap: () => _handleImport(context),
            ),
            Divider(
              height: 0.5,
              thickness: 0.5,
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
              indent: 16,
              endIndent: 16,
            ),
          ],
          _SettingsTappableRow(
            icon: LucideIcons.trash2,
            label: 'Reset all data',
            labelColor: const Color(0xFFB3261E),
            iconBgColor: const Color(0x1FB3261E),
            iconColor: const Color(0xFFB3261E),
            onTap: () => _showResetConfirmation(context, settings),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport(BuildContext context) async {
    final txProvider = context.read<TransactionProvider>();
    if (txProvider.transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions to export.')),
      );
      return;
    }
    final prefs = context.read<UserPreferencesProvider>();
    final allCategories = [...Category.categories, ...prefs.customCategories];
    try {
      await DataExportService.exportTransactions(
        transactions: txProvider.transactions,
        allCategories: allCategories,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _handleImport(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.single.path == null) return;

    ImportResult imported;
    try {
      imported = await DataExportService.importTransactions(
        result.files.single.path!,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to parse file: $e')),
        );
      }
      return;
    }

    if (imported.transactions.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              imported.skipped > 0
                  ? 'No valid rows found (${imported.skipped} skipped).'
                  : 'No transactions found in file.',
            ),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    final skipNote = imported.skipped > 0
        ? ' (${imported.skipped} invalid rows skipped)'
        : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Import ${imported.transactions.length} transactions?'),
        content: Text(
          'This will add ${imported.transactions.length} transactions to your existing data.$skipNote',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final txProvider = context.read<TransactionProvider>();
    for (final tx in imported.transactions) {
      await txProvider.addTransaction(tx);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${imported.transactions.length} transactions.',
          ),
        ),
      );
    }
  }

  void _showResetConfirmation(
    BuildContext context,
    AppSettingsProvider settings,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset all data?'),
        content: const Text(
          'This will permanently delete all your transactions, accounts, '
          'and preferences. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await settings.resetAllData();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const OnboardingFlow()),
                  (_) => false,
                );
              }
            },
            child: const Text(
              'Reset',
              style: TextStyle(color: Color(0xFFB3261E)),
            ),
          ),
        ],
      ),
    );
  }

  void _showFeedbackSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const FeedbackSheet(trigger: 'manual'),
    );
  }

  void _openPaywall(BuildContext context) {
    CustomPaywallScreen.show(context);
  }

  void _openCustomerCenter(BuildContext context) {
    PaywallScreen.showCustomerCenter().catchError((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer Center requires RevenueCat Pro plan.')),
        );
      }
    });
  }

  void _handleRestore(BuildContext context) {
    context.read<SubscriptionProvider>().restorePurchases().then((restored) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(restored ? 'Purchases restored!' : 'No active purchases found.'),
        ));
      }
    }).catchError((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to restore purchases.')),
        );
      }
    });
  }

  Widget _buildPrivacyCard(BuildContext context, UserPreferencesProvider prefs) {
    return _SettingsCard(
      child: FutureBuilder<PermissionStatus>(
        future: Permission.sms.status,
        builder: (_, snap) {
          final status = snap.data;
          final isPermanent = status == PermissionStatus.permanentlyDenied;
          return SwitchListTile(
            title: const Text('SMS Transaction Detection'),
            subtitle: Text(
              isPermanent
                  ? 'Permission denied — tap to open app settings'
                  : 'Automatically detect transactions from bank SMS',
              style: const TextStyle(fontSize: 12),
            ),
            value: prefs.smsFeatureEnabled && status == PermissionStatus.granted,
            onChanged: (v) async {
              if (!v) {
                await prefs.setSmsFeatureEnabled(false);
                await Workmanager().cancelByUniqueName('sms_scan_task');
                return;
              }
              if (isPermanent) {
                await openAppSettings();
                return;
              }
              final result = await Permission.sms.request();
              if (result.isGranted) {
                await prefs.setSmsFeatureEnabled(true);
                await Workmanager().registerPeriodicTask(
                  'sms_scan_task',
                  'sms_scan_task',
                  frequency: const Duration(minutes: 15),
                  existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
                );
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('SMS permission is required')),
                  );
                }
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildPremiumCard(BuildContext context, SubscriptionProvider subscription) {
    final isPro = subscription.isPro;
    return _SettingsCard(
      child: Column(
        children: [
          _SettingsTappableRow(
            icon: LucideIcons.sparkles,
            label: 'WLLT Premium',
            value: isPro ? 'Active' : 'Get Pro',
            onTap: isPro
                ? () => _openCustomerCenter(context)
                : () => _openPaywall(context),
          ),
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
            indent: 16,
            endIndent: 16,
          ),
          if (!isPro) ...[
            _SettingsTappableRow(
              icon: LucideIcons.refreshCw,
              label: 'Restore Purchases',
              onTap: () => _handleRestore(context),
            ),
            Divider(
              height: 0.5,
              thickness: 0.5,
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
              indent: 16,
              endIndent: 16,
            ),
          ],
          _SettingsReadOnlyRow(
            icon: LucideIcons.scanLine,
            label: 'Bill scanning',
            value: isPro ? 'Available' : 'Premium',
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return _SettingsCard(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF3B2977), Color(0xFF6750A4)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(LucideIcons.wallet, size: 26, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WLLT: Expense Tracker',
                      style: TextStyle(
                        fontSize: 17,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Built with ♥ using Flutter',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
            indent: 16,
            endIndent: 16,
          ),
          _SettingsTappableRow(
            icon: LucideIcons.messageSquare,
            label: 'Send Feedback',
            onTap: () => _showFeedbackSheet(context),
          ),
        ],
      ),
    );
  }
  Widget _buildLabsCard(BuildContext context) {
    final ai = context.watch<AiProvider>();
    final devMode = context.watch<AppSettingsProvider>().devMode;
    final subtitle = switch (ai.state) {
      AiModelState.ready       => '${ai.modelDisplayName} · On-device',
      AiModelState.downloading => 'Downloading…',
      AiModelState.error       => 'Download failed — tap to retry',
      _                        => '${ai.modelDisplayName} · ${ai.modelSizeLabel}',
    };
    if (devMode) {
      return _SettingsCard(
        child: _SettingsTappableRow(
          icon: LucideIcons.flaskConical,
          label: 'AI Features',
          value: 'Model lab',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ModelLabScreen()),
          ),
        ),
      );
    }
    return _SettingsCard(
      child: SwitchListTile(
        secondary: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            LucideIcons.flaskConical,
            size: 18,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
        title: const Text('AI Features', style: TextStyle(fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: ai.isEnabled,
        onChanged: ai.state == AiModelState.downloading
            ? null
            : (v) async {
                if (!v) {
                  _showDeleteConfirmation(context, ai);
                  return;
                }
                // Model may already be on disk (previous install, interrupted
                // toggle-off) — skip the download sheet and just load it.
                if (await ai.isActiveModelDownloaded) {
                  await ai.enableAndDownload();
                } else if (context.mounted) {
                  _showDownloadConfirmation(context, ai);
                }
              },
      ),
    );
  }

  void _showDownloadConfirmation(BuildContext context, AiProvider ai) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _DownloadSheet(ai: ai),
    );
  }

  void _showDeleteConfirmation(BuildContext context, AiProvider ai) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delete downloaded model?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(ctx).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${ai.modelSizeLabel} will be freed from your device.',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(ctx).colorScheme.error,
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      ai.disable();
                    },
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Download sheet ────────────────────────────────────────────────────────────

class _DownloadSheet extends StatefulWidget {
  final AiProvider ai;
  const _DownloadSheet({required this.ai});

  @override
  State<_DownloadSheet> createState() => _DownloadSheetState();
}

class _DownloadSheetState extends State<_DownloadSheet> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _started = widget.ai.state == AiModelState.downloading;
    widget.ai.addListener(_onStateChange);
  }

  @override
  void dispose() {
    widget.ai.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (!mounted) return;
    if (_started && widget.ai.state == AiModelState.ready) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {});
  }

  void _start() {
    setState(() => _started = true);
    widget.ai.enableAndDownload();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.ai.state;
    final progress = widget.ai.downloadProgress;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_started) ...[
            Text(
              'Download AI Model (${widget.ai.modelSizeLabel})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Runs fully on-device. No data leaves your phone. Wi-Fi recommended.',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Powered by Gemma. By downloading, you agree to the Gemma '
              'Terms of Use: ai.google.dev/gemma/terms',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _start,
                    child: const Text('Download'),
                  ),
                ),
              ],
            ),
          ] else if (state == AiModelState.downloading) ...[
            Text(
              'Downloading AI Model',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  LucideIcons.download,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Downloading…',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              'Wi-Fi recommended',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ] else if (state == AiModelState.error) ...[
            Text(
              'Download failed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Something went wrong. Check your connection and try again.',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _start,
                    child: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Shared card wrapper ───────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.hardEdge,
        child: child,
      ),
    );
  }
}

// ── Row variants ──────────────────────────────────────────────────────────────

/// Non-interactive header row inside a card (icon + label + subtitle).
class _SettingsInfoRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String subtitle;

  const _SettingsInfoRow({
    required this.icon,
    this.iconColor,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 18,
              color: iconColor ?? Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tappable row — navigates somewhere or triggers an action.
class _SettingsTappableRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Color? labelColor;
  final Color? iconBgColor;
  final Color? iconColor;
  final VoidCallback onTap;

  const _SettingsTappableRow({
    required this.icon,
    required this.label,
    this.value,
    this.labelColor,
    this.iconBgColor,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBgColor ?? Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 18,
                color: iconColor ?? Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: labelColor ?? Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (value != null) ...[
              Text(
                value!,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Non-tappable row showing a read-only value on the right.
class _SettingsReadOnlyRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SettingsReadOnlyRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Switch row ────────────────────────────────────────────────────────────────

class _SettingsSwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ── Theme mode toggle ─────────────────────────────────────────────────────────

class _ThemeModeToggle extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeModeToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _ThemeSegment(
            icon: LucideIcons.sun,
            label: 'Light',
            isSelected: current == ThemeMode.light,
            onTap: () => onChanged(ThemeMode.light),
          ),
          _ThemeSegment(
            icon: LucideIcons.monitor,
            label: 'System',
            isSelected: current == ThemeMode.system,
            onTap: () => onChanged(ThemeMode.system),
          ),
          _ThemeSegment(
            icon: LucideIcons.moon,
            label: 'Dark',
            isSelected: current == ThemeMode.dark,
            onTap: () => onChanged(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}

class _ThemeSegment extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeSegment({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: double.infinity,
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected
                ? const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ── Color scheme swatch ───────────────────────────────────────────────────────

class _ColorSwatch extends StatelessWidget {
  final _AppColorScheme scheme;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.scheme,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: isSelected ? 1.0 : 0.0),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            builder: (context, t, _) {
              final bgTop = Color.lerp(
                scheme.container,
                scheme.seed.withValues(alpha: 0.8),
                t,
              )!;
              final bgBottom = Color.lerp(scheme.container, scheme.seed, t)!;
              final shadowAlpha = t * 0.33;
              return Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [bgTop, bgBottom],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.seed.withValues(alpha: shadowAlpha),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Unselected dot — fades out
                    Opacity(
                      opacity: (1 - t).clamp(0.0, 1.0),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Color.lerp(scheme.onContainer, Colors.white, t),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    // Check icon — fades in
                    Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: const Icon(LucideIcons.check, size: 26, color: Colors.white),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(end: isSelected ? 1.0 : 0.0),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            builder: (context, t, _) {
              return Text(
                scheme.name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color.lerp(surfaceVariant, scheme.seed, t),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
