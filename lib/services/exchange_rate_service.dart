import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'diagnostics_logger.dart';

class ExchangeRateService with ChangeNotifier {
  ExchangeRateService._();
  static final instance = ExchangeRateService._();

  static const _baseUrl = 'https://api.frankfurter.dev/v2';
  static const _fallbackUrl = 'https://open.er-api.com/v6/latest';
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

    final attempts = <String>[];

    try {
      final today = DateTime.now();
      final isToday = _dateFmt.format(date) == _dateFmt.format(today);

      Map<String, double>? rates;

      if (isToday) {
        debugPrint('[ExchangeRate] API CALL → GET $_baseUrl/rates?base=$baseCurrency');
        rates = await _fetchLatest(baseCurrency, attempts);
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
          rates = await _fetchHistorical(baseCurrency, attempt, attempts);
          if (rates != null) {
            debugPrint('[ExchangeRate] API OK: historical $baseCurrency @ $dateStr — ${rates.length} rates');
            break;
          }
          debugPrint('[ExchangeRate] API FAIL: $dateStr — retrying');
        }
      }

      if (rates == null) {
        debugPrint('[ExchangeRate] All Frankfurter attempts failed for $baseCurrency — trying fallback API');
        rates = await _fetchLatestFallback(baseCurrency, attempts);
      }

      if (rates == null) {
        debugPrint('[ExchangeRate] TOTAL FAIL: no rates for $baseCurrency @ $key — display will use raw amount');
        DiagnosticsLogger.instance.logExchangeRateFailure(
          currency: baseCurrency,
          date: key,
          attempts: attempts,
        );
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

  /// Fetches real rates from API for every unique (baseCurrency, date) in dummy data.
  Future<void> seedDevModeRates() async {
    final seen = <String>{};
    final futures = <Future<void>>[];
    for (final tx in Transaction.dummyData) {
      final key = _cacheKey(tx.baseCurrency, tx.date);
      if (!seen.add(key)) continue;
      if (getCachedSnapshot(tx.baseCurrency, tx.date) != null) continue;
      futures.add(fetchSnapshot(tx.baseCurrency, tx.date).then((_) {}));
    }
    await Future.wait(futures);
    notifyListeners();
  }

  Future<Map<String, double>?> _fetchLatest(
      String base, List<String> attempts) async {
    try {
      final uri = Uri.parse('$_baseUrl/rates?base=$base');
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      debugPrint('[ExchangeRate] HTTP ${resp.statusCode} for $uri | body: ${resp.body.substring(0, resp.body.length.clamp(0, 200))}');
      if (resp.statusCode == 200) {
        final rates = _parseRates(resp.body);
        if (rates != null) {
          attempts.add('frankfurter_latest:200:ok');
          return rates;
        }
        attempts.add('frankfurter_latest:200:parse_fail');
      } else {
        attempts.add('frankfurter_latest:${resp.statusCode}');
      }
    } catch (e) {
      attempts.add('frankfurter_latest:exception:$e');
      debugPrint('[ExchangeRate] EXCEPTION (latest $base): $e');
    }
    return _fetchLatestFallback(base, attempts);
  }

  Future<Map<String, double>?> _fetchLatestFallback(
      String base, List<String> attempts) async {
    try {
      final uri = Uri.parse('$_fallbackUrl/$base');
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      debugPrint('[ExchangeRate] FALLBACK HTTP ${resp.statusCode} for $uri');
      if (resp.statusCode != 200) {
        attempts.add('fallback_latest:${resp.statusCode}');
        return null;
      }
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      if (decoded['result'] != 'success') {
        attempts.add('fallback_latest:200:result=${decoded['result']}');
        return null;
      }
      final raw = decoded['rates'] as Map<String, dynamic>?;
      if (raw == null) {
        attempts.add('fallback_latest:200:no_rates_key');
        return null;
      }
      attempts.add('fallback_latest:200:ok');
      return raw.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (e) {
      attempts.add('fallback_latest:exception:$e');
      debugPrint('[ExchangeRate] FALLBACK EXCEPTION ($base): $e');
      return null;
    }
  }

  Future<Map<String, double>?> _fetchHistorical(
      String base, DateTime date, List<String> attempts) async {
    try {
      final dateStr = _dateFmt.format(date);
      final uri = Uri.parse('$_baseUrl/rates?date=$dateStr&base=$base');
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      debugPrint('[ExchangeRate] HTTP ${resp.statusCode} for $uri | body: ${resp.body.substring(0, resp.body.length.clamp(0, 200))}');
      if (resp.statusCode == 200) {
        final rates = _parseRates(resp.body);
        if (rates != null) {
          attempts.add('frankfurter_historical_$dateStr:200:ok');
          return rates;
        }
        attempts.add('frankfurter_historical_$dateStr:200:parse_fail');
        return null;
      }
      attempts.add('frankfurter_historical_$dateStr:${resp.statusCode}');
      return null;
    } catch (e) {
      attempts.add('frankfurter_historical_${_dateFmt.format(date)}:exception:$e');
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
