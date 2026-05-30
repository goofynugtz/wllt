import '../models/models.dart';

typedef ImportResult = ({List<Transaction> transactions, int skipped});

class DataExportService {
  static Future<void> exportTransactions({
    required List<Transaction> transactions,
    required List<Category> allCategories,
  }) async {}

  static Future<ImportResult> importTransactions(String filePath) async =>
      (transactions: <Transaction>[], skipped: 0);
}
