typedef InferFn = Future<String> Function(String prompt);

class CategorizationAdapter {
  CategorizationAdapter._();

  static const Map<String, String> _merchantMap = {
    'swiggy': 'restaurant', 'zomato': 'restaurant', 'blinkit': 'groceries',
    'bigbasket': 'groceries', 'dunzo': 'groceries', 'zepto': 'groceries',
    'instamart': 'groceries', 'grofers': 'groceries',
    'blue tokai': 'coffee', 'starbucks': 'coffee', 'cafe coffee day': 'coffee',
    'third wave': 'coffee', 'tiger': 'coffee', 'barista': 'coffee',
    'mcdonalds': 'restaurant', 'burger king': 'restaurant', "domino's": 'restaurant',
    'pizza hut': 'restaurant', 'kfc': 'restaurant', "mcdonald's": 'restaurant',
    'subway': 'restaurant', 'haldirams': 'restaurant',
    'amazon': 'shopping', 'flipkart': 'shopping', 'myntra': 'shopping',
    'ajio': 'shopping', 'nykaa': 'shopping', 'meesho': 'shopping',
    'snapdeal': 'shopping', 'tata cliq': 'shopping', 'croma': 'shopping',
    'reliance digital': 'shopping', 'vijay sales': 'shopping',
    'ola': 'transport', 'uber': 'transport', 'rapido': 'transport',
    'namma yatri': 'transport', 'yulu': 'transport', 'bounce': 'transport',
    'irctc': 'transport', 'make my trip': 'travel', 'goibibo': 'travel',
    'easemytrip': 'travel', 'ixigo': 'travel', 'cleartrip': 'travel',
    'air india': 'travel', 'indigo': 'travel', 'spicejet': 'travel',
    'airtel': 'phone', 'jio': 'phone', 'vi': 'phone', 'bsnl': 'phone',
    'vodafone': 'phone', 'idea': 'phone',
    'netflix': 'movies', 'hotstar': 'movies', 'amazon prime': 'movies',
    'sony liv': 'movies', 'zee5': 'movies', 'jiocinema': 'movies',
    'bookmyshow': 'movies', 'pvr': 'movies', 'inox': 'movies',
    'paytm': 'shopping', 'phonepe': 'shopping',
    'hdfc': 'savings', 'icici': 'savings', 'sbi': 'savings',
    'axis': 'savings', 'kotak': 'savings', 'yes bank': 'savings',
    'indusind': 'savings', 'federal': 'savings',
    'decathlon': 'fitness', 'cult fit': 'fitness',
    'gold gym': 'fitness', 'anytime fitness': 'fitness',
    'byju': 'education', 'byjus': 'education', 'unacademy': 'education',
    'vedantu': 'education', 'coursera': 'education', 'udemy': 'education',
    'simplilearn': 'education',
    'jiomart': 'groceries', 'dmart': 'groceries',
    'reliance fresh': 'groceries', 'nature basket': 'groceries',
    'ikea': 'home', 'urban ladder': 'home', 'pepperfry': 'home',
    'apollo': 'utilities', 'medplus': 'utilities', 'netmeds': 'utilities',
    '1mg': 'utilities', 'pharmeasy': 'utilities',
    'tata power': 'utilities', 'adani electricity': 'utilities',
    'fiverr': 'work', 'upwork': 'work', 'linkedin': 'work',
    'google workspace': 'work', 'microsoft 365': 'work',
    'aws': 'work', 'digitalocean': 'work',
  };

  /// Suggests a category for [merchant].
  /// 1. Returns null immediately for empty merchant.
  /// 2. Checks deterministic [_merchantMap] — no AI call if hit.
  /// 3. Falls back to [infer] with Gemma chat prompt.
  /// 4. Validates AI output against [availableCategories] — null on mismatch.
  /// 5. Returns null on any inference error.
  static Future<String?> suggest({
    required String merchant,
    required List<String> availableCategories,
    required InferFn infer,
  }) async {
    if (merchant.trim().isEmpty) return null;

    final key = merchant.toLowerCase().trim();
    for (final entry in _merchantMap.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        if (availableCategories.contains(entry.value)) return entry.value;
      }
    }

    final categoryList = availableCategories.join(', ');
    final prompt = '<start_of_turn>user\n'
        'Classify this merchant into one category.\n'
        'Merchant: "$merchant"\n'
        'Categories: $categoryList\n'
        'Reply with only the category id.\n'
        '<end_of_turn>\n'
        '<start_of_turn>model\n';

    try {
      final raw = await infer(prompt);
      final result = raw.trim().toLowerCase();
      if (availableCategories.contains(result)) return result;
      return null;
    } catch (_) {
      return null;
    }
  }
}
