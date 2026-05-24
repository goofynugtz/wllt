import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:lucide_icons/lucide_icons.dart';
import '../models/models.dart';
import '../models/pending_sms_transaction.dart';
import '../providers/transaction_provider.dart';
import '../providers/account_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../services/sms_validator.dart';
import '../services/sms_filter.dart';
import '../services/sms_parser.dart';
import '../services/sms_rules_engine.dart';
import '../services/sms_pending_store.dart';
import '../services/storage_service.dart';
import '../ai/sms_parser_adapter.dart';
import '../ai/categorization_adapter.dart' show InferFn;

enum ProcessResult { added, alreadyCaptured, alreadyPending, blocked, filtered }

class SmsProvider extends ChangeNotifier {
  final SmsPendingStore _store;
  final TransactionProvider _transactions;
  final AccountProvider _accounts;
  final UserPreferencesProvider _prefs;
  final StorageService _storage;

  String? _highlightedId;
  String? get highlightedId => _highlightedId;
  void clearHighlight() {
    _highlightedId = null;
    notifyListeners();
  }

  bool _miscCategoryJustCreated = false;
  bool get miscCategoryJustCreated => _miscCategoryJustCreated;
  void clearMiscCategoryFlag() => _miscCategoryJustCreated = false;

  SmsProvider({
    required SmsPendingStore store,
    required TransactionProvider transactions,
    required AccountProvider accounts,
    required UserPreferencesProvider prefs,
    required StorageService storage,
  })  : _store = store,
        _transactions = transactions,
        _accounts = accounts,
        _prefs = prefs,
        _storage = storage;

  List<PendingSmsTransaction> get pending => _store.all;
  int get pendingCount => pending.length;

  Future<ProcessResult> processRawSms(
    String sender,
    String body,
    String? smsId, {
    InferFn? aiInfer,
  }) async {
    final contentHash = _hashBody(body);
    final dedup = _store.checkDuplicate(smsId, contentHash);
    if (dedup == DedupResult.duplicateConfirmed) return ProcessResult.alreadyCaptured;
    if (dedup == DedupResult.duplicatePending) {
      final existing = pending.firstWhereOrNull((p) => p.rawSms == body);
      if (existing != null) {
        _highlightedId = existing.id;
        notifyListeners();
      }
      return ProcessResult.alreadyPending;
    }

    final verdict = SmsValidator.validate(sender, body);
    if (verdict == SmsVerdict.blocked) return ProcessResult.blocked;

    if (!SmsFilter.isFinancial(sender, body)) return ProcessResult.filtered;

    ParsedSmsResult? parsed = SmsParser.parse(sender, body);

    // If deterministic parse failed and AI is available, try AI parsing
    if (parsed == null && aiInfer != null) {
      final aiResult = await SmsParserAdapter.parse(
        rawSms: body,
        infer: aiInfer,
      );
      if (aiResult != null) {
        parsed = ParsedSmsResult(
          merchant: aiResult.merchant,
          amount: aiResult.amount,
          type: aiResult.type == 'credit' ? TransactionType.income : TransactionType.expense,
        );
      }
    }

    final hint = SmsRulesEngine.categorize(parsed?.merchant);
    final categoryId = hint != null ? _resolveCategoryId(hint) : null;
    final accountHint = parsed?.accountHint ?? _hintFromSender(sender);

    final item = PendingSmsTransaction(
      id: smsId ?? contentHash,
      rawSms: body,
      merchant: parsed?.merchant,
      amount: parsed?.amount,
      type: parsed?.type ?? TransactionType.expense,
      categoryId: categoryId,
      accountHint: accountHint,
      parsedAt: DateTime.now(),
      isUnparsed: parsed == null,
      verdict: verdict,
    );

    await _store.add(item, smsId: smsId, contentHash: contentHash);
    notifyListeners();
    return ProcessResult.added;
  }

  Future<void> confirm(String id) async {
    final item = pending.firstWhere((p) => p.id == id);
    final accountId = _resolveAccount(item.accountHint);
    final currency = _prefs.currency;
    final tx = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      transactionTitle: item.merchant ?? 'Unknown',
      categoryId: item.categoryId ?? '',
      amount: item.amount ?? 0,
      type: item.type,
      date: item.parsedAt,
      account: accountId ?? '',
      tags: [],
      baseCurrency: currency,
    );
    await _transactions.addTransaction(tx);
    await _store.confirm(id);
    notifyListeners();
  }

  Future<void> confirmAsMisc(String id) async {
    await _ensureMiscCategory();
    final miscId = _resolveCategoryId('misc') ?? 'misc';
    final item = pending.firstWhere((p) => p.id == id);
    await _store.update(id, item.copyWith(categoryId: miscId));
    await confirm(id);
  }

  Future<void> dismiss(String id) async {
    await _store.dismiss(id);
    notifyListeners();
  }

  Future<void> updateItem(
    String id, {
    String? merchant,
    double? amount,
    TransactionType? type,
    String? categoryId,
    String? accountHint,
  }) async {
    final existing = pending.firstWhere((p) => p.id == id);
    await _store.update(id, existing.copyWith(
      merchant: merchant,
      amount: amount,
      type: type,
      categoryId: categoryId,
      accountHint: accountHint,
    ));
    notifyListeners();
  }

  String? _resolveCategoryId(String hint) {
    final allCategories = [
      ...Category.categories,
      ..._storage.getCustomCategories(),
    ].where((c) => _prefs.activeCategories.isEmpty || _prefs.activeCategories.contains(c.id)).toList();

    final exact = allCategories.firstWhereOrNull(
      (c) => c.name.toLowerCase() == hint.toLowerCase(),
    );
    if (exact != null) return exact.id;

    return allCategories.firstWhereOrNull(
      (c) =>
          c.name.toLowerCase().contains(hint.toLowerCase()) ||
          hint.toLowerCase().contains(c.name.toLowerCase()),
    )?.id;
  }

  Future<void> _ensureMiscCategory() async {
    final custom = _storage.getCustomCategories();
    if (custom.any((c) => c.id == 'misc')) return;
    const misc = Category(
      id: 'misc',
      name: 'Misc',
      lucideIcon: LucideIcons.package,
      color: '#9E9E9E',
      bg: '#F5F5F5',
    );
    await _storage.saveCustomCategory(misc);
    final active = _prefs.activeCategories;
    if (!active.contains('misc')) {
      await _prefs.setCategories([...active, 'misc']);
    }
    _miscCategoryJustCreated = true;
  }

  String? _resolveAccount(String? hint) {
    if (hint == null) return null;
    final matches = _accounts.accounts
        .where((a) => a.displayName.toLowerCase().contains(hint.toLowerCase()))
        .toList();
    return matches.length == 1 ? matches.first.id : null;
  }

  String _hashBody(String body) {
    final normalized = body.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  String? _hintFromSender(String sender) {
    const hints = {
      'HDFCBK': 'HDFC', 'ICICIB': 'ICICI', 'SBIINB': 'SBI',
      'AXISBK': 'Axis', 'KOTAKB': 'Kotak',
    };
    return hints[sender.toUpperCase()];
  }
}
