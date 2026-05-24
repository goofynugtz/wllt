import 'models.dart';

enum SmsVerdict { safe, suspicious, blocked }

class PendingSmsTransaction {
  final String id;
  final String rawSms;
  final String? merchant;
  final double? amount;
  final TransactionType type;
  final String? categoryId;
  final String? accountHint;
  final DateTime parsedAt;
  final bool isUnparsed;
  final SmsVerdict verdict;

  const PendingSmsTransaction({
    required this.id,
    required this.rawSms,
    this.merchant,
    this.amount,
    required this.type,
    this.categoryId,
    this.accountHint,
    required this.parsedAt,
    required this.isUnparsed,
    required this.verdict,
  });

  PendingSmsTransaction copyWith({
    String? merchant,
    double? amount,
    TransactionType? type,
    String? categoryId,
    String? accountHint,
  }) => PendingSmsTransaction(
    id: id,
    rawSms: rawSms,
    merchant: merchant ?? this.merchant,
    amount: amount ?? this.amount,
    type: type ?? this.type,
    categoryId: categoryId ?? this.categoryId,
    accountHint: accountHint ?? this.accountHint,
    parsedAt: parsedAt,
    isUnparsed: isUnparsed,
    verdict: verdict,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'rawSms': rawSms,
    if (merchant != null) 'merchant': merchant,
    if (amount != null) 'amount': amount,
    'type': type.name,
    if (categoryId != null) 'categoryId': categoryId,
    if (accountHint != null) 'accountHint': accountHint,
    'parsedAt': parsedAt.toIso8601String(),
    'isUnparsed': isUnparsed,
    'verdict': verdict.name,
  };

  factory PendingSmsTransaction.fromJson(Map<String, dynamic> json) =>
      PendingSmsTransaction(
        id: json['id'] as String,
        rawSms: json['rawSms'] as String,
        merchant: json['merchant'] as String?,
        amount: (json['amount'] as num?)?.toDouble(),
        type: TransactionType.values.firstWhere((e) => e.name == json['type']),
        categoryId: json['categoryId'] as String?,
        accountHint: json['accountHint'] as String?,
        parsedAt: DateTime.parse(json['parsedAt'] as String),
        isUnparsed: json['isUnparsed'] as bool,
        verdict: SmsVerdict.values.firstWhere((e) => e.name == json['verdict']),
      );
}
