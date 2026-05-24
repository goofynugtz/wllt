class SmsRulesEngine {
  static const _merchantMap = <String, String>{
    'zomato': 'restaurant', 'swiggy': 'restaurant', 'eatfit': 'restaurant',
    'fasoos': 'restaurant', 'box8': 'restaurant', 'faasos': 'restaurant',
    'bigbasket': 'groceries', 'dmart': 'groceries', 'blinkit': 'groceries',
    'zepto': 'groceries', 'jiomart': 'groceries', 'grofers': 'groceries',
    'swiggy instamart': 'groceries', 'dunzo': 'groceries', 'big bazaar': 'groceries',
    'amazon': 'shopping', 'flipkart': 'shopping', 'myntra': 'shopping',
    'meesho': 'shopping', 'nykaa': 'shopping', 'ajio': 'shopping',
    'decathlon': 'shopping', 'reliance digital': 'shopping', 'croma': 'shopping',
    'snapdeal': 'shopping', 'tatacliq': 'shopping',
    'uber': 'transport', 'ola': 'transport', 'rapido': 'transport',
    'bmtc': 'transport', 'best bus': 'transport', 'dtc': 'transport',
    'metro': 'transport', 'irctc': 'transport', 'redbus': 'transport',
    'yulu': 'transport', 'bounce': 'transport',
    'netflix': 'movies', 'hotstar': 'movies', 'amazon prime': 'movies',
    'inox': 'movies', 'pvr': 'movies', 'bookmyshow': 'movies',
    'sony liv': 'movies', 'zee5': 'movies', 'voot': 'movies',
    'jio cinema': 'movies', 'apple tv': 'movies', 'disney': 'movies',
    'bescom': 'utilities', 'mseb': 'utilities', 'tpddl': 'utilities',
    'bses': 'utilities', 'torrent power': 'utilities',
    'jio': 'utilities', 'airtel': 'utilities', 'vi ': 'utilities',
    'bsnl': 'utilities', 'act fibernet': 'utilities', 'hathway': 'utilities',
    'tata sky': 'utilities', 'dish tv': 'utilities',
    'apollo pharmacy': 'doctor', 'practo': 'doctor', 'pharmeasy': 'doctor',
    '1mg': 'doctor', 'medline': 'doctor', 'netmeds': 'doctor',
    'apollo hospitals': 'doctor', 'fortis': 'doctor', 'max hospital': 'doctor',
    'blue tokai': 'coffee', 'starbucks': 'coffee', 'cafe coffee day': 'coffee',
    'third wave': 'coffee', 'barista': 'coffee', 'tim hortons': 'coffee',
    'cure.fit': 'fitness', 'cult.fit': 'fitness',
    'gold gym': 'fitness', 'anytime fitness': 'fitness',
    'makemytrip': 'travel', 'goibibo': 'travel', 'cleartrip': 'travel',
    'indigo': 'travel', 'air india': 'travel', 'spicejet': 'travel',
    'oyo': 'travel', 'airbnb': 'travel', 'treebo': 'travel',
    'fabhotels': 'travel', 'agoda': 'travel',
    'byjus': 'education', "byju's": 'education', 'unacademy': 'education',
    'coursera': 'education', 'udemy': 'education', 'upgrad': 'education',
    'vedantu': 'education', 'whitehat jr': 'education',
    'jio recharge': 'phone', 'airtel recharge': 'phone', 'vi recharge': 'phone',
    'amazon gift': 'gifts', 'flipkart gift': 'gifts',
    'urban company': 'home', 'urbanclap': 'home', 'sulekha': 'home',
  };

  static const _keywordMap = <String, String>{
    'pharmacy': 'doctor', 'clinic': 'doctor', 'hospital': 'doctor',
    'medical': 'doctor', 'health': 'doctor',
    'cafe': 'coffee', 'coffee': 'coffee',
    'gym': 'fitness', 'fitness': 'fitness', 'yoga': 'fitness', 'sports': 'fitness',
    'school': 'education', 'college': 'education', 'university': 'education',
    'course': 'education', 'institute': 'education',
    'hotel': 'travel', 'resort': 'travel',
    'recharge': 'phone', 'broadband': 'internet', 'dth': 'utilities',
    'salary': 'savings', 'stipend': 'savings',
    'refund': 'savings', 'cashback': 'savings',
    'grocery': 'groceries', 'supermarket': 'groceries', 'mart': 'groceries',
    'restaurant': 'restaurant', 'food': 'restaurant', 'kitchen': 'restaurant',
    'pizza': 'restaurant', 'burger': 'restaurant', 'biryani': 'restaurant',
  };

  static String? categorize(String? merchant) {
    if (merchant == null) return null;
    final lower = merchant.toLowerCase().trim();

    for (final entry in _merchantMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    for (final entry in _keywordMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }
}
