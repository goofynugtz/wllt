class ParsedPurchase {
  final double amount;
  final String? merchant;

  const ParsedPurchase({required this.amount, this.merchant});
}

/// Regex-only extraction of a spoken purchase ("spent 200 on coffee at Third
/// Wave") into amount + merchant. No amount match means no confident parse —
/// callers fall back to [PurchaseTranscriptAdapter] (Gemma) or surface an
/// error. Assumes the speech-to-text engine already normalizes spoken
/// numbers to digits (true for both Android's on-device and cloud
/// recognizers) — no word-to-number parsing here.
class PurchaseTranscriptParser {
  static final _amountPattern = RegExp(
    r'(?:spent|paid|cost)\s+(?:rs\.?|inr|rupees|₹)?\s*([\d,]+(?:\.\d+)?)',
    caseSensitive: false,
  );

  // Tried in this order — "at" is the most specific merchant marker in
  // natural speech ("spent 200 on coffee at Third Wave" — the merchant is
  // "Third Wave", not "coffee"), so it wins when both are present.
  static final _atMerchant =
      RegExp(r"\bat\s+([A-Za-z0-9][A-Za-z0-9\s&'.,-]{1,40})$", caseSensitive: false);
  static final _onMerchant =
      RegExp(r"\bon\s+([A-Za-z0-9][A-Za-z0-9\s&'.,-]{1,40})$", caseSensitive: false);
  static final _forMerchant =
      RegExp(r"\bfor\s+([A-Za-z0-9][A-Za-z0-9\s&'.,-]{1,40})$", caseSensitive: false);

  static ParsedPurchase? parse(String transcript) {
    final amountMatch = _amountPattern.firstMatch(transcript);
    if (amountMatch == null) return null;

    final amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', '').trim());
    if (amount == null || amount <= 0) return null;

    final merchant = _atMerchant.firstMatch(transcript)?.group(1) ??
        _onMerchant.firstMatch(transcript)?.group(1) ??
        _forMerchant.firstMatch(transcript)?.group(1);

    return ParsedPurchase(amount: amount, merchant: merchant?.trim());
  }
}
