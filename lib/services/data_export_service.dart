import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';

typedef ImportResult = ({List<Transaction> transactions, int skipped});

class DataExportService {
  static const List<String> _headers = [
    'Date', 'Title', 'Type', 'Amount', 'Currency', 'Category', 'Account', 'Tags', 'Note',
  ];

  static Future<void> exportTransactions({
    required List<Transaction> transactions,
    required List<Category> allCategories,
  }) async {
    final categoryMap = {for (final c in allCategories) c.id: c.name};

    final rows = <List<dynamic>>[_headers];
    for (final tx in transactions) {
      rows.add([
        tx.date.toIso8601String(),
        tx.transactionTitle,
        tx.type.name,
        tx.amount,
        tx.baseCurrency,
        categoryMap[tx.categoryId] ?? tx.categoryId,
        tx.account,
        tx.tags.join('|'),
        tx.note ?? '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/wllt_export_$stamp.csv');
    await file.writeAsString(csv);

    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'text/csv')],
      subject: 'WLLT Transactions Export',
    ));
  }

  static Future<ImportResult> importTransactions(String filePath) async {
    final content = await File(filePath).readAsString();
    final rows = const CsvToListConverter(eol: '\n').convert(content);

    if (rows.length < 2) return (transactions: <Transaction>[], skipped: 0);

    final categoryNameToId = {
      for (final c in Category.categories) c.name.toLowerCase(): c.id,
    };

    final transactions = <Transaction>[];
    int skipped = 0;

    for (final row in rows.skip(1)) {
      if (row.length < 7) {
        skipped++;
        continue;
      }
      try {
        final categoryId =
            categoryNameToId[row[5].toString().toLowerCase()] ?? 'shopping';
        final tagsStr = row.length > 7 ? row[7].toString() : '';
        final noteStr = row.length > 8 ? row[8].toString() : '';
        transactions.add(Transaction(
          id: 'import_${DateTime.now().microsecondsSinceEpoch}_${transactions.length}',
          transactionTitle: row[1].toString(),
          categoryId: categoryId,
          amount: double.tryParse(row[3].toString()) ?? 0.0,
          type: TransactionType.values.firstWhere(
            (e) => e.name == row[2].toString(),
            orElse: () => TransactionType.expense,
          ),
          date: DateTime.parse(row[0].toString()),
          account: row[6].toString(),
          tags: tagsStr.isEmpty ? [] : tagsStr.split('|'),
          note: noteStr.isEmpty ? null : noteStr,
          baseCurrency: row.length > 4 ? row[4].toString() : 'USD',
        ));
      } catch (_) {
        skipped++;
      }
    }

    return (transactions: transactions, skipped: skipped);
  }
}
