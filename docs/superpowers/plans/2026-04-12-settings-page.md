# Settings Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fully functional Settings screen as a 5th bottom nav tab with live theme mode switching (Light/System/Dark), 8-color scheme selection, currency picker, categories navigation, and data reset.

**Architecture:** A new `AppSettingsProvider` manages `ThemeMode` and `Color colorSeed`, persisted via two new Hive keys in `StorageService`. `WalletApp` in `main.dart` wraps `MaterialApp` in a `Consumer<AppSettingsProvider>` so theme + themeMode update instantly. `SettingsScreen` is a stateless widget consuming both providers.

**Tech Stack:** Flutter, Dart, Provider, Hive (persistence), lucide_icons, flutter_test (unit tests)

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `lib/services/storage_service.dart` | Add `keyThemeMode`, `keyColorSeed`, getters, setters, `clearAll()` |
| Modify | `lib/theme/app_theme.dart` | Add `darkTheme()` and `fromSeed()` factory |
| Create | `lib/providers/app_settings_provider.dart` | `ThemeMode` + `Color colorSeed` state, persists via storage |
| Modify | `lib/main.dart` | Add `AppSettingsProvider` to tree, `Consumer` wraps `MaterialApp` |
| Create | `lib/screens/currency_picker_screen.dart` | Standalone currency picker screen (search + list) |
| Create | `lib/screens/settings_screen.dart` | Full settings UI with all sections |
| Modify | `lib/screens/layout_screen.dart` | Add 5th Settings tab + screen |
| Create | `test/services/storage_service_theme_test.dart` | Tests for new storage methods |
| Create | `test/providers/app_settings_provider_test.dart` | Tests for AppSettingsProvider |

---

### Task 1: StorageService — theme mode + color seed + clearAll

**Files:**
- Modify: `lib/services/storage_service.dart`
- Create: `test/services/storage_service_theme_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/services/storage_service_theme_test.dart`:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wllt/services/storage_service.dart';

void main() {
  late Directory tempDir;
  late StorageService storage;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('wllt_theme_test_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
  });

  tearDown(() async => Hive.close());
  tearDownAll(() => tempDir.deleteSync(recursive: true));

  group('themeMode', () {
    test('defaults to system', () {
      expect(storage.themeMode, ThemeMode.system);
    });

    test('setThemeMode persists light', () async {
      await storage.setThemeMode(ThemeMode.light);
      expect(storage.themeMode, ThemeMode.light);
    });

    test('setThemeMode persists dark', () async {
      await storage.setThemeMode(ThemeMode.dark);
      expect(storage.themeMode, ThemeMode.dark);
    });

    test('setThemeMode persists system', () async {
      await storage.setThemeMode(ThemeMode.dark);
      await storage.setThemeMode(ThemeMode.system);
      expect(storage.themeMode, ThemeMode.system);
    });
  });

  group('colorSeed', () {
    test('defaults to violet 0xFF6750A4', () {
      expect(storage.colorSeed, const Color(0xFF6750A4));
    });

    test('setColorSeed persists color', () async {
      await storage.setColorSeed(const Color(0xFF006874));
      expect(storage.colorSeed, const Color(0xFF006874));
    });
  });

  group('clearAll', () {
    test('resets themeMode to system default', () async {
      await storage.setThemeMode(ThemeMode.dark);
      await storage.clearAll();
      expect(storage.themeMode, ThemeMode.system);
    });

    test('resets colorSeed to violet default', () async {
      await storage.setColorSeed(const Color(0xFF006874));
      await storage.clearAll();
      expect(storage.colorSeed, const Color(0xFF6750A4));
    });

    test('resets currency to USD', () async {
      await storage.setCurrency('EUR');
      await storage.clearAll();
      expect(storage.currency, 'USD');
    });

    test('resets onboarding flag', () async {
      await storage.setOnboardingComplete();
      await storage.clearAll();
      expect(storage.isOnboardingComplete, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```
cd D:/Projects/Prototypes/HireAlrt/mobile/wllt
flutter test test/services/storage_service_theme_test.dart
```

Expected: compilation error or failures — `themeMode`, `colorSeed`, `setThemeMode`, `setColorSeed`, `clearAll` don't exist yet.

- [ ] **Step 3: Add the new keys, getters, setters, and clearAll to StorageService**

In `lib/services/storage_service.dart`, add the import at the top and then new members. The file already imports `hive_flutter` and `shared_preferences`. Add `flutter/material.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
```

Add new key constants after `keyOnboardingComplete`:

```dart
  static const String keyThemeMode  = 'theme_mode';
  static const String keyColorSeed  = 'color_seed';
```

Add new getters after the `setOnboardingComplete` method:

```dart
  // ── Theme mode ────────────────────────────────────────────────────────
  ThemeMode get themeMode {
    switch (_userPrefs.get(keyThemeMode) as String?) {
      case 'light': return ThemeMode.light;
      case 'dark':  return ThemeMode.dark;
      default:      return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) {
    final val = switch (mode) {
      ThemeMode.light  => 'light',
      ThemeMode.dark   => 'dark',
      ThemeMode.system => 'system',
    };
    return _userPrefs.put(keyThemeMode, val);
  }

  // ── Color seed ────────────────────────────────────────────────────────
  Color get colorSeed {
    final raw = _userPrefs.get(keyColorSeed) as int?;
    return raw != null ? Color(raw) : const Color(0xFF6750A4);
  }

  Future<void> setColorSeed(Color color) =>
      _userPrefs.put(keyColorSeed, color.value);

  // ── Reset ─────────────────────────────────────────────────────────────
  Future<void> clearAll() async {
    await _userPrefs.clear();
    await _categories.clear();
    await _prefs.remove(keyOnboardingComplete);
  }
```

- [ ] **Step 4: Run tests — expect all to pass**

```
flutter test test/services/storage_service_theme_test.dart
```

Expected output: all tests pass (12 tests).

---

### Task 2: AppTheme — darkTheme + fromSeed

**Files:**
- Modify: `lib/theme/app_theme.dart`

- [ ] **Step 1: Add `darkTheme()` and `fromSeed()` to AppTheme**

In `lib/theme/app_theme.dart`, add these two static methods after `lightTheme`:

```dart
  static ThemeData darkTheme({String fontFamily = 'sans-serif'}) => ThemeData(
        useMaterial3: true,
        fontFamily: fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: backgroundDark,
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundDark,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );

  static ThemeData fromSeed(
    Color seed,
    Brightness brightness, {
    String fontFamily = 'sans-serif',
  }) =>
      ThemeData(
        useMaterial3: true,
        fontFamily: fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: brightness,
        ),
        scaffoldBackgroundColor:
            brightness == Brightness.dark ? backgroundDark : backgroundLight,
        appBarTheme: AppBarTheme(
          backgroundColor:
              brightness == Brightness.dark ? backgroundDark : backgroundLight,
          foregroundColor:
              brightness == Brightness.dark ? Colors.white : textPrimary,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: brightness == Brightness.dark ? Colors.white : textPrimary,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: seed,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
```

- [ ] **Step 2: Verify compilation**

```
flutter analyze lib/theme/app_theme.dart
```

Expected: no errors.

---

### Task 3: AppSettingsProvider

**Files:**
- Create: `lib/providers/app_settings_provider.dart`
- Create: `test/providers/app_settings_provider_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/providers/app_settings_provider_test.dart`:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wllt/providers/app_settings_provider.dart';
import 'package:wllt/services/storage_service.dart';

void main() {
  late Directory tempDir;
  late StorageService storage;
  late AppSettingsProvider provider;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('wllt_appsettings_test_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    provider = AppSettingsProvider(storage);
  });

  tearDown(() async => Hive.close());
  tearDownAll(() => tempDir.deleteSync(recursive: true));

  group('initial state', () {
    test('themeMode defaults to system', () {
      expect(provider.themeMode, ThemeMode.system);
    });

    test('colorSeed defaults to violet', () {
      expect(provider.colorSeed, const Color(0xFF6750A4));
    });
  });

  group('setThemeMode', () {
    test('updates themeMode and notifies listeners', () async {
      bool notified = false;
      provider.addListener(() => notified = true);
      await provider.setThemeMode(ThemeMode.dark);
      expect(provider.themeMode, ThemeMode.dark);
      expect(notified, isTrue);
    });
  });

  group('setColorSeed', () {
    test('updates colorSeed and notifies listeners', () async {
      bool notified = false;
      provider.addListener(() => notified = true);
      await provider.setColorSeed(const Color(0xFF006874));
      expect(provider.colorSeed, const Color(0xFF006874));
      expect(notified, isTrue);
    });
  });

  group('resetAllData', () {
    test('clears storage and notifies listeners', () async {
      await provider.setThemeMode(ThemeMode.dark);
      await provider.setColorSeed(const Color(0xFF006874));
      bool notified = false;
      provider.addListener(() => notified = true);
      await provider.resetAllData();
      expect(provider.themeMode, ThemeMode.system);
      expect(provider.colorSeed, const Color(0xFF6750A4));
      expect(notified, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run tests — confirm they fail**

```
flutter test test/providers/app_settings_provider_test.dart
```

Expected: file not found / compilation error.

- [ ] **Step 3: Create AppSettingsProvider**

Create `lib/providers/app_settings_provider.dart`:

```dart
import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class AppSettingsProvider extends ChangeNotifier {
  final StorageService _storage;

  AppSettingsProvider(this._storage);

  ThemeMode get themeMode  => _storage.themeMode;
  Color     get colorSeed  => _storage.colorSeed;

  Future<void> setThemeMode(ThemeMode mode) async {
    await _storage.setThemeMode(mode);
    notifyListeners();
  }

  Future<void> setColorSeed(Color color) async {
    await _storage.setColorSeed(color);
    notifyListeners();
  }

  /// Clears all Hive boxes + SharedPreferences and resets in-memory state.
  Future<void> resetAllData() async {
    await _storage.clearAll();
    notifyListeners();
  }
}
```

- [ ] **Step 4: Run tests — expect all to pass**

```
flutter test test/providers/app_settings_provider_test.dart
```

Expected: 6 tests pass.

---

### Task 4: Wire AppSettingsProvider into main.dart

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Update main.dart**

Replace the full content of `lib/main.dart` with:

```dart
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
        builder: (_, settings, __) => MaterialApp(
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
```

- [ ] **Step 2: Verify compilation**

```
flutter analyze lib/main.dart
```

Expected: no errors.

---

### Task 5: CurrencyPickerScreen — standalone screen

**Files:**
- Create: `lib/screens/currency_picker_screen.dart`

- [ ] **Step 1: Create the file**

Create `lib/screens/currency_picker_screen.dart`:

```dart
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../data/currencies.dart';
import '../providers/user_preferences_provider.dart';
import '../theme/app_theme.dart';

class CurrencyPickerScreen extends StatefulWidget {
  const CurrencyPickerScreen({super.key});

  @override
  State<CurrencyPickerScreen> createState() => _CurrencyPickerScreenState();
}

class _CurrencyPickerScreenState extends State<CurrencyPickerScreen> {
  String _query = '';
  late String _selectedCode;

  @override
  void initState() {
    super.initState();
    _selectedCode = context.read<UserPreferencesProvider>().currency;
  }

  List<CurrencyInfo> get _filtered {
    if (_query.isEmpty) return kCurrencies;
    final q = _query.toLowerCase();
    return kCurrencies
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.code.toLowerCase().contains(q) ||
            c.country.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _select(String code) async {
    setState(() => _selectedCode = code);
    await context.read<UserPreferencesProvider>().setCurrency(code);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Currency',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search currencies...',
                hintStyle: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.textTertiary,
                ),
                prefixIcon: const Icon(
                  LucideIcons.search,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.searchX,
                          size: 36,
                          color: AppTheme.textTertiary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No results for "$_query"',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final c = filtered[i];
                      return _CurrencyRow(
                        currency: c,
                        isSelected: c.code == _selectedCode,
                        onTap: () => _select(c.code),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyRow extends StatelessWidget {
  final CurrencyInfo currency;
  final bool isSelected;
  final VoidCallback onTap;

  const _CurrencyRow({
    required this.currency,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5EFF7) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CountryFlag.fromCountryCode(
              currency.countryCode,
              height: 24,
              width: 34,
              shape: const RoundedRectangle(4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currency.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    '${currency.code} · ${currency.symbol} · ${currency.country}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.check,
                  size: 14,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

```
flutter analyze lib/screens/currency_picker_screen.dart
```

Expected: no errors.

---

### Task 6: SettingsScreen — full implementation

**Files:**
- Create: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Create the file**

Create `lib/screens/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/app_settings_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../screens/categories_screen.dart';
import '../screens/currency_picker_screen.dart';
import '../screens/onboarding/onboarding_flow.dart';
import '../theme/app_theme.dart';

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
    final settings = context.watch<AppSettingsProvider>();
    final prefs    = context.watch<UserPreferencesProvider>();

    final activeScheme = _kColorSchemes.firstWhere(
      (s) => s.seed.value == settings.colorSeed.value,
      orElse: () => _kColorSchemes.first,
    );
    final paletteName = Theme.of(context).brightness == Brightness.dark
        ? 'Dark palette'
        : 'Light palette';

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(context, prefs),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildSectionLabel('Appearance')),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: _buildAppearanceCard(context, settings),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildSectionLabel('Color Scheme')),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: _buildColorSchemeCard(
                context,
                settings,
                activeScheme,
                paletteName,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildSectionLabel('Preferences')),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: _buildPreferencesCard(context, prefs),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: _buildSectionLabel('Account & Data'),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: _buildAccountCard(context, settings, prefs),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(child: _buildSectionLabel('About')),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(child: _buildAboutCard()),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  // ── Sections ──────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, UserPreferencesProvider prefs) {
    final isOffline = prefs.authMode == 'offline';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.settings,
              size: 20,
              color: AppTheme.onSurfaceColor,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.55,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'WLLT v1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
            decoration: BoxDecoration(
              color: isOffline
                  ? const Color(0xFFFFF8E1)
                  : const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isOffline
                    ? const Color(0x4DF59E0B)
                    : const Color(0x4D4CAF50),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOffline ? LucideIcons.wifiOff : LucideIcons.wifi,
                  size: 12,
                  color: isOffline
                      ? const Color(0xFF92400E)
                      : const Color(0xFF1B5E20),
                ),
                const SizedBox(width: 6),
                Text(
                  isOffline ? 'Offline' : 'Online',
                  style: TextStyle(
                    fontSize: 11,
                    color: isOffline
                        ? const Color(0xFF92400E)
                        : const Color(0xFF1B5E20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(label.toUpperCase(), style: AppTheme.trackingWide),
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
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 0,
              childAspectRatio: 72.5 / 75.75,
              children: _kColorSchemes.map((scheme) {
                return _ColorSwatch(
                  scheme: scheme,
                  isSelected:
                      scheme.seed.value == settings.colorSeed.value,
                  onTap: () => context
                      .read<AppSettingsProvider>()
                      .setColorSeed(scheme.seed),
                );
              }).toList(),
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
            value: prefs.currency,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CurrencyPickerScreen(),
              ),
            ),
          ),
          const Divider(height: 0.5, color: AppTheme.borderColor, indent: 16, endIndent: 16),
          _SettingsTappableRow(
            icon: LucideIcons.tag,
            label: 'Categories',
            value: '${prefs.activeCategories.length} categories',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CategoriesScreen()),
            ),
          ),
        ],
      ),
    );
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
          const Divider(height: 0.5, color: AppTheme.borderColor, indent: 16, endIndent: 16),
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

  Widget _buildAboutCard() {
    return _SettingsCard(
      child: Padding(
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
              child: const Icon(
                LucideIcons.wallet,
                size: 26,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WLLT: Expense Tracker',
                  style: TextStyle(
                    fontSize: 17,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Built with ♥ using Flutter',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFCAC4D0),
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

// ── Private reusable widgets ──────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 8,
            offset: Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }
}

/// Non-interactive info row used in card headers (e.g. "App theme / Always light").
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
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 18,
              color: iconColor ?? AppTheme.onSurfaceColor,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tappable row with optional right-side value label and chevron.
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
                color: iconBgColor ?? AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 18,
                color: iconColor ?? AppTheme.onSurfaceColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: labelColor ?? AppTheme.textPrimary,
                ),
              ),
            ),
            if (value != null) ...[
              Text(
                value!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textTertiary,
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: AppTheme.textTertiary,
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
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 18, color: AppTheme.onSurfaceColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Theme mode toggle ─────────────────────────────────────────────────────────

class _ThemeModeToggle extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeModeToggle({
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFE8E0EC),
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
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
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
                    ? AppTheme.textPrimary
                    : AppTheme.textTertiary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? AppTheme.textPrimary
                      : AppTheme.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Color swatch ──────────────────────────────────────────────────────────────

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
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isSelected ? null : scheme.container,
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.seed.withOpacity(0.8),
                        scheme.seed,
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: scheme.seed.withOpacity(0.33),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(LucideIcons.check, size: 22, color: Colors.white)
                : Center(
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: scheme.onContainer,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            scheme.name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isSelected ? scheme.seed : AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

```
flutter analyze lib/screens/settings_screen.dart
```

Expected: no errors.

---

### Task 7: layout_screen.dart — add 5th Settings tab

**Files:**
- Modify: `lib/screens/layout_screen.dart`

- [ ] **Step 1: Add import and settings screen to layout**

In `lib/screens/layout_screen.dart`, add the import after the existing imports:

```dart
import '../screens/settings_screen.dart';
```

In `initState`, add `const SettingsScreen()` as the 5th element of `_screens`:

```dart
    _screens = [
      HomeScreen(
        onNavigateToHistory: () => _navigateToTab(1),
        pageScrollEnabled: _pageScrollEnabled,
      ),
      const TransactionsScreen(),
      const AnalyticsScreen(),
      const AccountsScreen(),
      const SettingsScreen(),
    ];
```

In the `_navItems` list, add the Settings item:

```dart
  final List<NavItem> _navItems = [
    const NavItem(icon: LucideIcons.layoutDashboard, label: 'Home'),
    const NavItem(icon: LucideIcons.arrowLeftRight, label: 'History'),
    const NavItem(icon: LucideIcons.barChart2, label: 'Analytics'),
    const NavItem(icon: LucideIcons.wallet, label: 'Accounts'),
    const NavItem(icon: LucideIcons.settings, label: 'Settings'),
  ];
```

In `_buildFab`, add a null return for index 4 (Settings has no FAB):

```dart
  Widget? _buildFab() {
    // Analytics — nothing to add here
    if (_currentIndex == 2) return null;

    // Settings — no FAB
    if (_currentIndex == 4) return null;

    // Accounts — simple add-account button
    if (_currentIndex == 3) {
```

- [ ] **Step 2: Verify full compilation**

```
flutter analyze lib/
```

Expected: no errors across the entire lib directory.

- [ ] **Step 3: Run all tests**

```
flutter test
```

Expected: all existing tests pass plus the 18 new tests from Tasks 1 and 3.

---

## Self-Review Checklist

- [x] **StorageService** — `themeMode`, `colorSeed`, `setThemeMode`, `setColorSeed`, `clearAll` — Task 1
- [x] **AppTheme.fromSeed + darkTheme** — Task 2
- [x] **AppSettingsProvider** — Task 3
- [x] **main.dart Consumer wrapping MaterialApp with themeMode** — Task 4
- [x] **CurrencyPickerScreen** (standalone, navigatable from Settings) — Task 5
- [x] **SettingsScreen** — all 5 sections: Appearance, Color Scheme, Preferences, Account & Data, About — Task 6
- [x] **5th tab in layout_screen** — Task 7
- [x] **Reset all data** clears both Hive boxes + SharedPreferences key, navigates to OnboardingFlow — Task 6 `_showResetConfirmation`
- [x] **FAB suppressed** on Settings tab — Task 7
