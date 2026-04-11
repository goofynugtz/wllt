import 'dart:io' show Platform; // mobile only — not available on web

class CurrencyInfo {
  final String code;
  final String name;
  final String symbol;
  final String countryCode; // ISO 3166-1 alpha-2 (or 'EU' for Euro)
  final String country;

  const CurrencyInfo({
    required this.code,
    required this.name,
    required this.symbol,
    required this.countryCode,
    required this.country,
  });
}

const List<CurrencyInfo> kCurrencies = [
  CurrencyInfo(code: 'AED', name: 'UAE Dirham',          symbol: 'د.إ',  countryCode: 'AE', country: 'UAE'),
  CurrencyInfo(code: 'ARS', name: 'Argentine Peso',       symbol: r'$',   countryCode: 'AR', country: 'Argentina'),
  CurrencyInfo(code: 'AUD', name: 'Australian Dollar',    symbol: 'A\$',  countryCode: 'AU', country: 'Australia'),
  CurrencyInfo(code: 'BDT', name: 'Bangladeshi Taka',     symbol: '৳',    countryCode: 'BD', country: 'Bangladesh'),
  CurrencyInfo(code: 'BGN', name: 'Bulgarian Lev',        symbol: 'лв',   countryCode: 'BG', country: 'Bulgaria'),
  CurrencyInfo(code: 'BHD', name: 'Bahraini Dinar',       symbol: 'BD',   countryCode: 'BH', country: 'Bahrain'),
  CurrencyInfo(code: 'BRL', name: 'Brazilian Real',       symbol: 'R\$',  countryCode: 'BR', country: 'Brazil'),
  CurrencyInfo(code: 'CAD', name: 'Canadian Dollar',      symbol: 'CA\$', countryCode: 'CA', country: 'Canada'),
  CurrencyInfo(code: 'CHF', name: 'Swiss Franc',          symbol: 'Fr',   countryCode: 'CH', country: 'Switzerland'),
  CurrencyInfo(code: 'CNY', name: 'Chinese Yuan',         symbol: '¥',    countryCode: 'CN', country: 'China'),
  CurrencyInfo(code: 'CZK', name: 'Czech Koruna',         symbol: 'Kč',   countryCode: 'CZ', country: 'Czech Republic'),
  CurrencyInfo(code: 'DKK', name: 'Danish Krone',         symbol: 'kr',   countryCode: 'DK', country: 'Denmark'),
  CurrencyInfo(code: 'EGP', name: 'Egyptian Pound',       symbol: '£',    countryCode: 'EG', country: 'Egypt'),
  CurrencyInfo(code: 'EUR', name: 'Euro',                 symbol: '€',    countryCode: 'EU', country: 'European Union'),
  CurrencyInfo(code: 'GBP', name: 'British Pound',        symbol: '£',    countryCode: 'GB', country: 'United Kingdom'),
  CurrencyInfo(code: 'HKD', name: 'Hong Kong Dollar',     symbol: 'HK\$', countryCode: 'HK', country: 'Hong Kong'),
  CurrencyInfo(code: 'HUF', name: 'Hungarian Forint',     symbol: 'Ft',   countryCode: 'HU', country: 'Hungary'),
  CurrencyInfo(code: 'IDR', name: 'Indonesian Rupiah',    symbol: 'Rp',   countryCode: 'ID', country: 'Indonesia'),
  CurrencyInfo(code: 'ILS', name: 'Israeli Shekel',       symbol: '₪',    countryCode: 'IL', country: 'Israel'),
  CurrencyInfo(code: 'INR', name: 'Indian Rupee',         symbol: '₹',    countryCode: 'IN', country: 'India'),
  CurrencyInfo(code: 'JPY', name: 'Japanese Yen',         symbol: '¥',    countryCode: 'JP', country: 'Japan'),
  CurrencyInfo(code: 'KRW', name: 'South Korean Won',     symbol: '₩',    countryCode: 'KR', country: 'South Korea'),
  CurrencyInfo(code: 'MXN', name: 'Mexican Peso',         symbol: r'$',   countryCode: 'MX', country: 'Mexico'),
  CurrencyInfo(code: 'MYR', name: 'Malaysian Ringgit',    symbol: 'RM',   countryCode: 'MY', country: 'Malaysia'),
  CurrencyInfo(code: 'NGN', name: 'Nigerian Naira',       symbol: '₦',    countryCode: 'NG', country: 'Nigeria'),
  CurrencyInfo(code: 'NOK', name: 'Norwegian Krone',      symbol: 'kr',   countryCode: 'NO', country: 'Norway'),
  CurrencyInfo(code: 'NZD', name: 'New Zealand Dollar',   symbol: 'NZ\$', countryCode: 'NZ', country: 'New Zealand'),
  CurrencyInfo(code: 'PHP', name: 'Philippine Peso',      symbol: '₱',    countryCode: 'PH', country: 'Philippines'),
  CurrencyInfo(code: 'PKR', name: 'Pakistani Rupee',      symbol: '₨',    countryCode: 'PK', country: 'Pakistan'),
  CurrencyInfo(code: 'PLN', name: 'Polish Zloty',         symbol: 'zł',   countryCode: 'PL', country: 'Poland'),
  CurrencyInfo(code: 'RUB', name: 'Russian Ruble',        symbol: '₽',    countryCode: 'RU', country: 'Russia'),
  CurrencyInfo(code: 'SAR', name: 'Saudi Riyal',          symbol: '﷼',    countryCode: 'SA', country: 'Saudi Arabia'),
  CurrencyInfo(code: 'SEK', name: 'Swedish Krona',        symbol: 'kr',   countryCode: 'SE', country: 'Sweden'),
  CurrencyInfo(code: 'SGD', name: 'Singapore Dollar',     symbol: 'S\$',  countryCode: 'SG', country: 'Singapore'),
  CurrencyInfo(code: 'THB', name: 'Thai Baht',            symbol: '฿',    countryCode: 'TH', country: 'Thailand'),
  CurrencyInfo(code: 'TRY', name: 'Turkish Lira',         symbol: '₺',    countryCode: 'TR', country: 'Turkey'),
  CurrencyInfo(code: 'TWD', name: 'Taiwan Dollar',        symbol: 'NT\$', countryCode: 'TW', country: 'Taiwan'),
  CurrencyInfo(code: 'USD', name: 'US Dollar',            symbol: r'$',   countryCode: 'US', country: 'United States'),
  CurrencyInfo(code: 'VND', name: 'Vietnamese Dong',      symbol: '₫',    countryCode: 'VN', country: 'Vietnam'),
  CurrencyInfo(code: 'ZAR', name: 'South African Rand',   symbol: 'R',    countryCode: 'ZA', country: 'South Africa'),
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
