import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../models/models.dart';
import '../models/pending_sms_transaction.dart';
import '../services/sms_filter.dart';
import '../services/sms_parser.dart';
import '../services/sms_pending_store.dart';
import '../services/sms_reader.dart';
import '../services/sms_rules_engine.dart';
import '../services/sms_validator.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task != 'sms_scan_task') return true;
    await Hive.initFlutter();
    final store = SmsPendingStore();
    await store.init();
    final lastTs =
        store.lastScanTs ?? DateTime.now().subtract(const Duration(days: 30));
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
  final normalized =
      body.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  return sha256.convert(utf8.encode(normalized)).toString();
}
