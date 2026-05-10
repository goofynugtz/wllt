import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'providers/account_provider.dart';
import 'providers/app_settings_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/user_preferences_provider.dart';
import 'screens/layout_screen.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'services/auth_service.dart';
import 'services/purchase_service.dart';
import 'services/storage_service.dart';
import 'services/system_font_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await MobileAds.instance.initialize();
  await PurchaseService.instance.initialize();
  await Hive.initFlutter();

  final storage = StorageService();
  await storage.init();

  final systemFont = await SystemFontService.loadSystemFont();

  runApp(WalletApp(storage: storage, systemFont: systemFont));
}

class WalletApp extends StatelessWidget {
  final StorageService storage;
  final String systemFont;

  const WalletApp({super.key, required this.storage, required this.systemFont});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppSettingsProvider(storage),
        ),
        ChangeNotifierProvider(
          create: (_) => UserPreferencesProvider(storage),
        ),
        ChangeNotifierProxyProvider<AppSettingsProvider, TransactionProvider>(
          create: (_) => TransactionProvider(storage, devMode: storage.devMode),
          update: (_, settings, prev) => prev!..reloadIfNeeded(settings.devMode),
        ),
        ChangeNotifierProxyProvider<AppSettingsProvider, AccountProvider>(
          create: (_) => AccountProvider(storage, devMode: storage.devMode),
          update: (_, settings, prev) => prev!..reloadIfNeeded(settings.devMode),
        ),
        ChangeNotifierProvider(
          create: (_) => SubscriptionProvider()..init(),
        ),
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
      ],
      child: _ThemedApp(storage: storage, systemFont: systemFont),
    );
  }
}

class _ThemedApp extends StatefulWidget {
  final StorageService storage;
  final String systemFont;

  const _ThemedApp({required this.storage, required this.systemFont});

  @override
  State<_ThemedApp> createState() => _ThemedAppState();
}

class _ThemedAppState extends State<_ThemedApp> {
  // Cached once — prevents StreamBuilder from resubscribing on every theme
  // rebuild, which would briefly show a loading state and reset LayoutScreen.
  late final Stream<User?> _authStream =
      FirebaseAuth.instance.authStateChanges();

  @override
  Widget build(BuildContext context) {
    final colorSeed = context.select<AppSettingsProvider, Color>((s) => s.colorSeed);
    final themeMode = context.select<AppSettingsProvider, ThemeMode>((s) => s.themeMode);

    return MaterialApp(
      title: 'WLLT',
      theme: AppTheme.fromSeed(colorSeed, Brightness.light, fontFamily: widget.systemFont),
      darkTheme: AppTheme.fromSeed(colorSeed, Brightness.dark, fontFamily: widget.systemFont),
      themeMode: themeMode,
      home: StreamBuilder<User?>(
        stream: _authStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final signedIn = snapshot.data != null;
          if (signedIn && widget.storage.isOnboardingComplete) {
            return const LayoutScreen();
          }
          return const OnboardingFlow();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
