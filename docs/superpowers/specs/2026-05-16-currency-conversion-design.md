# Currency Conversion Design
**Date:** 2026-05-16  
**Status:** Approved

---

## Context

The app currently stores transaction amounts as raw `double` values with a single global currency preference (ISO code) per user. No exchange rate data exists. When the user changes their default currency, amounts need to be displayed in the new currency using the exchange rate that was live at the time each transaction was recorded — not today's rate. This spec implements that system.

---

## Architecture Overview

```
add_expense_sheet.dart
  └─► ExchangeRateService.fetchSnapshot(baseCurrency, date)
        ├─ Hive _ratesBox (cache hit) → return
        └─ Frankfurter API (cache miss)
              ├─ /v2/latest?base={BASE}  (today)
              └─ /v2/{YYYY-MM-DD}?base={BASE}  (historical / fallback)
                    └─ retry up to 7 days back if needed
        └─ Save to Hive → return rates

Transaction model
  └─ new field: baseCurrency (String)

Display layer (all transaction lists / detail views)
  └─ Helpers.convertAmount(amount, baseCurrency, displayCurrency, rates)
        └─ looks up snapshot from ExchangeRateService
        └─ if convertHistoricalCurrency == false AND baseCurrency != displayCurrency
              → show in original baseCurrency, no conversion

CurrencyPickerScreen (on confirm)
  └─ show dialog: "Convert all history?" / "Keep original"
        └─ note: "Rates reflect the exchange rate at the time of each transaction"
        └─ save convertHistoricalCurrency: bool to UserPreferences
```

---

## Data Models

### 1. Transaction (modify existing)

File: `lib/models/models.dart`

Add field:
```dart
final String baseCurrency; // ISO code of default currency when transaction was entered
```/

- Default for legacy transactions (no field in Hive): fall back to `StorageService.currency` at read time, or `'USD'` if unknown
- Serialized in `toJson` / `fromJson`

### 2. ExchangeRateSnapshot (new model)

File: `lib/models/models.dart` or new `lib/models/exchange_rate_snapshot.dart`

```dart
class ExchangeRateSnapshot {
  final String key;               // "YYYY-MM-DD_BASE" e.g. "2026-05-16_USD"
  final String baseCurrency;      // ISO code
  final Map<String, double> rates; // { "INR": 83.12, "EUR": 0.92, ... }
  final String fetchedAt;         // ISO-8601 datetime string
}
```

Hive box key: `key` field value.

### 3. UserPreferences (extend existing)

File: `lib/services/storage_service.dart`

Add:
```dart
static const String keyConvertHistoricalCurrency = 'convertHistoricalCurrency';
bool get convertHistoricalCurrency => _userPrefsBox.get(keyConvertHistoricalCurrency, defaultValue: true);
Future<void> setConvertHistoricalCurrency(bool value) async => _userPrefsBox.put(keyConvertHistoricalCurrency, value);
```

---

## Service Layer

### ExchangeRateService (new)

File: `lib/services/exchange_rate_service.dart`

```dart
class ExchangeRateService {
  static const _baseUrl = 'https://api.frankfurter.dev/v2';

  /// Returns cached snapshot or fetches from API.
  /// baseCurrency: ISO code (e.g. "USD")
  /// date: the transaction date
  Future<Map<String, double>?> fetchSnapshot(String baseCurrency, DateTime date);

  /// Synchronous cache-only lookup (for display layer — no network call).
  ExchangeRateSnapshot? getCachedSnapshot(String baseCurrency, DateTime date);

  /// Internal: build Hive cache key
  String _cacheKey(String base, DateTime date) =>
    '${DateFormat('yyyy-MM-dd').format(date)}_$base';
}
```

**Fetch strategy:**
1. Check `_ratesBox.get(key)` — cache hit → return `snapshot.rates`
2. Cache miss, date == today → `GET /v2/latest?base={BASE}`
3. If step 2 fails OR date != today → `GET /v2/{YYYY-MM-DD}?base={BASE}`
4. If step 3 fails → walk back 1 day at a time, up to 7 attempts
5. On success → save `ExchangeRateSnapshot` to `_ratesBox` under original requested key
6. On total failure → return `null` (caller shows raw amount with original currency label)

**Dependencies:** `http` package (add to pubspec.yaml)

---

## Transaction Entry Flow

File: `lib/widgets/add_expense_sheet.dart`

Before `StorageService.saveTransaction(transaction)`:
1. Get `currentCurrency = userPrefs.currency`
2. Call `ExchangeRateService.fetchSnapshot(currentCurrency, selectedDate)`
3. Construct `Transaction` with `baseCurrency: currentCurrency`
4. Snapshot is saved to cache by service; transaction carries only `baseCurrency`

---

## Display Layer

### Helpers.convertAmount (new utility)

File: `lib/utils/helpers.dart`

```dart
/// Returns amount converted from baseCurrency to targetCurrency using rates.
/// Returns original amount if currencies match or rates is null.
static double convertAmount(
  double amount,
  String baseCurrency,
  String targetCurrency,
  Map<String, double>? rates,
) {
  if (baseCurrency == targetCurrency || rates == null) return amount;
  final rate = rates[targetCurrency];
  if (rate == null) return amount;
  return amount * rate;
}
```

### Where to apply conversion

All sites that call `Helpers.formatAmount(transaction.amount, symbol)` need updating:
- `lib/screens/transactions_screen.dart` (line ~44, 55-58)
- `lib/screens/home_screen.dart`
- `lib/screens/accounts_screen.dart`
- `lib/widgets/add_expense_sheet.dart` (preview display)
- `lib/screens/category_breakdown_screen.dart`

**Render logic:**
```dart
final displayCurrency = userPrefs.currency;
final convertHistory = storageService.convertHistoricalCurrency;

if (convertHistory || tx.baseCurrency == displayCurrency) {
  // Fetch snapshot from ExchangeRateService cache (sync lookup from Hive — no await)
  final snapshot = exchangeRateService.getCachedSnapshot(tx.baseCurrency, tx.date);
  final converted = Helpers.convertAmount(tx.amount, tx.baseCurrency, displayCurrency, snapshot?.rates);
  Helpers.formatAmount(converted, displayCurrencySymbol);
} else {
  // Show in original currency
  final originalSymbol = getCurrencyByCode(tx.baseCurrency)?.symbol ?? tx.baseCurrency;
  Helpers.formatAmount(tx.amount, originalSymbol);
}
```

Note: Hive lookups are synchronous; no `FutureBuilder` needed at display. Snapshots are pre-fetched at transaction entry; display only reads cache.

---

## Settings / Currency Change Dialog

File: `lib/screens/currency_picker_screen.dart`

On user confirming a new currency:
1. Call existing `UserPreferencesProvider.setCurrency(newCode)`
2. Show `AlertDialog`:

```
Title: "Currency changed to [FLAG] INR"

Body:  "How should past transactions appear?"

       ● Convert all history to INR
       ● Keep in original currencies

       ── note ──────────────────────────────
       Rates shown reflect the exchange rate
       at the time of each transaction.
       ──────────────────────────────────────

[Cancel]                          [Confirm]
```

3. On confirm: `storageService.setConvertHistoricalCurrency(selectedOption)`
4. Trigger `UserPreferencesProvider.notifyListeners()` → all screens rebuild

---

## Dependency Changes

`pubspec.yaml`:
```yaml
dependencies:
  http: ^1.2.0   # add this
```

---

## Migration / Legacy Transactions

Existing transactions in Hive have no `baseCurrency` field. On `fromJson`:
```dart
baseCurrency: json['baseCurrency'] as String? ?? StorageService.instance.currency,
```
This assigns the user's current currency as the base for legacy transactions — a reasonable approximation.

---

## Verification

1. Add `http` package → `flutter pub get` → no pubspec errors
2. Create transaction in USD → check Hive `_ratesBox` has key `"YYYY-MM-DD_USD"` with rates map
3. Switch to INR with "Convert all history" → home/transactions screens show INR amounts
4. Switch to INR with "Keep original" → old USD transactions show `$` symbol, new ones show `₹`
5. Kill network → add transaction → verify fallback fetches historical rate (check logs) or shows original currency gracefully
6. Re-open app → verify cached rates persist (Hive survives restart)
7. Verify legacy transactions (no `baseCurrency` in JSON) load without crash, use current currency as fallback
