import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'providers/app_settings_provider.dart';
import 'providers/user_preferences_provider.dart';
import 'screens/layout_screen.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'services/system_font_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
      ],
      child: Consumer<AppSettingsProvider>(
        builder: (context, settings, _) => MaterialApp(
          title: 'WLLT',
          theme: AppTheme.fromSeed(
            settings.colorSeed,
            Brightness.light,
            fontFamily: systemFont,
          ),
          darkTheme: AppTheme.fromSeed(
            settings.colorSeed,
            Brightness.dark,
            fontFamily: systemFont,
          ),
          themeMode: settings.themeMode,
          home: storage.isOnboardingComplete
              ? const LayoutScreen()
              : const OnboardingFlow(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
