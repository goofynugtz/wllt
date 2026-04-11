import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'providers/user_preferences_provider.dart';
import 'screens/layout_screen.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Hive.initFlutter();

  final storage = StorageService();
  await storage.init();

  runApp(WalletApp(storage: storage));
}

class WalletApp extends StatelessWidget {
  final StorageService storage;

  const WalletApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => UserPreferencesProvider(storage),
        ),
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
      ],
      child: MaterialApp(
        title: 'WLLT',
        theme: AppTheme.lightTheme,
        home: storage.isOnboardingComplete
            ? const LayoutScreen()
            : const OnboardingFlow(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
