import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:workmanager/workmanager.dart';

import 'models/models.dart';
import 'models/pending_sms_transaction.dart';
import 'providers/account_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/app_settings_provider.dart';
import 'providers/budget_provider.dart';
import 'providers/sms_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/user_preferences_provider.dart';
import 'screens/layout_screen.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'services/auth_service.dart';
import 'services/exchange_rate_service.dart';
import 'services/purchase_service.dart';
import 'services/sms_filter.dart';
import 'services/sms_parser.dart';
import 'services/sms_pending_store.dart';
import 'services/sms_reader.dart';
import 'services/sms_rules_engine.dart';
import 'services/sms_validator.dart';
import 'services/storage_service.dart';
import 'services/system_font_service.dart';
import 'theme/app_theme.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task != 'sms_scan_task') return true;
    await Hive.initFlutter();
    final store = SmsPendingStore();
    await store.init();
    final lastTs = store.lastScanTs ?? DateTime.now().subtract(const Duration(days: 30));
    final messages = await SmsReader.readSince(lastTs);
    for (final msg in messages) {
      final hash = _hashBody(msg.body);
      final dedup = store.checkDuplicate(msg.id, hash);
      if (dedup != DedupResult.newMessage) continue;
      final verdict = SmsValidator.validate(msg.sender, msg.body);
      if (verdict == SmsVerdict.blocked) continue;
      if (!SmsFilter.isFinancial(msg.sender, msg.body)) continue;
      final parsed = SmsParser.parse(msg.sender, msg.body);
      final item = PendingSmsTransaction(
        id: msg.id ?? hash,
        rawSms: msg.body,
        merchant: parsed?.merchant,
        amount: parsed?.amount,
        type: parsed?.type ?? TransactionType.expense,
        categoryId: SmsRulesEngine.categorize(parsed?.merchant),
        accountHint: parsed?.accountHint,
        parsedAt: DateTime.now(),
        isUnparsed: parsed == null,
        verdict: verdict,
      );
      await store.add(item, smsId: msg.id, contentHash: hash);
    }
    await store.setLastScanTs(DateTime.now());
    return true;
  });
}

String _hashBody(String body) {
  final normalized = body.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  return sha256.convert(utf8.encode(normalized)).toString();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await MobileAds.instance.initialize();
  await PurchaseService.instance.initialize();
  await Hive.initFlutter();

  final storage = StorageService();
  await storage.init();
  await ExchangeRateService.instance.init();

  final smsPendingStore = SmsPendingStore();
  await smsPendingStore.init();

  if (defaultTargetPlatform == TargetPlatform.android) {
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

  runApp(WalletApp(storage: storage, systemFont: systemFont, smsPendingStore: smsPendingStore));
}

class WalletApp extends StatelessWidget {
  final StorageService storage;
  final String systemFont;
  final SmsPendingStore smsPendingStore;

  const WalletApp({
    super.key,
    required this.storage,
    required this.systemFont,
    required this.smsPendingStore,
  });

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
        ChangeNotifierProxyProvider<AppSettingsProvider, BudgetProvider>(
          create: (_) => BudgetProvider(storage, devMode: storage.devMode),
          update: (_, settings, prev) => prev!..reloadIfNeeded(settings.devMode),
        ),
        ChangeNotifierProvider(
          create: (_) => SubscriptionProvider()..init(),
        ),
        ChangeNotifierProxyProvider<SubscriptionProvider, AiProvider>(
          create: (_) => AiProvider(storage),
          update: (_, sub, prev) {
            prev!.updateIsPro(sub.isPro);
            return prev;
          },
        ),
        ChangeNotifierProvider<ExchangeRateService>.value(
          value: ExchangeRateService.instance,
        ),
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        ChangeNotifierProxyProvider3<TransactionProvider, AccountProvider, UserPreferencesProvider, SmsProvider>(
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
      if (user != null) {
        PurchaseService.instance.loginUser(user.uid);
      } else {
        PurchaseService.instance.logoutUser();
      }
    });

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AiProvider>().init();
    });
  }

  void _handleSharedText(String text) {
    if (text.isEmpty || !mounted) return;
    final sms = context.read<SmsProvider>();
    sms.processRawSms('shared', text, null);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _sharingSubscription?.cancel();
    super.dispose();
  }

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
