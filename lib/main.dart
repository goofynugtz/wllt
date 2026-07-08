import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'
    if (dart.library.html) 'platform/ads_web.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart'
    if (dart.library.html) 'platform/sharing_web.dart';
import 'package:workmanager/workmanager.dart'
    if (dart.library.html) 'platform/workmanager_web.dart';

import 'firebase_options.dart';
import 'platform/callback_dispatcher.dart';
import 'providers/account_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/app_settings_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/sms_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/suggested_actions_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/user_preferences_provider.dart';
import 'screens/layout_screen.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'services/auth_service.dart';
import 'services/exchange_rate_service.dart';
import 'services/purchase_service.dart';
import 'services/sms_pending_store.dart';
import 'services/storage_service.dart';
import 'services/system_font_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: kIsWeb ? DefaultFirebaseOptions.web : null,
  );

  if (!kIsWeb) {
    await MobileAds.instance.initialize();
    await PurchaseService.instance.initialize();
  }

  await Hive.initFlutter();

  final storage = StorageService();
  await storage.init();
  await ExchangeRateService.instance.init();

  final smsPendingStore = SmsPendingStore();
  await smsPendingStore.init();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      'sms_scan_task',
      'sms_scan_task',
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.notRequired),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  final systemFont = await SystemFontService.loadSystemFont();

  // Detect demo mode from ?demo=true URL param (web only, for iframe embeds).
  bool startInDemoMode = false;
  if (kIsWeb) {
    startInDemoMode = Uri.base.queryParameters['demo'] == 'true';
  }

  runApp(WalletApp(
    storage: storage,
    systemFont: systemFont,
    smsPendingStore: smsPendingStore,
    startInDemoMode: startInDemoMode,
  ));
}

class WalletApp extends StatelessWidget {
  final StorageService storage;
  final String systemFont;
  final SmsPendingStore smsPendingStore;
  final bool startInDemoMode;

  const WalletApp({
    super.key,
    required this.storage,
    required this.systemFont,
    required this.smsPendingStore,
    this.startInDemoMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final p = AppSettingsProvider(storage);
            if (startInDemoMode) p.setDemoMode(true);
            return p;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => UserPreferencesProvider(storage),
        ),
        ChangeNotifierProxyProvider<AppSettingsProvider, TransactionProvider>(
          create: (_) => TransactionProvider(
            storage,
            devMode: storage.devMode,
            cloudUid: kIsWeb && !startInDemoMode ? currentUid : null,
          ),
          update: (_, settings, prev) =>
              prev!..reloadIfNeeded(settings.devMode || settings.demoMode),
        ),
        ChangeNotifierProxyProvider<AppSettingsProvider, AccountProvider>(
          create: (_) => AccountProvider(
            storage,
            devMode: storage.devMode,
            cloudUid: kIsWeb && !startInDemoMode ? currentUid : null,
          ),
          update: (_, settings, prev) =>
              prev!..reloadIfNeeded(settings.devMode || settings.demoMode),
        ),
        ChangeNotifierProxyProvider<AppSettingsProvider, BudgetProvider>(
          create: (_) => BudgetProvider(storage, devMode: storage.devMode),
          update: (_, settings, prev) =>
              prev!..reloadIfNeeded(settings.devMode || settings.demoMode),
        ),
        ChangeNotifierProvider(
          create: (_) => kIsWeb
              ? SubscriptionProvider()
              : (SubscriptionProvider()..init()),
        ),
        ChangeNotifierProxyProvider<SubscriptionProvider, AiProvider>(
          create: (_) => AiProvider(storage),
          update: (_, sub, prev) {
            prev!.updateIsPro(sub.isPro);
            return prev;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => SuggestedActionsProvider()..init(),
        ),
        ChangeNotifierProvider<ExchangeRateService>.value(
          value: ExchangeRateService.instance,
        ),
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        ChangeNotifierProxyProvider3<TransactionProvider, AccountProvider,
            UserPreferencesProvider, SmsProvider>(
          create: (ctx) => SmsProvider(
            store: smsPendingStore,
            transactions: ctx.read<TransactionProvider>(),
            accounts: ctx.read<AccountProvider>(),
            prefs: ctx.read<UserPreferencesProvider>(),
            storage: storage,
          ),
          update: (_, tx, acc, prefs, prev) => prev!,
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
  late final Stream<User?> _authStream =
      FirebaseAuth.instance.authStateChanges();

  StreamSubscription<User?>? _authSub;
  StreamSubscription? _sharingSubscription;

  @override
  void initState() {
    super.initState();

    _authSub = _authStream.listen((user) {
      if (!kIsWeb) {
        if (user != null) {
          PurchaseService.instance.loginUser(user.uid);
        } else {
          PurchaseService.instance.logoutUser();
        }
      }
      // Wire Firestore cloud storage on sign-in.
      // Web: loads Firestore data. Mobile: enables write-through.
      if (user != null && mounted) {
        context.read<TransactionProvider>().setCloudUid(user.uid);
        context.read<AccountProvider>().setCloudUid(user.uid);
      }
    });

    if (!kIsWeb) {
      _sharingSubscription =
          ReceiveSharingIntent.instance.getMediaStream().listen((event) {
        for (final item in event) {
          if (item.type == SharedMediaType.text && item.message != null) {
            _handleSharedText(item.message!);
          }
        }
      });

      ReceiveSharingIntent.instance.getInitialMedia().then((event) {
        for (final item in event) {
          if (item.type == SharedMediaType.text && item.message != null) {
            _handleSharedText(item.message!);
          }
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AiProvider>().init();
    });
  }

  void _handleSharedText(String text) {
    if (text.isEmpty || !mounted) return;
    context.read<SmsProvider>().processRawSms('shared', text, null);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _sharingSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorSeed =
        context.select<AppSettingsProvider, Color>((s) => s.colorSeed);
    final themeMode =
        context.select<AppSettingsProvider, ThemeMode>((s) => s.themeMode);
    final demoMode =
        context.select<AppSettingsProvider, bool>((s) => s.demoMode);

    return MaterialApp(
      title: 'WLLT',
      theme: AppTheme.fromSeed(colorSeed, Brightness.light,
          fontFamily: widget.systemFont),
      darkTheme: AppTheme.fromSeed(colorSeed, Brightness.dark,
          fontFamily: widget.systemFont),
      themeMode: themeMode,
      home: demoMode
          ? const LayoutScreen()
          : StreamBuilder<User?>(
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
