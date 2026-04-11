# Onboarding Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a 3-screen first-launch onboarding flow with Google OAuth or offline mode, currency selection with locale auto-detect, and category selection with Hive local storage and Firestore cloud sync.

**Architecture:** `shared_preferences` gates the onboarding flow on cold start. User data (currency, categories, auth mode) is stored in Hive and optionally synced to Firestore in real-time via `SyncService` when signed in. A `UserPreferencesProvider` (ChangeNotifier) exposes preferences app-wide.

**Tech Stack:** Flutter, Hive + hive_flutter, shared_preferences, google_sign_in, firebase_auth, cloud_firestore, lucide_icons (existing), flutter_svg (existing), Provider (existing), mocktail (dev)

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `pubspec.yaml` | Modify | Add 6 deps + mocktail dev dep |
| `lib/models/models.dart` | Modify | Update Category model; replace 11 → 18 categories; remap transaction categoryIds |
| `lib/widgets/category_icon_widget.dart` | Create | Renders SVG asset or Lucide icon based on category type |
| `lib/screens/onboarding/onboarding_shared_widgets.dart` | Create | `OnboardingProgressBar` shared across pages 2 & 3 |
| `lib/data/currencies.dart` | Create | ISO currency list + locale-to-code mapping + auto-detect function |
| `lib/services/storage_service.dart` | Create | Hive + SharedPreferences read/write abstraction |
| `lib/services/auth_service.dart` | Create | google_sign_in + firebase_auth wrapper |
| `lib/services/sync_service.dart` | Create | Firestore ↔ Hive bidirectional sync with real-time listener |
| `lib/providers/user_preferences_provider.dart` | Create | ChangeNotifier over StorageService; owns SyncService lifecycle |
| `lib/main.dart` | Modify | Async init: Firebase + Hive + StorageService; onboarding routing |
| `lib/screens/onboarding/onboarding_flow.dart` | Create | PageView + PageController; physics locked |
| `lib/screens/onboarding/onboarding_page1_screen.dart` | Create | Welcome + Google/Offline auth + T&C checkbox |
| `lib/screens/onboarding/onboarding_page2_screen.dart` | Create | Currency picker: locale detect, search, scrollable list |
| `lib/screens/onboarding/onboarding_page3_screen.dart` | Create | 2-col category grid: toggle, select all, Get Started |
| `test/services/storage_service_test.dart` | Create | Unit tests for StorageService |
| `test/providers/user_preferences_provider_test.dart` | Create | Unit tests for UserPreferencesProvider |

---

### Task 1: Add dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add packages**

Open `pubspec.yaml`. Under `dependencies:`, after the `flutter_svg` line, add:

```yaml
  # Storage
  shared_preferences: ^2.3.0
  hive: ^2.2.3
  hive_flutter: ^1.1.0

  # Auth & Cloud
  google_sign_in: ^6.2.0
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.0
  cloud_firestore: ^5.4.0
```

Under `dev_dependencies:`, after `flutter_lints`, add:

```yaml
  mocktail: ^1.0.4
```

- [ ] **Step 2: Install**

```bash
flutter pub get
```

Expected: `Got dependencies!` with no errors.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add onboarding dependencies (hive, firebase, google_sign_in, mocktail)"
```

---

### Task 2: Firebase platform setup (manual)

> These steps cannot be automated — they require a Google account and browser. Complete them before continuing.

- [ ] **Step 1: Create Firebase project**

1. Go to https://console.firebase.google.com → create or open a project
2. Enable **Authentication → Sign-in method → Google**
3. Enable **Firestore Database** (start in test mode)

- [ ] **Step 2: Add Android app**

1. In Firebase Console → Project Settings → Add app → Android
2. Package name: check `android/app/build.gradle` for `applicationId` (e.g. `com.example.wllt`)
3. Download `google-services.json` → save to `android/app/google-services.json`
4. Add debug SHA-1 fingerprint (required for Google Sign-In on Android):

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Copy the SHA-1 output into Firebase Console → Project Settings → Android app → SHA certificate fingerprints.

- [ ] **Step 3: Add iOS app**

1. In Firebase Console → Add app → iOS
2. Bundle ID: open `ios/Runner.xcodeproj/project.pbxproj`, search for `PRODUCT_BUNDLE_IDENTIFIER`
3. Download `GoogleService-Info.plist` → save to `ios/Runner/GoogleService-Info.plist`

- [ ] **Step 4: Update android/build.gradle**

In `android/build.gradle`, find `buildscript { dependencies {` and add:

```groovy
classpath 'com.google.gms:google-services:4.4.0'
```

- [ ] **Step 5: Update android/app/build.gradle**

At the very bottom of `android/app/build.gradle`, add:

```groovy
apply plugin: 'com.google.gms.google-services'
```

- [ ] **Step 6: Verify Firebase setup compiles**

```bash
flutter build apk --debug
```

Expected: builds without Firebase errors. Google Sign-In will fail at runtime if SHA-1 is missing — Step 2 must be complete.

---

### Task 3: Update Category model

**Files:**
- Modify: `lib/models/models.dart`

- [ ] **Step 1: Add imports to models.dart**

At the very top of `lib/models/models.dart`, before `enum TransactionType`, add:

```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
```

- [ ] **Step 2: Replace Category class**

Replace the entire `Category` class (from `class Category {` through the closing `}` that ends `getById`) with:

```dart
class Category {
  final String id;
  final String name;
  final String? iconPath;     // SVG asset path — null for Lucide categories
  final IconData? lucideIcon; // Lucide icon — null for SVG categories
  final String color;         // Hex, e.g. "#EBA9A9" — used for icon circle bg
  final String bg;            // Hex light variant — used in existing transaction badges

  const Category({
    required this.id,
    required this.name,
    this.iconPath,
    this.lucideIcon,
    required this.color,
    required this.bg,
  }) : assert(
          iconPath != null || lucideIcon != null,
          'Category must have either iconPath or lucideIcon',
        );

  bool get isLucideIcon => lucideIcon != null;

  /// Backward compat: existing screens that call category.icon still compile.
  String get icon => iconPath ?? '';

  static const List<Category> categories = [
    Category(id: 'shopping',   name: 'Shopping',   iconPath: 'assets/icons/categories/shopping.svg',   color: '#EBA9A9', bg: '#fce4ec'),
    Category(id: 'restaurant', name: 'Restaurant', lucideIcon: LucideIcons.utensils,                   color: '#E2B932', bg: '#fffde7'),
    Category(id: 'work',       name: 'Work',       lucideIcon: LucideIcons.briefcase,                  color: '#74A1DB', bg: '#e3f2fd'),
    Category(id: 'doctor',     name: 'Doctor',     lucideIcon: LucideIcons.activity,                   color: '#9D85E5', bg: '#ede7f6'),
    Category(id: 'coffee',     name: 'Coffee',     lucideIcon: LucideIcons.coffee,                     color: '#70C01F', bg: '#f1f8e9'),
    Category(id: 'movies',     name: 'Movies',     lucideIcon: LucideIcons.film,                       color: '#86D9BC', bg: '#e0f2f1'),
    Category(id: 'transport',  name: 'Transport',  iconPath: 'assets/icons/categories/transport.svg',  color: '#8FC9E2', bg: '#e1f5fe'),
    Category(id: 'groceries',  name: 'Groceries',  iconPath: 'assets/icons/categories/groceries.svg',  color: '#F4A261', bg: '#fff3e0'),
    Category(id: 'utilities',  name: 'Utilities',  iconPath: 'assets/icons/categories/utilities.svg',  color: '#E76F51', bg: '#fbe9e7'),
    Category(id: 'music',      name: 'Music',      lucideIcon: LucideIcons.music,                      color: '#2A9D8F', bg: '#e0f7fa'),
    Category(id: 'travel',     name: 'Travel',     lucideIcon: LucideIcons.plane,                      color: '#FFB703', bg: '#fff8e1'),
    Category(id: 'fitness',    name: 'Fitness',    lucideIcon: LucideIcons.dumbbell,                   color: '#C77FFF', bg: '#f3e5f5'),
    Category(id: 'education',  name: 'Education',  iconPath: 'assets/icons/categories/education.svg',  color: '#06D6A0', bg: '#e8f5e9'),
    Category(id: 'savings',    name: 'Savings',    iconPath: 'assets/icons/categories/savings.svg',    color: '#FB8500', bg: '#fff3e0'),
    Category(id: 'home',       name: 'Home',       lucideIcon: LucideIcons.house,                      color: '#FF6B6B', bg: '#ffebee'),
    Category(id: 'phone',      name: 'Phone',      lucideIcon: LucideIcons.smartphone,                 color: '#4CC9F0', bg: '#e3f2fd'),
    Category(id: 'internet',   name: 'Internet',   lucideIcon: LucideIcons.wifi,                       color: '#A8DADC', bg: '#e0f7fa'),
    Category(id: 'gifts',      name: 'Gifts',      lucideIcon: LucideIcons.gift,                       color: '#E63946', bg: '#ffebee'),
  ];

  static Category getById(String id) {
    return categories.firstWhere(
      (cat) => cat.id == id,
      orElse: () => categories.first,
    );
  }
}
```

> **Note on Lucide icon names:** The `lucide_icons: ^0.257.0` package uses camelCase names. If any icon above causes a compile error (e.g. `LucideIcons.dumbbell` not found), check the package's exported symbol list with `flutter pub deps` and substitute the closest available name.

- [ ] **Step 3: Remap transaction categoryIds**

In `Transaction.transactions`, apply these ID changes (old → new):
- `food` → `restaurant` (affects t3, t5, t8, t22)
- `health` → `doctor` (affects t2)
- `entertainment` → `movies` (affects t7, t13, t18)
- `rent` → `home` (affects t20)
- `income` → `savings` (affects t4, t19, t21)

Go through each transaction and update `categoryId`. Example for t3:
```dart
Transaction(
  id: 't3',
  transactionTitle: 'Blue Tokai',
  categoryId: 'restaurant', // was 'food'
  amount: 220,
  type: TransactionType.expense,
  date: DateTime(2026, 3, 28),
  account: 'Cash',
  tags: ['restaurant'],     // update tags too
),
```

Apply the same pattern to all 11 affected transactions.

- [ ] **Step 4: Verify no compile errors**

```bash
flutter analyze lib/models/models.dart
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/models/models.dart
git commit -m "feat: replace Category model with 18-category design set; remap transaction IDs"
```

---

### Task 4: Create CategoryIconWidget

**Files:**
- Create: `lib/widgets/category_icon_widget.dart`

- [ ] **Step 1: Create widget**

Create `lib/widgets/category_icon_widget.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/models.dart';

/// Renders a category's icon as either an SVG asset or a Lucide icon.
/// The caller controls size and color — this widget only renders the icon shape.
class CategoryIconWidget extends StatelessWidget {
  final Category category;
  final double size;
  final Color color;

  const CategoryIconWidget({
    super.key,
    required this.category,
    this.size = 18,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (category.isLucideIcon) {
      return Icon(category.lucideIcon, size: size, color: color);
    }
    return SvgPicture.asset(
      category.iconPath!,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/widgets/category_icon_widget.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/category_icon_widget.dart
git commit -m "feat: add CategoryIconWidget supporting both SVG and Lucide icons"
```

---

### Task 5: Create shared onboarding widgets

**Files:**
- Create: `lib/screens/onboarding/onboarding_shared_widgets.dart`

- [ ] **Step 1: Create shared widgets file**

Create `lib/screens/onboarding/onboarding_shared_widgets.dart`:

```dart
import 'package:flutter/material.dart';

/// 3-segment progress bar used on pages 2 and 3 of the onboarding flow.
class OnboardingProgressBar extends StatelessWidget {
  final int current; // number of filled segments (1-based)
  final int total;

  const OnboardingProgressBar({
    super.key,
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final filled = i < current;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: filled
                  ? const Color(0xFF6750A4)
                  : const Color(0xFFE8E0EC),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/screens/onboarding/onboarding_shared_widgets.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/onboarding/onboarding_shared_widgets.dart
git commit -m "feat: add OnboardingProgressBar shared widget"
```

---

### Task 6: Create currency data

**Files:**
- Create: `lib/data/currencies.dart`

- [ ] **Step 1: Create currencies.dart**

Create `lib/data/currencies.dart`:

```dart
import 'dart:io' show Platform; // mobile only — not available on web

class CurrencyInfo {
  final String code;
  final String name;
  final String symbol;
  final String flag;
  final String country;

  const CurrencyInfo({
    required this.code,
    required this.name,
    required this.symbol,
    required this.flag,
    required this.country,
  });
}

const List<CurrencyInfo> kCurrencies = [
  CurrencyInfo(code: 'AED', name: 'UAE Dirham',          symbol: 'د.إ',  flag: '🇦🇪', country: 'UAE'),
  CurrencyInfo(code: 'ARS', name: 'Argentine Peso',       symbol: r'$',   flag: '🇦🇷', country: 'Argentina'),
  CurrencyInfo(code: 'AUD', name: 'Australian Dollar',    symbol: 'A\$',  flag: '🇦🇺', country: 'Australia'),
  CurrencyInfo(code: 'BDT', name: 'Bangladeshi Taka',     symbol: '৳',    flag: '🇧🇩', country: 'Bangladesh'),
  CurrencyInfo(code: 'BGN', name: 'Bulgarian Lev',        symbol: 'лв',   flag: '🇧🇬', country: 'Bulgaria'),
  CurrencyInfo(code: 'BHD', name: 'Bahraini Dinar',       symbol: 'BD',   flag: '🇧🇭', country: 'Bahrain'),
  CurrencyInfo(code: 'BRL', name: 'Brazilian Real',       symbol: 'R\$',  flag: '🇧🇷', country: 'Brazil'),
  CurrencyInfo(code: 'CAD', name: 'Canadian Dollar',      symbol: 'CA\$', flag: '🇨🇦', country: 'Canada'),
  CurrencyInfo(code: 'CHF', name: 'Swiss Franc',          symbol: 'Fr',   flag: '🇨🇭', country: 'Switzerland'),
  CurrencyInfo(code: 'CNY', name: 'Chinese Yuan',         symbol: '¥',    flag: '🇨🇳', country: 'China'),
  CurrencyInfo(code: 'CZK', name: 'Czech Koruna',         symbol: 'Kč',   flag: '🇨🇿', country: 'Czech Republic'),
  CurrencyInfo(code: 'DKK', name: 'Danish Krone',         symbol: 'kr',   flag: '🇩🇰', country: 'Denmark'),
  CurrencyInfo(code: 'EGP', name: 'Egyptian Pound',       symbol: '£',    flag: '🇪🇬', country: 'Egypt'),
  CurrencyInfo(code: 'EUR', name: 'Euro',                 symbol: '€',    flag: '🇪🇺', country: 'European Union'),
  CurrencyInfo(code: 'GBP', name: 'British Pound',        symbol: '£',    flag: '🇬🇧', country: 'United Kingdom'),
  CurrencyInfo(code: 'HKD', name: 'Hong Kong Dollar',     symbol: 'HK\$', flag: '🇭🇰', country: 'Hong Kong'),
  CurrencyInfo(code: 'HUF', name: 'Hungarian Forint',     symbol: 'Ft',   flag: '🇭🇺', country: 'Hungary'),
  CurrencyInfo(code: 'IDR', name: 'Indonesian Rupiah',    symbol: 'Rp',   flag: '🇮🇩', country: 'Indonesia'),
  CurrencyInfo(code: 'ILS', name: 'Israeli Shekel',       symbol: '₪',    flag: '🇮🇱', country: 'Israel'),
  CurrencyInfo(code: 'INR', name: 'Indian Rupee',         symbol: '₹',    flag: '🇮🇳', country: 'India'),
  CurrencyInfo(code: 'JPY', name: 'Japanese Yen',         symbol: '¥',    flag: '🇯🇵', country: 'Japan'),
  CurrencyInfo(code: 'KRW', name: 'South Korean Won',     symbol: '₩',    flag: '🇰🇷', country: 'South Korea'),
  CurrencyInfo(code: 'MXN', name: 'Mexican Peso',         symbol: r'$',   flag: '🇲🇽', country: 'Mexico'),
  CurrencyInfo(code: 'MYR', name: 'Malaysian Ringgit',    symbol: 'RM',   flag: '🇲🇾', country: 'Malaysia'),
  CurrencyInfo(code: 'NGN', name: 'Nigerian Naira',       symbol: '₦',    flag: '🇳🇬', country: 'Nigeria'),
  CurrencyInfo(code: 'NOK', name: 'Norwegian Krone',      symbol: 'kr',   flag: '🇳🇴', country: 'Norway'),
  CurrencyInfo(code: 'NZD', name: 'New Zealand Dollar',   symbol: 'NZ\$', flag: '🇳🇿', country: 'New Zealand'),
  CurrencyInfo(code: 'PHP', name: 'Philippine Peso',      symbol: '₱',    flag: '🇵🇭', country: 'Philippines'),
  CurrencyInfo(code: 'PKR', name: 'Pakistani Rupee',      symbol: '₨',    flag: '🇵🇰', country: 'Pakistan'),
  CurrencyInfo(code: 'PLN', name: 'Polish Zloty',         symbol: 'zł',   flag: '🇵🇱', country: 'Poland'),
  CurrencyInfo(code: 'RUB', name: 'Russian Ruble',        symbol: '₽',    flag: '🇷🇺', country: 'Russia'),
  CurrencyInfo(code: 'SAR', name: 'Saudi Riyal',          symbol: '﷼',    flag: '🇸🇦', country: 'Saudi Arabia'),
  CurrencyInfo(code: 'SEK', name: 'Swedish Krona',        symbol: 'kr',   flag: '🇸🇪', country: 'Sweden'),
  CurrencyInfo(code: 'SGD', name: 'Singapore Dollar',     symbol: 'S\$',  flag: '🇸🇬', country: 'Singapore'),
  CurrencyInfo(code: 'THB', name: 'Thai Baht',            symbol: '฿',    flag: '🇹🇭', country: 'Thailand'),
  CurrencyInfo(code: 'TRY', name: 'Turkish Lira',         symbol: '₺',    flag: '🇹🇷', country: 'Turkey'),
  CurrencyInfo(code: 'TWD', name: 'Taiwan Dollar',        symbol: 'NT\$', flag: '🇹🇼', country: 'Taiwan'),
  CurrencyInfo(code: 'USD', name: 'US Dollar',            symbol: r'$',   flag: '🇺🇸', country: 'United States'),
  CurrencyInfo(code: 'VND', name: 'Vietnamese Dong',      symbol: '₫',    flag: '🇻🇳', country: 'Vietnam'),
  CurrencyInfo(code: 'ZAR', name: 'South African Rand',   symbol: 'R',    flag: '🇿🇦', country: 'South Africa'),
];

/// Maps device locale strings (from Platform.localeName) to ISO 4217 codes.
const Map<String, String> kLocaleToCurrency = {
  'en_US': 'USD', 'en_GB': 'GBP', 'en_IN': 'INR', 'en_AU': 'AUD',
  'en_CA': 'CAD', 'en_NZ': 'NZD', 'en_ZA': 'ZAR', 'en_SG': 'SGD',
  'en_HK': 'HKD', 'en_PH': 'PHP', 'en_NG': 'NGN', 'en_PK': 'PKR',
  'en_BD': 'BDT', 'en_EG': 'EGP', 'en_AE': 'AED', 'en_SA': 'SAR',
  'en_BH': 'BHD', 'zh_CN': 'CNY', 'zh_TW': 'TWD', 'zh_HK': 'HKD',
  'ja_JP': 'JPY', 'ko_KR': 'KRW', 'de_DE': 'EUR', 'fr_FR': 'EUR',
  'es_ES': 'EUR', 'it_IT': 'EUR', 'pt_BR': 'BRL', 'pt_PT': 'EUR',
  'ru_RU': 'RUB', 'tr_TR': 'TRY', 'id_ID': 'IDR', 'ms_MY': 'MYR',
  'th_TH': 'THB', 'vi_VN': 'VND', 'ar_SA': 'SAR', 'ar_AE': 'AED',
  'ar_EG': 'EGP', 'sv_SE': 'SEK', 'nb_NO': 'NOK', 'da_DK': 'DKK',
  'pl_PL': 'PLN', 'cs_CZ': 'CZK', 'hu_HU': 'HUF', 'he_IL': 'ILS',
  'bg_BG': 'BGN', 'es_MX': 'MXN', 'es_AR': 'ARS',
};

/// Detects the user's currency from the device locale.
/// Tries exact locale match first (e.g. "en_IN"), then country suffix match.
/// Falls back to "USD" if unrecognised.
String detectCurrencyFromLocale() {
  try {
    final locale = Platform.localeName; // e.g. "en_IN", "zh_CN"
    if (kLocaleToCurrency.containsKey(locale)) {
      return kLocaleToCurrency[locale]!;
    }
    final parts = locale.split('_');
    if (parts.length >= 2) {
      final country = parts.last;
      final match = kLocaleToCurrency.entries.firstWhere(
        (e) => e.key.endsWith('_$country'),
        orElse: () => const MapEntry('', 'USD'),
      );
      return match.value;
    }
  } catch (_) {
    // Platform.localeName unavailable (e.g. test environment)
  }
  return 'USD';
}

/// Returns the [CurrencyInfo] for [code], defaulting to USD if not found.
CurrencyInfo getCurrencyByCode(String code) {
  return kCurrencies.firstWhere(
    (c) => c.code == code,
    orElse: () => kCurrencies.firstWhere((c) => c.code == 'USD'),
  );
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/data/currencies.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/data/currencies.dart
git commit -m "feat: add currency data with locale auto-detection (40 currencies)"
```

---

### Task 7: Create StorageService

**Files:**
- Create: `lib/services/storage_service.dart`
- Create: `test/services/storage_service_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/services/storage_service_test.dart`:

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wllt/services/storage_service.dart';

void main() {
  late Directory tempDir;
  late StorageService storage;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('wllt_storage_test_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
  });

  tearDown(() async => Hive.close());

  tearDownAll(() => tempDir.deleteSync(recursive: true));

  group('onboarding flag', () {
    test('isOnboardingComplete is false by default', () {
      expect(storage.isOnboardingComplete, isFalse);
    });

    test('setOnboardingComplete persists true', () async {
      await storage.setOnboardingComplete();
      expect(storage.isOnboardingComplete, isTrue);
    });
  });

  group('currency', () {
    test('defaults to USD', () {
      expect(storage.currency, 'USD');
    });

    test('setCurrency persists the code', () async {
      await storage.setCurrency('INR');
      expect(storage.currency, 'INR');
    });
  });

  group('auth mode', () {
    test('defaults to offline', () {
      expect(storage.authMode, 'offline');
    });

    test('setAuthMode persists the mode', () async {
      await storage.setAuthMode('google');
      expect(storage.authMode, 'google');
    });
  });

  group('google credentials', () {
    test('googleUid is null by default', () {
      expect(storage.googleUid, isNull);
    });

    test('setGoogleCredentials persists uid and email', () async {
      await storage.setGoogleCredentials(uid: 'uid_abc', email: 'test@gmail.com');
      expect(storage.googleUid, 'uid_abc');
      expect(storage.googleEmail, 'test@gmail.com');
    });
  });

  group('active categories', () {
    test('returns empty list by default', () {
      expect(storage.activeCategories, isEmpty);
    });

    test('setActiveCategories persists the list', () async {
      await storage.setActiveCategories(['shopping', 'transport', 'groceries']);
      expect(storage.activeCategories, ['shopping', 'transport', 'groceries']);
    });
  });
}
```

- [ ] **Step 2: Run tests — confirm they fail**

```bash
flutter test test/services/storage_service_test.dart
```

Expected: compile error — `storage_service.dart` does not exist yet.

- [ ] **Step 3: Create StorageService**

Create `lib/services/storage_service.dart`:

```dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _userPrefsBox = 'user_prefs';
  static const String _categoriesBox = 'active_categories';

  static const String keyCurrency = 'currency';
  static const String keyAuthMode = 'auth_mode';
  static const String keyGoogleUid = 'google_uid';
  static const String keyGoogleEmail = 'google_email';
  static const String keyCategories = 'categories';
  static const String keyOnboardingComplete = 'onboarding_complete';

  late Box _userPrefs;
  late Box _categories;
  late SharedPreferences _prefs;

  Future<void> init() async {
    _userPrefs = await Hive.openBox(_userPrefsBox);
    _categories = await Hive.openBox(_categoriesBox);
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Onboarding ────────────────────────────────────────────────────────
  bool get isOnboardingComplete =>
      _prefs.getBool(keyOnboardingComplete) ?? false;

  Future<void> setOnboardingComplete() =>
      _prefs.setBool(keyOnboardingComplete, true);

  // ── Currency ──────────────────────────────────────────────────────────
  String get currency =>
      (_userPrefs.get(keyCurrency) as String?) ?? 'USD';

  Future<void> setCurrency(String code) =>
      _userPrefs.put(keyCurrency, code);

  // ── Auth ──────────────────────────────────────────────────────────────
  String get authMode =>
      (_userPrefs.get(keyAuthMode) as String?) ?? 'offline';

  Future<void> setAuthMode(String mode) =>
      _userPrefs.put(keyAuthMode, mode);

  String? get googleUid =>
      _userPrefs.get(keyGoogleUid) as String?;

  String? get googleEmail =>
      _userPrefs.get(keyGoogleEmail) as String?;

  Future<void> setGoogleCredentials({
    required String uid,
    required String email,
  }) async {
    await _userPrefs.put(keyGoogleUid, uid);
    await _userPrefs.put(keyGoogleEmail, email);
  }

  // ── Categories ────────────────────────────────────────────────────────
  List<String> get activeCategories {
    final raw = _categories.get(keyCategories);
    if (raw == null) return [];
    return (raw as List).cast<String>();
  }

  Future<void> setActiveCategories(List<String> ids) =>
      _categories.put(keyCategories, ids);
}
```

- [ ] **Step 4: Run tests — confirm they pass**

```bash
flutter test test/services/storage_service_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/services/storage_service.dart test/services/storage_service_test.dart
git commit -m "feat: add StorageService (Hive + SharedPreferences)"
```

---

### Task 8: Create AuthService

**Files:**
- Create: `lib/services/auth_service.dart`

- [ ] **Step 1: Create AuthService**

Create `lib/services/auth_service.dart`:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final GoogleSignIn _googleSignIn;
  final FirebaseAuth _auth;

  AuthService({
    GoogleSignIn? googleSignIn,
    FirebaseAuth? auth,
  })  : _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _auth = auth ?? FirebaseAuth.instance;

  /// Signs in with Google OAuth then exchanges for a Firebase credential.
  /// Returns null if the user dismissed the account picker.
  /// Throws [FirebaseAuthException] on auth failure.
  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() => Future.wait([
        _googleSignIn.signOut(),
        _auth.signOut(),
      ]);

  User? get currentUser => _auth.currentUser;
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/services/auth_service.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/services/auth_service.dart
git commit -m "feat: add AuthService (Google Sign-In + Firebase Auth)"
```

---

### Task 9: Create SyncService

**Files:**
- Create: `lib/services/sync_service.dart`

- [ ] **Step 1: Create SyncService**

Create `lib/services/sync_service.dart`:

```dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'storage_service.dart';

class SyncService {
  final FirebaseFirestore _firestore;
  final StorageService _storage;
  final String _uid;

  final _remoteChanges = StreamController<void>.broadcast();

  /// Emits whenever a remote Firestore change has been applied to Hive.
  Stream<void> get remoteChanges => _remoteChanges.stream;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  SyncService({
    required FirebaseFirestore firestore,
    required StorageService storage,
    required String uid,
  })  : _firestore = firestore,
        _storage = storage,
        _uid = uid;

  DocumentReference<Map<String, dynamic>> get _doc => _firestore
      .collection('users')
      .doc(_uid)
      .collection('preferences')
      .doc('data');

  /// Starts a real-time Firestore listener.
  /// Remote changes are written to Hive and broadcast via [remoteChanges].
  void startListening() {
    _sub = _doc.snapshots().listen((snap) async {
      if (!snap.exists) return;
      final data = snap.data()!;

      final remoteCurrency = data['currency'] as String?;
      if (remoteCurrency != null) {
        await _storage.setCurrency(remoteCurrency);
      }

      final rawCats = data['categories'];
      if (rawCats is List) {
        await _storage.setActiveCategories(rawCats.cast<String>());
      }

      _remoteChanges.add(null);
    });
  }

  /// Pushes current Hive state to Firestore.
  Future<void> pushToFirestore() => _doc.set({
        'currency': _storage.currency,
        'categories': _storage.activeCategories,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Called after any local write. Fire-and-forget — does not block the UI.
  void syncPreferences() {
    pushToFirestore();
  }

  void dispose() {
    _sub?.cancel();
    _remoteChanges.close();
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/services/sync_service.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/services/sync_service.dart
git commit -m "feat: add SyncService (Firestore ↔ Hive real-time sync)"
```

---

### Task 10: Create UserPreferencesProvider

**Files:**
- Create: `lib/providers/user_preferences_provider.dart`
- Create: `test/providers/user_preferences_provider_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/providers/user_preferences_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wllt/services/storage_service.dart';
import 'package:wllt/providers/user_preferences_provider.dart';

class MockStorageService extends Mock implements StorageService {}

void main() {
  late MockStorageService mockStorage;
  late UserPreferencesProvider provider;

  setUp(() {
    mockStorage = MockStorageService();
    provider = UserPreferencesProvider(mockStorage);
  });

  group('UserPreferencesProvider', () {
    test('currency delegates to StorageService', () {
      when(() => mockStorage.currency).thenReturn('GBP');
      expect(provider.currency, 'GBP');
    });

    test('setCurrency writes to storage and notifies listeners', () async {
      when(() => mockStorage.setCurrency(any())).thenAnswer((_) async {});
      when(() => mockStorage.currency).thenReturn('INR');

      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.setCurrency('INR');

      verify(() => mockStorage.setCurrency('INR')).called(1);
      expect(notifyCount, 1);
    });

    test('activeCategories delegates to StorageService', () {
      when(() => mockStorage.activeCategories)
          .thenReturn(['shopping', 'transport']);
      expect(provider.activeCategories, ['shopping', 'transport']);
    });

    test('setCategories writes to storage and notifies listeners', () async {
      when(() => mockStorage.setActiveCategories(any()))
          .thenAnswer((_) async {});
      when(() => mockStorage.activeCategories).thenReturn(['shopping']);

      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.setCategories(['shopping']);

      verify(() => mockStorage.setActiveCategories(['shopping'])).called(1);
      expect(notifyCount, 1);
    });

    test('authMode delegates to StorageService', () {
      when(() => mockStorage.authMode).thenReturn('google');
      expect(provider.authMode, 'google');
    });
  });
}
```

- [ ] **Step 2: Run tests — confirm they fail**

```bash
flutter test test/providers/user_preferences_provider_test.dart
```

Expected: compile error — file does not exist yet.

- [ ] **Step 3: Create UserPreferencesProvider**

Create `lib/providers/user_preferences_provider.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';

class UserPreferencesProvider extends ChangeNotifier {
  final StorageService _storage;
  SyncService? _syncService;

  UserPreferencesProvider(this._storage);

  String get currency => _storage.currency;
  List<String> get activeCategories => _storage.activeCategories;
  String get authMode => _storage.authMode;
  String? get googleUid => _storage.googleUid;

  Future<void> setAuthMode(String mode) async {
    await _storage.setAuthMode(mode);
    notifyListeners();
  }

  /// Call after successful Google sign-in to store credentials and start sync.
  Future<void> setGoogleUser({
    required String uid,
    required String email,
  }) async {
    await _storage.setGoogleCredentials(uid: uid, email: email);
    _setupSync(uid);
    notifyListeners();
  }

  Future<void> setCurrency(String code) async {
    await _storage.setCurrency(code);
    _syncService?.syncPreferences();
    notifyListeners();
  }

  Future<void> setCategories(List<String> ids) async {
    await _storage.setActiveCategories(ids);
    _syncService?.syncPreferences();
    notifyListeners();
  }

  Future<void> completeOnboarding() =>
      _storage.setOnboardingComplete();

  void _setupSync(String uid) {
    _syncService?.dispose();
    _syncService = SyncService(
      firestore: FirebaseFirestore.instance,
      storage: _storage,
      uid: uid,
    );
    _syncService!.startListening();
    _syncService!.remoteChanges.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _syncService?.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 4: Run tests — confirm they pass**

```bash
flutter test test/providers/user_preferences_provider_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/providers/user_preferences_provider.dart \
        test/providers/user_preferences_provider_test.dart
git commit -m "feat: add UserPreferencesProvider managing SyncService lifecycle"
```

---

### Task 11: Update main.dart

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Replace main.dart**

Replace the entire contents of `lib/main.dart`:

```dart
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
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/main.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: async startup — Firebase + Hive init, onboarding routing, Provider setup"
```

---

### Task 12: Create OnboardingFlow

**Files:**
- Create: `lib/screens/onboarding/onboarding_flow.dart`

- [ ] **Step 1: Create OnboardingFlow**

Create `lib/screens/onboarding/onboarding_flow.dart`:

```dart
import 'package:flutter/material.dart';
import 'onboarding_page1_screen.dart';
import 'onboarding_page2_screen.dart';
import 'onboarding_page3_screen.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _controller = PageController();

  void _nextPage() => _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

  void _previousPage() => _controller.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _controller,
        // Navigation is explicit — swiping is disabled to prevent skipping steps.
        physics: const NeverScrollableScrollPhysics(),
        children: [
          OnboardingPage1Screen(onNext: _nextPage),
          OnboardingPage2Screen(onNext: _nextPage, onBack: _previousPage),
          OnboardingPage3Screen(onBack: _previousPage),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/screens/onboarding/onboarding_flow.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/onboarding/onboarding_flow.dart
git commit -m "feat: add OnboardingFlow PageView with locked physics"
```

---

### Task 13: Create Page 1 — Welcome & Auth

**Files:**
- Create: `lib/screens/onboarding/onboarding_page1_screen.dart`

- [ ] **Step 1: Create Page 1**

Create `lib/screens/onboarding/onboarding_page1_screen.dart`:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../providers/user_preferences_provider.dart';
import '../../services/auth_service.dart';

class OnboardingPage1Screen extends StatefulWidget {
  final VoidCallback onNext;

  const OnboardingPage1Screen({super.key, required this.onNext});

  @override
  State<OnboardingPage1Screen> createState() => _OnboardingPage1ScreenState();
}

class _OnboardingPage1ScreenState extends State<OnboardingPage1Screen> {
  bool _agreedToTerms = false;
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final cred = await context.read<AuthService>().signInWithGoogle();
      if (cred == null) {
        // User dismissed the account picker — do nothing
        setState(() => _isLoading = false);
        return;
      }
      final user = cred.user!;
      final prefs = context.read<UserPreferencesProvider>();
      await prefs.setAuthMode('google');
      await prefs.setGoogleUser(uid: user.uid, email: user.email ?? '');
      widget.onNext();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: ${e.message}')),
      );
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleOfflineMode() async {
    await context.read<UserPreferencesProvider>().setAuthMode('offline');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Offline mode — your data won't be backed up to the cloud."),
        duration: Duration(seconds: 3),
      ),
    );
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _agreedToTerms && !_isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(color: const Color(0xFFFFF3F0).withOpacity(0.91)),
          Column(
            children: [
              // ── Hero ──────────────────────────────────────────────────
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF6750A4), Color(0xFF9D85E5)],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x526750A4),
                              blurRadius: 40,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          LucideIcons.wallet,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'WLLT',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 38,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.76,
                          color: Color(0xFF1D1B20),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Track your expenses,\nmaster your money.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          color: Color(0xFF6B6572),
                          height: 1.375,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Bottom panel ──────────────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(36)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 32,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'GET STARTED',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        letterSpacing: 0.325,
                        color: Color(0xFF6B6572),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Opacity(
                      opacity: enabled ? 1.0 : 0.4,
                      child: _ActionButton(
                        onPressed: enabled ? _handleGoogleSignIn : null,
                        isLoading: _isLoading,
                        icon: const _GoogleLogo(),
                        label: 'Continue with Google',
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1D1B20),
                        borderColor: const Color(0xFFE8E0EC),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                            child: Divider(color: Color(0xFFE8E0EC))),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or',
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: Colors.grey.shade400)),
                        ),
                        const Expanded(
                            child: Divider(color: Color(0xFFE8E0EC))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Opacity(
                      opacity: enabled ? 1.0 : 0.4,
                      child: _ActionButton(
                        onPressed: enabled ? _handleOfflineMode : null,
                        isLoading: false,
                        icon: const Icon(LucideIcons.cloudOff,
                            size: 20, color: Color(0xFF6750A4)),
                        label: 'Continue without account',
                        backgroundColor: const Color(0xFFF5EFF7),
                        foregroundColor: const Color(0xFF6750A4),
                        borderColor: Colors.transparent,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _agreedToTerms,
                            activeColor: const Color(0xFF6750A4),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                            onChanged: (v) =>
                                setState(() => _agreedToTerms = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: Color(0xFF9E99A3),
                              ),
                              children: [
                                const TextSpan(text: 'I agree to the '),
                                TextSpan(
                                  text: 'Terms of Service',
                                  style: const TextStyle(
                                      color: Color(0xFF6750A4)),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      // Link URL not yet configured
                                    },
                                ),
                                const TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: const TextStyle(
                                      color: Color(0xFF6750A4)),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      // Link URL not yet configured
                                    },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;

  const _ActionButton({
    required this.onPressed,
    required this.isLoading,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: borderColor == Colors.transparent
              ? null
              : const [
                  BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 6,
                      offset: Offset(0, 1))
                ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: foregroundColor))
                : icon,
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: foregroundColor,
                ),
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 16, color: foregroundColor),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

/// Renders the Google "G" using colored text.
/// Replace with an official Google logo SVG asset before production release.
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4285F4),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/screens/onboarding/onboarding_page1_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/onboarding/onboarding_page1_screen.dart
git commit -m "feat: add onboarding Page 1 — welcome, Google/offline auth, T&C checkbox"
```

---

### Task 14: Create Page 2 — Currency Picker

**Files:**
- Create: `lib/screens/onboarding/onboarding_page2_screen.dart`

- [ ] **Step 1: Create Page 2**

Create `lib/screens/onboarding/onboarding_page2_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../data/currencies.dart';
import '../../providers/user_preferences_provider.dart';
import 'onboarding_shared_widgets.dart';

class OnboardingPage2Screen extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingPage2Screen({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<OnboardingPage2Screen> createState() => _OnboardingPage2ScreenState();
}

class _OnboardingPage2ScreenState extends State<OnboardingPage2Screen> {
  late String _selectedCode;
  late String _detectedCode;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _detectedCode = detectCurrencyFromLocale();
    _selectedCode = _detectedCode;
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

  Future<void> _handleContinue() async {
    await context.read<UserPreferencesProvider>().setCurrency(_selectedCode);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final detectedInfo = getCurrencyByCode(_detectedCode);
    final selectedInfo = getCurrencyByCode(_selectedCode);
    final isOffline =
        context.read<UserPreferencesProvider>().authMode == 'offline';
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF3F0),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.chevronLeft),
                    onPressed: widget.onBack,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: OnboardingProgressBar(current: 2, total: 3)),
                  const SizedBox(width: 8),
                  const Text('2 of 3',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF6B6572))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // ── Heading ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 33),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "What's your currency?",
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 26,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.65,
                      color: Color(0xFF1D1B20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Color(0xFF6B6572)),
                      children: [
                        const TextSpan(text: 'We detected '),
                        TextSpan(
                          text: '${detectedInfo.flag} ${detectedInfo.code}',
                          style:
                              const TextStyle(color: Color(0xFF1D1B20)),
                        ),
                        const TextSpan(text: ' based on your region.'),
                      ],
                    ),
                  ),
                  if (isOffline) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: const Color(0x66FFD54F)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(LucideIcons.alertTriangle,
                              size: 12, color: Color(0xFF92400E)),
                          SizedBox(width: 6),
                          Text(
                            'Offline mode · No cloud backup',
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: Color(0xFF92400E)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            // ── Search ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 6,
                        offset: Offset(0, 1))
                  ],
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search currencies...',
                    hintStyle: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        color: Color(0xFFCAC4D0)),
                    prefixIcon: Icon(LucideIcons.search,
                        size: 18, color: Color(0xFF6B6572)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 18, vertical: 18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ── Selected currency card ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5EFF7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFF6750A4), width: 2),
                ),
                child: Row(
                  children: [
                    Text(selectedInfo.flag,
                        style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(selectedInfo.name,
                              style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: Color(0xFF6750A4))),
                          Text(
                            '${selectedInfo.code} · ${selectedInfo.symbol}',
                            style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Color(0xFF9D85E5)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE7F6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('Selected',
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Color(0xFF6750A4))),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ── Currency list ─────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 4),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final currency = filtered[i];
                  return _CurrencyRow(
                    currency: currency,
                    isSelected: currency.code == _selectedCode,
                    onTap: () =>
                        setState(() => _selectedCode = currency.code),
                  );
                },
              ),
            ),
            // ── Continue button ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 8, 30, 24),
              child: GestureDetector(
                onTap: _handleContinue,
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1B20),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x38000000),
                          blurRadius: 20,
                          offset: Offset(0, 4))
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Continue',
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.white)),
                      SizedBox(width: 8),
                      Icon(LucideIcons.chevronRight,
                          size: 18, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
          color: isSelected
              ? const Color(0xFFF5EFF7)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(currency.flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(currency.name,
                      style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          color: Color(0xFF1D1B20))),
                  Text(
                    '${currency.code} · ${currency.symbol} · ${currency.country}',
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFF9E99A3)),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                    color: Color(0xFF6750A4), shape: BoxShape.circle),
                child: const Icon(LucideIcons.check,
                    size: 14, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/screens/onboarding/onboarding_page2_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/onboarding/onboarding_page2_screen.dart
git commit -m "feat: add onboarding Page 2 — currency picker with locale auto-detect and search"
```

---

### Task 15: Create Page 3 — Category Selector

**Files:**
- Create: `lib/screens/onboarding/onboarding_page3_screen.dart`

- [ ] **Step 1: Create Page 3**

Create `lib/screens/onboarding/onboarding_page3_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/user_preferences_provider.dart';
import '../../screens/layout_screen.dart';
import '../../widgets/category_icon_widget.dart';
import 'onboarding_shared_widgets.dart';

class OnboardingPage3Screen extends StatefulWidget {
  final VoidCallback onBack;

  const OnboardingPage3Screen({super.key, required this.onBack});

  @override
  State<OnboardingPage3Screen> createState() => _OnboardingPage3ScreenState();
}

class _OnboardingPage3ScreenState extends State<OnboardingPage3Screen> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    // Pre-select first 8 categories (matches the Figma design's default state)
    _selected = Category.categories.take(8).map((c) => c.id).toSet();
  }

  void _toggle(String id) => setState(() {
        if (_selected.contains(id)) {
          _selected.remove(id);
        } else {
          _selected.add(id);
        }
      });

  void _selectAll() => setState(() {
        _selected = Category.categories.map((c) => c.id).toSet();
      });

  Future<void> _handleGetStarted() async {
    final prefs = context.read<UserPreferencesProvider>();
    await prefs.setCategories(_selected.toList());
    await prefs.completeOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LayoutScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOffline =
        context.read<UserPreferencesProvider>().authMode == 'offline';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF3F0),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.chevronLeft),
                    onPressed: widget.onBack,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: OnboardingProgressBar(current: 3, total: 3)),
                  const SizedBox(width: 8),
                  const Text('3 of 3',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF6B6572))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // ── Heading ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 38),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Choose your categories',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 26,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.65,
                      color: Color(0xFF1D1B20),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Select the categories you use most. You can always add or remove them later.',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: Color(0xFF6B6572),
                        height: 1.43),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Counter row ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Color(0xFF1D1B20)),
                      children: [
                        TextSpan(
                          text: '${_selected.length}',
                          style:
                              const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const TextSpan(
                          text: ' selected',
                          style: TextStyle(color: Color(0xFF6B6572)),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _selectAll,
                    child: const Text('Select all',
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6750A4))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // ── Category grid ─────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 215 / 68,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: Category.categories.length,
                  itemBuilder: (context, i) {
                    final cat = Category.categories[i];
                    return _CategoryChip(
                      category: cat,
                      isSelected: _selected.contains(cat.id),
                      onTap: () => _toggle(cat.id),
                    );
                  },
                ),
              ),
            ),
            // ── Get Started button ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 8, 30, 24),
              child: Opacity(
                opacity: _selected.isEmpty ? 0.4 : 1.0,
                child: GestureDetector(
                  onTap: _selected.isEmpty ? null : _handleGetStarted,
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D1B20),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 20,
                            offset: Offset(0, 4))
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.sparkles,
                            size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Get Started',
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final Category category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  Color get _color {
    final hex = category.color.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? null : Border.all(color: const Color(0xFFE8E0EC)),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 12,
                      offset: Offset(0, 2))
                ]
              : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _color
                          : _color.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: CategoryIconWidget(
                        category: category,
                        size: 18,
                        color: isSelected ? Colors.white : _color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    category.name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF1D1B20)
                          : const Color(0xFF9E99A3),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                      color: _color, shape: BoxShape.circle),
                  child: const Icon(LucideIcons.check,
                      size: 11, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/screens/onboarding/onboarding_page3_screen.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Run all tests**

```bash
flutter test
```

Expected: `All tests passed!`

- [ ] **Step 4: Smoke test the full flow**

```bash
flutter run
```

1. App should open to Page 1 (Welcome screen)
2. Both buttons should be greyed out
3. Tick the checkbox → buttons become active
4. Tap "Continue without account" → snackbar appears, advance to Page 2
5. Page 2 should show auto-detected currency; search filters work; Continue advances to Page 3
6. Page 3 shows 18 category chips, 8 pre-selected; toggle and Get Started work
7. After Get Started → `LayoutScreen` loads
8. Kill and relaunch the app → goes straight to `LayoutScreen` (onboarding not shown again)

- [ ] **Step 5: Commit**

```bash
git add lib/screens/onboarding/onboarding_page3_screen.dart
git commit -m "feat: add onboarding Page 3 — category selector with 2-col grid and Get Started"
```

---

## Follow-up (not in scope of this plan)

- **`helpers.dart:3`** — `formatINR` hardcodes `₹`. After this plan, update it to read currency symbol from `UserPreferencesProvider`.
- **`_GoogleLogo`** — replace the colored "G" text with an official Google logo SVG asset before production.
- **Terms/Privacy links** — add actual URLs to the `TapGestureRecognizer` handlers in Page 1.
- **Firestore security rules** — tighten rules from test mode to `allow read, write: if request.auth.uid == userId;` before production.
