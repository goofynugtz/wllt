import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart'
    if (dart.library.html) '../platform/purchases_web.dart';

import '../providers/subscription_provider.dart';

class CustomPaywallScreen extends StatefulWidget {
  const CustomPaywallScreen({super.key});

  static Future<void> show(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CustomPaywallScreen()),
      );

  @override
  State<CustomPaywallScreen> createState() => _CustomPaywallScreenState();
}

class _CustomPaywallScreenState extends State<CustomPaywallScreen> {
  @override
  void initState() {
    super.initState();
    // If offerings haven't loaded yet, fetch them now.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sub = context.read<SubscriptionProvider>();
      if (sub.offerings == null && !sub.loading) sub.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sub = context.watch<SubscriptionProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(child: _buildBody(context, sub, cs)),
    );
  }

  Widget _buildBody(BuildContext context, SubscriptionProvider sub, ColorScheme cs) {
    if (sub.loading) {
      return Column(
        children: [
          _CloseButton(cs: cs),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }

    final packages = _sortedPackages(sub.offerings?.current?.availablePackages ?? []);

    return Column(
      children: [
        _buildHeader(context, cs),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              children: [
                const SizedBox(height: 12),
                _buildFeatureList(cs),
                const SizedBox(height: 28),
                if (sub.offerings == null)
                  _buildErrorState(cs, 'Could not load offerings.', sub)
                else if (packages.isEmpty)
                  _buildErrorState(cs, 'No packages configured in RevenueCat dashboard.', sub)
                else
                  ...packages.map((p) => _PackageCard(package: p)),
                if (packages.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildRestoreRow(context, sub, cs),
                  const SizedBox(height: 8),
                  Text(
                    'Payments processed securely via the Play Store / App Store.\nSubscriptions auto-renew unless cancelled.',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (sub.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    sub.error!,
                    style: TextStyle(fontSize: 12, color: cs.error),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Preferred display order: Monthly → Yearly → Lifetime
  List<Package> _sortedPackages(List<Package> packages) {
    const order = [PackageType.monthly, PackageType.annual, PackageType.lifetime];
    final sorted = [...packages]..sort((a, b) {
        final ai = order.indexOf(a.packageType);
        final bi = order.indexOf(b.packageType);
        return (ai == -1 ? 999 : ai).compareTo(bi == -1 ? 999 : bi);
      });
    return sorted;
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primary.withValues(alpha: 0.1),
                cs.primaryContainer.withValues(alpha: 0.25),
              ],
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cs.primary.withValues(alpha: 0.85), cs.primary],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(LucideIcons.sparkles, size: 26, color: Colors.white),
              ),
              const SizedBox(height: 14),
              Text(
                'WLLT Premium',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Unlock the full experience',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: IconButton(
            icon: Icon(LucideIcons.x, size: 20, color: cs.onSurfaceVariant),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureList(ColorScheme cs) {
    const features = [
      (LucideIcons.scanLine,   'Bill scanning',       'Scan receipts & bills automatically'),
      (LucideIcons.trendingUp, 'Advanced analytics',  'Spending trends & insights'),
      (LucideIcons.cloudOff,   'No ads',              'Completely ad-free experience'),
      (LucideIcons.refreshCw,  'Cloud sync',          'Sync across all your devices'),
    ];
    return Column(
      children: features
          .map((f) => _FeatureRow(icon: f.$1, label: f.$2, subtitle: f.$3, cs: cs))
          .toList(),
    );
  }

  Widget _buildErrorState(ColorScheme cs, String message, SubscriptionProvider sub) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            message,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: sub.loading ? null : sub.refresh,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreRow(
    BuildContext context,
    SubscriptionProvider sub,
    ColorScheme cs,
  ) {
    return TextButton(
      onPressed: () {
        sub.restorePurchases().then((restored) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              restored ? 'Purchases restored!' : 'No active purchases found.',
            ),
          ));
          if (restored) Navigator.of(context).pop();
        });
      },
      child: Text(
        'Restore purchases',
        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
      ),
    );
  }
}

// ── Close button (used during loading state) ──────────────────────────────────

class _CloseButton extends StatelessWidget {
  final ColorScheme cs;
  const _CloseButton({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 6, right: 6),
        child: IconButton(
          icon: Icon(LucideIcons.x, size: 20, color: cs.onSurfaceVariant),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

// ── Feature row ───────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final ColorScheme cs;

  const _FeatureRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 17, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.check, size: 16, color: cs.primary),
        ],
      ),
    );
  }
}

// ── Package card ──────────────────────────────────────────────────────────────

class _PackageCard extends StatefulWidget {
  final Package package;
  const _PackageCard({required this.package});

  @override
  State<_PackageCard> createState() => _PackageCardState();
}

class _PackageCardState extends State<_PackageCard> {
  bool _loading = false;

  PackageType get _type => widget.package.packageType;

  String get _title => switch (_type) {
        PackageType.lifetime => 'Lifetime',
        PackageType.annual   => 'Yearly',
        PackageType.monthly  => 'Monthly',
        _                    => widget.package.identifier,
      };

  String get _subtitle => switch (_type) {
        PackageType.annual  => 'Best value · billed annually',
        PackageType.monthly => 'Billed every month',
        _                   => 'One-time purchase',
      };

  bool get _isPopular => _type == PackageType.annual;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final price = widget.package.storeProduct.priceString;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: _isPopular ? cs.primaryContainer : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _loading ? null : _purchase,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _isPopular ? cs.onPrimaryContainer : cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: _isPopular
                                  ? cs.onPrimaryContainer.withValues(alpha: 0.7)
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_loading)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _isPopular ? cs.onPrimaryContainer : cs.primary,
                        ),
                      )
                    else
                      Text(
                        price,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _isPopular ? cs.onPrimaryContainer : cs.onSurface,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_isPopular)
            Positioned(
              top: -10,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'POPULAR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: cs.onPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _purchase() async {
    setState(() => _loading = true);
    final sub = context.read<SubscriptionProvider>();
    final isPro = await sub.purchase(widget.package);
    if (!mounted) return;
    setState(() => _loading = false);
    if (isPro) Navigator.of(context).pop();
  }
}
