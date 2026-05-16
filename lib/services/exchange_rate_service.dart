import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/models.dart';

class ExchangeRateService with ChangeNotifier {
  ExchangeRateService._();
  static final instance = ExchangeRateService._();

  static const _baseUrl = 'https://api.frankfurter.dev/v2';
  static const _boxName = 'exchange_rates';
  static final _dateFmt = DateFormat('yyyy-MM-dd');

  late Box _ratesBox;
  final _inflight = <String>{};

  Future<void> init() async {
    _ratesBox = await Hive.openBox(_boxName);
  }

  String _cacheKey(String base, DateTime date) =>
      '${_dateFmt.format(date)}_$base';

  ExchangeRateSnapshot? getCachedSnapshot(String baseCurrency, DateTime date) {
    final raw = _ratesBox.get(_cacheKey(baseCurrency, date));
    if (raw == null) return null;
    return ExchangeRateSnapshot.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<Map<String, double>?> fetchSnapshot(
      String baseCurrency, DateTime date) async {
    final key = _cacheKey(baseCurrency, date);
    final cached = getCachedSnapshot(baseCurrency, date);
    if (cached != null) {
      debugPrint('[ExchangeRate] CACHE HIT: $key (${cached.rates.length} rates)');
      return cached.rates;
    }

    if (_inflight.contains(key)) {
      debugPrint('[ExchangeRate] IN-FLIGHT: $key — skipping duplicate fetch');
      return null;
    }
    _inflight.add(key);

    try {
      final today = DateTime.now();
      final isToday = _dateFmt.format(date) == _dateFmt.format(today);

      Map<String, double>? rates;

      if (isToday) {
        debugPrint('[ExchangeRate] API CALL → GET $_baseUrl/rates?base=$baseCurrency');
        rates = await _fetchLatest(baseCurrency);
        if (rates != null) {
          debugPrint('[ExchangeRate] API OK: latest $baseCurrency — ${rates.length} rates');
        } else {
          debugPrint('[ExchangeRate] API FAIL: latest $baseCurrency — will try historical');
        }
      }

      if (rates == null) {
        for (var i = 0; i < 7; i++) {
          final attempt = date.subtract(Duration(days: i));
          final dateStr = _dateFmt.format(attempt);
          debugPrint('[ExchangeRate] API CALL → GET $_baseUrl/rates?date=$dateStr&base=$baseCurrency (attempt ${i + 1}/7)');
          rates = await _fetchHistorical(baseCurrency, attempt);
          if (rates != null) {
            debugPrint('[ExchangeRate] API OK: historical $baseCurrency @ $dateStr — ${rates.length} rates');
            break;
          }
          debugPrint('[ExchangeRate] API FAIL: $dateStr — retrying');
        }
      }

      if (rates == null) {
        debugPrint('[ExchangeRate] TOTAL FAIL: no rates for $baseCurrency @ $key — display will use raw amount');
        return null;
      }

      final snapshot = ExchangeRateSnapshot(
        key: key,
        baseCurrency: baseCurrency,
        rates: rates,
        fetchedAt: DateTime.now().toIso8601String(),
      );
      await _ratesBox.put(key, snapshot.toJson());
      debugPrint('[ExchangeRate] CACHED: $key saved to Hive');
      notifyListeners();
      return rates;
    } finally {
      _inflight.remove(key);
    }
  }

  /// Fire-and-forget: fetches rates for all uncached (baseCurrency, date) pairs
  /// in [txns] that differ from [displayCurrency].
  Future<void> prefetchForTransactions(
    List<Transaction> txns,
    String displayCurrency,
  ) async {
    final seen = <String>{};
    for (final tx in txns) {
      if (tx.baseCurrency == displayCurrency) continue;
      final key = _cacheKey(tx.baseCurrency, tx.date);
      if (!seen.add(key)) continue;
      if (getCachedSnapshot(tx.baseCurrency, tx.date) != null) continue;
      fetchSnapshot(tx.baseCurrency, tx.date);
    }
  }

  /// Seeds mock snapshots for every unique (baseCurrency, date) in dummy data.
  /// Rates vary by period so same-currency transactions on different dates
  /// show visibly different converted amounts when the display currency changes.
  Future<void> seedDevModeRates() async {
    final seen = <String>{};
    for (final tx in Transaction.dummyData) {
      final key = _cacheKey(tx.baseCurrency, tx.date);
      if (!seen.add(key)) continue;
      final rates = _devRatesFor(tx.baseCurrency, tx.date);
      if (rates.isEmpty) continue;
      final snapshot = ExchangeRateSnapshot(
        key: key,
        baseCurrency: tx.baseCurrency,
        rates: rates,
        fetchedAt: DateTime.now().toIso8601String(),
      );
      await _ratesBox.put(key, snapshot.toJson());
    }
    notifyListeners();
  }

  /// INR-based rates that drift across 5 historical periods.
  /// All values are "1 INR = x [target]".
  Map<String, double> _devRatesFor(String base, DateTime date) {
    if (base != 'INR') return {};
    final y = date.year;
    final m = date.month;

    // Period A: May–Aug 2025 · ₹84/$
    if (y < 2025 || (y == 2025 && m <= 8)) {
      return {'USD': 0.01190, 'EUR': 0.01087, 'GBP': 0.00935, 'JPY': 1.7500, 'AED': 0.04370, 'SGD': 0.01600};
    }
    // Period B: Sep–Nov 2025 · ₹84.7/$
    if (y == 2025 && m <= 11) {
      return {'USD': 0.01181, 'EUR': 0.01078, 'GBP': 0.00928, 'JPY': 1.7350, 'AED': 0.04337, 'SGD': 0.01588};
    }
    // Period C: Dec 2025–Feb 2026 · ₹85.6/$
    if (y == 2025 || (y == 2026 && m <= 2)) {
      return {'USD': 0.01168, 'EUR': 0.01066, 'GBP': 0.00918, 'JPY': 1.7150, 'AED': 0.04290, 'SGD': 0.01571};
    }
    // Period D: Mar–Apr 2026 · ₹87/$
    if (y == 2026 && m <= 4) {
      return {'USD': 0.01149, 'EUR': 0.01049, 'GBP': 0.00904, 'JPY': 1.6880, 'AED': 0.04222, 'SGD': 0.01546};
    }
    // Period E: May 2026+ · ₹85.5/$
    return {'USD': 0.01170, 'EUR': 0.01068, 'GBP': 0.00919, 'JPY': 1.7180, 'AED': 0.04299, 'SGD': 0.01572};
  }

  Future<Map<String, double>?> _fetchLatest(String base) async {
    try {
      final uri = Uri.parse('$_baseUrl/rates?base=$base');
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      debugPrint('[ExchangeRate] HTTP ${resp.statusCode} for $uri | body: ${resp.body.substring(0, resp.body.length.clamp(0, 200))}');
      if (resp.statusCode != 200) return null;
      return _parseRates(resp.body);
    } catch (e) {
      debugPrint('[ExchangeRate] EXCEPTION (latest $base): $e');
      return null;
    }
  }

  Future<Map<String, double>?> _fetchHistorical(
      String base, DateTime date) async {
    try {
      final dateStr = _dateFmt.format(date);
      final uri = Uri.parse('$_baseUrl/rates?date=$dateStr&base=$base');
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      debugPrint('[ExchangeRate] HTTP ${resp.statusCode} for $uri | body: ${resp.body.substring(0, resp.body.length.clamp(0, 200))}');
      if (resp.statusCode != 200) return null;
      return _parseRates(resp.body);
    } catch (e) {
      debugPrint('[ExchangeRate] EXCEPTION (historical $base @ ${_dateFmt.format(date)}): $e');
      return null;
    }
  }

  Map<String, double>? _parseRates(String body) {
    try {
      final decoded = jsonDecode(body);
      // v2: array of {date, base, quote, rate}
      if (decoded is List) {
        return {
          for (final item in decoded)
            (item['quote'] as String): (item['rate'] as num).toDouble(),
        };
      }
      // v1 fallback: {rates: {AED: 0.038, ...}}
      if (decoded is Map<String, dynamic>) {
        final raw = decoded['rates'] as Map<String, dynamic>?;
        if (raw == null) return null;
        return raw.map((k, v) => MapEntry(k, (v as num).toDouble()));
      }
      return null;
    } catch (e) {
      debugPrint('[ExchangeRate] PARSE ERROR: $e');
      return null;
    }
  }
}
