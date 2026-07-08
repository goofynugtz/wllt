import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

enum TransactionType { expense, income }

class ExchangeRateSnapshot {
  final String key;            // "YYYY-MM-DD_BASE"
  final String baseCurrency;
  final Map<String, double> rates;
  final String fetchedAt;      // ISO-8601

  const ExchangeRateSnapshot({
    required this.key,
    required this.baseCurrency,
    required this.rates,
    required this.fetchedAt,
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'baseCurrency': baseCurrency,
    'rates': rates,
    'fetchedAt': fetchedAt,
  };

  factory ExchangeRateSnapshot.fromJson(Map<String, dynamic> json) =>
      ExchangeRateSnapshot(
        key: json['key'] as String,
        baseCurrency: json['baseCurrency'] as String,
        rates: Map<String, double>.from(
          (json['rates'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
        ),
        fetchedAt: json['fetchedAt'] as String,
      );
}

// All Lucide icons selectable in the category picker, keyed by codePoint.
// Values are existing LucideIcons.* constants — no runtime IconData construction —
// so the release-build tree shaker can statically determine which glyphs to keep.
final Map<int, IconData> _kLucideIconByCodePoint = {
  LucideIcons.shoppingBag.codePoint:   LucideIcons.shoppingBag,
  LucideIcons.shoppingCart.codePoint:  LucideIcons.shoppingCart,
  LucideIcons.creditCard.codePoint:    LucideIcons.creditCard,
  LucideIcons.wallet.codePoint:        LucideIcons.wallet,
  LucideIcons.banknote.codePoint:      LucideIcons.banknote,
  LucideIcons.coins.codePoint:         LucideIcons.coins,
  LucideIcons.receipt.codePoint:       LucideIcons.receipt,
  LucideIcons.tag.codePoint:           LucideIcons.tag,
  LucideIcons.store.codePoint:         LucideIcons.store,
  LucideIcons.gift.codePoint:          LucideIcons.gift,
  LucideIcons.package.codePoint:       LucideIcons.package,
  LucideIcons.landmark.codePoint:      LucideIcons.landmark,
  LucideIcons.indianRupee.codePoint:   LucideIcons.indianRupee,
  LucideIcons.piggyBank.codePoint:     LucideIcons.piggyBank,
  LucideIcons.briefcase.codePoint:     LucideIcons.briefcase,
  LucideIcons.laptop.codePoint:        LucideIcons.laptop,
  LucideIcons.monitor.codePoint:       LucideIcons.monitor,
  LucideIcons.cpu.codePoint:           LucideIcons.cpu,
  LucideIcons.printer.codePoint:       LucideIcons.printer,
  LucideIcons.mail.codePoint:          LucideIcons.mail,
  LucideIcons.phone.codePoint:         LucideIcons.phone,
  LucideIcons.smartphone.codePoint:    LucideIcons.smartphone,
  LucideIcons.building.codePoint:      LucideIcons.building,
  LucideIcons.building2.codePoint:     LucideIcons.building2,
  LucideIcons.coffee.codePoint:        LucideIcons.coffee,
  LucideIcons.utensils.codePoint:      LucideIcons.utensils,
  LucideIcons.pizza.codePoint:         LucideIcons.pizza,
  LucideIcons.beer.codePoint:          LucideIcons.beer,
  LucideIcons.wine.codePoint:          LucideIcons.wine,
  LucideIcons.apple.codePoint:         LucideIcons.apple,
  LucideIcons.banana.codePoint:        LucideIcons.banana,
  LucideIcons.egg.codePoint:           LucideIcons.egg,
  LucideIcons.cookie.codePoint:        LucideIcons.cookie,
  LucideIcons.candy.codePoint:         LucideIcons.candy,
  LucideIcons.fish.codePoint:          LucideIcons.fish,
  LucideIcons.milk.codePoint:          LucideIcons.milk,
  LucideIcons.drumstick.codePoint:     LucideIcons.drumstick,
  LucideIcons.cake.codePoint:          LucideIcons.cake,
  LucideIcons.beef.codePoint:          LucideIcons.beef,
  LucideIcons.iceCream.codePoint:      LucideIcons.iceCream,
  LucideIcons.croissant.codePoint:     LucideIcons.croissant,
  LucideIcons.sandwich.codePoint:      LucideIcons.sandwich,
  LucideIcons.car.codePoint:           LucideIcons.car,
  LucideIcons.bus.codePoint:           LucideIcons.bus,
  LucideIcons.bike.codePoint:          LucideIcons.bike,
  LucideIcons.plane.codePoint:         LucideIcons.plane,
  LucideIcons.train.codePoint:         LucideIcons.train,
  LucideIcons.ship.codePoint:          LucideIcons.ship,
  LucideIcons.truck.codePoint:         LucideIcons.truck,
  LucideIcons.fuel.codePoint:          LucideIcons.fuel,
  LucideIcons.navigation.codePoint:    LucideIcons.navigation,
  LucideIcons.activity.codePoint:      LucideIcons.activity,
  LucideIcons.dumbbell.codePoint:      LucideIcons.dumbbell,
  LucideIcons.heartPulse.codePoint:    LucideIcons.heartPulse,
  LucideIcons.stethoscope.codePoint:   LucideIcons.stethoscope,
  LucideIcons.pill.codePoint:          LucideIcons.pill,
  LucideIcons.thermometer.codePoint:   LucideIcons.thermometer,
  LucideIcons.cross.codePoint:         LucideIcons.cross,
  LucideIcons.baby.codePoint:          LucideIcons.baby,
  LucideIcons.heart.codePoint:         LucideIcons.heart,
  LucideIcons.film.codePoint:          LucideIcons.film,
  LucideIcons.music.codePoint:         LucideIcons.music,
  LucideIcons.headphones.codePoint:    LucideIcons.headphones,
  LucideIcons.camera.codePoint:        LucideIcons.camera,
  LucideIcons.mic.codePoint:           LucideIcons.mic,
  LucideIcons.gamepad2.codePoint:      LucideIcons.gamepad2,
  LucideIcons.tv.codePoint:            LucideIcons.tv,
  LucideIcons.star.codePoint:          LucideIcons.star,
  LucideIcons.trophy.codePoint:        LucideIcons.trophy,
  LucideIcons.award.codePoint:         LucideIcons.award,
  LucideIcons.home.codePoint:          LucideIcons.home,
  LucideIcons.lamp.codePoint:          LucideIcons.lamp,
  LucideIcons.armchair.codePoint:      LucideIcons.armchair,
  LucideIcons.bed.codePoint:           LucideIcons.bed,
  LucideIcons.bath.codePoint:          LucideIcons.bath,
  LucideIcons.wrench.codePoint:        LucideIcons.wrench,
  LucideIcons.hammer.codePoint:        LucideIcons.hammer,
  LucideIcons.plug.codePoint:          LucideIcons.plug,
  LucideIcons.zap.codePoint:           LucideIcons.zap,
  LucideIcons.wifi.codePoint:          LucideIcons.wifi,
  LucideIcons.bookOpen.codePoint:      LucideIcons.bookOpen,
  LucideIcons.graduationCap.codePoint: LucideIcons.graduationCap,
  LucideIcons.library.codePoint:       LucideIcons.library,
  LucideIcons.microscope.codePoint:    LucideIcons.microscope,
  LucideIcons.pencil.codePoint:        LucideIcons.pencil,
  LucideIcons.school.codePoint:        LucideIcons.school,
  LucideIcons.newspaper.codePoint:     LucideIcons.newspaper,
  LucideIcons.luggage.codePoint:       LucideIcons.luggage,
  LucideIcons.hotel.codePoint:         LucideIcons.hotel,
  LucideIcons.mapPin.codePoint:        LucideIcons.mapPin,
  LucideIcons.compass.codePoint:       LucideIcons.compass,
  LucideIcons.globe.codePoint:         LucideIcons.globe,
  LucideIcons.flag.codePoint:          LucideIcons.flag,
  LucideIcons.mountain.codePoint:      LucideIcons.mountain,
  LucideIcons.sun.codePoint:           LucideIcons.sun,
  LucideIcons.umbrella.codePoint:      LucideIcons.umbrella,
  LucideIcons.gem.codePoint:           LucideIcons.gem,
  LucideIcons.diamond.codePoint:       LucideIcons.diamond,
  LucideIcons.crown.codePoint:         LucideIcons.crown,
  LucideIcons.leaf.codePoint:          LucideIcons.leaf,
};

class Category {
  final String id;
  final String name;
  final String? iconPath;     // SVG asset path — null for Lucide categories
  final IconData? lucideIcon; // Lucide icon — null for SVG categories
  final String color;         // Hex, e.g. "#EBA9A9" — used for icon circle bg
  final String bg;            // Hex light variant — used in existing transaction badges

  const Category({
    required this.id,
    required this.name,
    this.iconPath,
    this.lucideIcon,
    required this.color,
    required this.bg,
  }) : assert(
          iconPath != null || lucideIcon != null,
          'Category must have either iconPath or lucideIcon',
        );

  bool get isLucideIcon => lucideIcon != null;

  /// Backward compat: existing screens that call category.icon still compile.
  String get icon => iconPath ?? '';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'bg': bg,
    if (iconPath != null) 'iconPath': iconPath,
    if (lucideIcon != null) ...{
      'iconCodePoint': lucideIcon!.codePoint,
      'iconFontFamily': lucideIcon!.fontFamily,
      'iconFontPackage': lucideIcon!.fontPackage,
    },
  };

  factory Category.fromJson(Map<String, dynamic> json) {
    final IconData? lucideIcon = json['iconCodePoint'] != null
        ? _kLucideIconByCodePoint[json['iconCodePoint'] as int] ??
            LucideIcons.shoppingBag
        : null;
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      lucideIcon: lucideIcon,
      iconPath: json['iconPath'] as String?,
      color: json['color'] as String,
      bg: (json['bg'] as String?) ?? json['color'] as String,
    );
  }

  static const List<Category> categories = [
    Category(id: 'shopping',   name: 'Shopping',   lucideIcon: LucideIcons.shoppingBag,  color: '#EBA9A9', bg: '#fce4ec'),
    Category(id: 'restaurant', name: 'Restaurant', lucideIcon: LucideIcons.utensils,     color: '#E2B932', bg: '#fffde7'),
    Category(id: 'work',       name: 'Work',       lucideIcon: LucideIcons.briefcase,    color: '#74A1DB', bg: '#e3f2fd'),
    Category(id: 'doctor',     name: 'Doctor',     lucideIcon: LucideIcons.activity,     color: '#9D85E5', bg: '#ede7f6'),
    Category(id: 'coffee',     name: 'Coffee',     lucideIcon: LucideIcons.coffee,       color: '#70C01F', bg: '#f1f8e9'),
    Category(id: 'movies',     name: 'Movies',     lucideIcon: LucideIcons.film,         color: '#86D9BC', bg: '#e0f2f1'),
    Category(id: 'transport',  name: 'Transport',  lucideIcon: LucideIcons.car,          color: '#8FC9E2', bg: '#e1f5fe'),
    Category(id: 'groceries',  name: 'Groceries',  lucideIcon: LucideIcons.shoppingCart, color: '#F4A261', bg: '#fff3e0'),
    Category(id: 'utilities',  name: 'Utilities',  lucideIcon: LucideIcons.zap,          color: '#E76F51', bg: '#fbe9e7'),
    Category(id: 'music',      name: 'Music',      lucideIcon: LucideIcons.music,        color: '#2A9D8F', bg: '#e0f7fa'),
    Category(id: 'travel',     name: 'Travel',     lucideIcon: LucideIcons.plane,        color: '#FFB703', bg: '#fff8e1'),
    Category(id: 'fitness',    name: 'Fitness',    lucideIcon: LucideIcons.dumbbell,     color: '#C77FFF', bg: '#f3e5f5'),
    Category(id: 'education',  name: 'Education',  lucideIcon: LucideIcons.bookOpen,     color: '#06D6A0', bg: '#e8f5e9'),
    Category(id: 'savings',    name: 'Savings',    lucideIcon: LucideIcons.piggyBank,    color: '#FB8500', bg: '#fff3e0'),
    Category(id: 'home',       name: 'Home',       lucideIcon: LucideIcons.home,         color: '#FF6B6B', bg: '#ffebee'),
    Category(id: 'phone',      name: 'Phone',      lucideIcon: LucideIcons.smartphone,   color: '#4CC9F0', bg: '#e3f2fd'),
    Category(id: 'internet',   name: 'Internet',   lucideIcon: LucideIcons.wifi,         color: '#A8DADC', bg: '#e0f7fa'),
    Category(id: 'gifts',      name: 'Gifts',      lucideIcon: LucideIcons.gift,         color: '#E63946', bg: '#ffebee'),
  ];

  static Category getById(String id) {
    return categories.firstWhere(
      (cat) => cat.id == id,
      orElse: () => categories.first,
    );
  }
}

class Transaction {
  final String id;
  final String transactionTitle;
  final String categoryId;
  final double amount;
  final TransactionType type;
  final DateTime date;
  final String account;
  final List<String> tags;
  final String? note;
  final String baseCurrency;

  const Transaction({
    required this.id,
    required this.transactionTitle,
    required this.categoryId,
    required this.amount,
    required this.type,
    required this.date,
    required this.account,
    required this.tags,
    this.note,
    this.baseCurrency = 'USD',
  });

  Transaction copyWith({
    String? id,
    String? transactionTitle,
    String? categoryId,
    double? amount,
    TransactionType? type,
    DateTime? date,
    String? account,
    List<String>? tags,
    String? note,
    String? baseCurrency,
  }) => Transaction(
    id: id ?? this.id,
    transactionTitle: transactionTitle ?? this.transactionTitle,
    categoryId: categoryId ?? this.categoryId,
    amount: amount ?? this.amount,
    type: type ?? this.type,
    date: date ?? this.date,
    account: account ?? this.account,
    tags: tags ?? this.tags,
    note: note ?? this.note,
    baseCurrency: baseCurrency ?? this.baseCurrency,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'transactionTitle': transactionTitle,
    'categoryId': categoryId,
    'amount': amount,
    'type': type.name,
    'date': date.toIso8601String(),
    'account': account,
    'tags': tags,
    'baseCurrency': baseCurrency,
    if (note != null) 'note': note,
  };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as String,
    transactionTitle: json['transactionTitle'] as String,
    categoryId: json['categoryId'] as String,
    amount: (json['amount'] as num).toDouble(),
    type: TransactionType.values.firstWhere((e) => e.name == json['type']),
    date: DateTime.parse(json['date'] as String),
    account: json['account'] as String,
    tags: ((json['tags'] as List?) ?? []).cast<String>(),
    note: json['note'] as String?,
    baseCurrency: json['baseCurrency'] as String? ?? 'USD',
  );

  /// Fixed-calendar entries plus device-clock-anchored entries. Fixed months
  /// that fall in the current or previous month are dropped because the
  /// dynamic blocks already cover them — otherwise rent/salary/subscriptions
  /// would double up whenever the device clock overlaps a fixed month.
  static List<Transaction> get dummyData {
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1);
    bool coveredByDynamic(DateTime d) =>
        (d.year == now.year && d.month == now.month) ||
        (d.year == prev.year && d.month == prev.month);
    return [
      ..._dynamicDummySource,
      ..._fixedDummySource.where((tx) => !coveredByDynamic(tx.date)),
    ].map((tx) => tx.copyWith(baseCurrency: 'INR')).toList();
  }

  /// Date [monthsAgo] months before now, on [day]. Keeps the dynamic dummy
  /// blocks anchored to the device clock so dev mode always has current-month
  /// and previous-month data (DateTime normalizes month <= 0 into prior years).
  static DateTime _dm(int monthsAgo, int day) {
    final now = DateTime.now();
    return DateTime(now.year, now.month - monthsAgo, day);
  }

  static final List<Transaction> _fixedDummySource = [
    Transaction(
      id: 't1',
      transactionTitle: 'Big Bazaar',
      categoryId: 'groceries',
      amount: 1240,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 28),
      account: 'a1',
      tags: ['groceries'],
      note: 'Monthly groceries run',
    ),
    Transaction(
      id: 't2',
      transactionTitle: 'Apollo Pharmacy',
      categoryId: 'doctor',
      amount: 380,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 28),
      account: 'a1',
      tags: ['doctor'],
    ),
    Transaction(
      id: 't3',
      transactionTitle: 'Blue Tokai',
      categoryId: 'restaurant',
      amount: 220,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 28),
      account: 'a3',
      tags: ['restaurant'],
    ),
    Transaction(
      id: 't4',
      transactionTitle: 'Salary Credit',
      categoryId: 'savings',
      amount: 85000,
      type: TransactionType.income,
      date: DateTime(2026, 3, 27),
      account: 'a1',
      tags: ['savings'],
    ),
    Transaction(
      id: 't5',
      transactionTitle: 'Swiggy',
      categoryId: 'restaurant',
      amount: 450,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 27),
      account: 'a2',
      tags: ['restaurant'],
    ),
    Transaction(
      id: 't6',
      transactionTitle: 'Ola',
      categoryId: 'transport',
      amount: 180,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 26),
      account: 'a1',
      tags: ['transport'],
    ),
    Transaction(
      id: 't7',
      transactionTitle: 'Netflix',
      categoryId: 'movies',
      amount: 649,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 26),
      account: 'a2',
      tags: ['movies'],
    ),
    Transaction(
      id: 't8',
      transactionTitle: 'Zomato',
      categoryId: 'restaurant',
      amount: 349,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 25),
      account: 'a1',
      tags: ['restaurant'],
    ),
    Transaction(
      id: 't9',
      transactionTitle: 'BESCOM',
      categoryId: 'utilities',
      amount: 1850,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 25),
      account: 'a1',
      tags: ['utilities'],
    ),
    Transaction(
      id: 't10',
      transactionTitle: 'Amazon',
      categoryId: 'shopping',
      amount: 2399,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 24),
      account: 'a2',
      tags: ['shopping'],
    ),
    Transaction(
      id: 't11',
      transactionTitle: 'Decathlon',
      categoryId: 'shopping',
      amount: 3200,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 24),
      account: 'a2',
      tags: ['shopping'],
    ),
    Transaction(
      id: 't12',
      transactionTitle: 'BMTC Bus',
      categoryId: 'transport',
      amount: 35,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 23),
      account: 'a3',
      tags: ['transport'],
    ),
    Transaction(
      id: 't13',
      transactionTitle: 'Inox Movies',
      categoryId: 'movies',
      amount: 380,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 22),
      account: 'a2',
      tags: ['movies'],
    ),
    Transaction(
      id: 't14',
      transactionTitle: 'D-Mart',
      categoryId: 'groceries',
      amount: 2100,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 20),
      account: 'a1',
      tags: ['groceries'],
    ),
    Transaction(
      id: 't15',
      transactionTitle: 'Myntra',
      categoryId: 'shopping',
      amount: 1899,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 18),
      account: 'a2',
      tags: ['shopping'],
    ),
    Transaction(
      id: 't16',
      transactionTitle: 'Rapido',
      categoryId: 'transport',
      amount: 90,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 19),
      account: 'a3',
      tags: ['transport'],
    ),
    Transaction(
      id: 't17',
      transactionTitle: 'Blinkit',
      categoryId: 'groceries',
      amount: 650,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 17),
      account: 'a2',
      note: 'Quick grocery run',
      tags: ['groceries'],
    ),
    Transaction(
      id: 't18',
      transactionTitle: 'Hotstar',
      categoryId: 'movies',
      amount: 299,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 10),
      account: 'a2',
      tags: ['movies'],
    ),
    Transaction(
      id: 't19',
      transactionTitle: 'Freelance Project',
      categoryId: 'savings',
      amount: 25000,
      type: TransactionType.income,
      date: DateTime(2026, 3, 15),
      account: 'a1',
      note: 'UI design project',
      tags: ['savings'],
    ),
    Transaction(
      id: 't20',
      transactionTitle: 'House Rent',
      categoryId: 'home',
      amount: 18000,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 1),
      account: 'a1',
      tags: ['home'],
    ),
    Transaction(
      id: 't21',
      transactionTitle: 'Salary Credit',
      categoryId: 'savings',
      amount: 85000,
      type: TransactionType.income,
      date: DateTime(2026, 2, 27),
      account: 'a1',
      tags: ['savings'],
    ),
    Transaction(
      id: 't22',
      transactionTitle: 'Swiggy',
      categoryId: 'restaurant',
      amount: 380,
      type: TransactionType.expense,
      date: DateTime(2026, 2, 25),
      account: 'a1',
      tags: ['restaurant'],
    ),
    Transaction(
      id: 't23',
      transactionTitle: 'BigBasket',
      categoryId: 'groceries',
      amount: 1890,
      type: TransactionType.expense,
      date: DateTime(2026, 2, 20),
      account: 'a1',
      tags: ['groceries'],
    ),
    Transaction(
      id: 't24',
      transactionTitle: 'Uber',
      categoryId: 'transport',
      amount: 420,
      type: TransactionType.expense,
      date: DateTime(2026, 2, 18),
      account: 'a2',
      tags: ['transport'],
    ),
    // ── August 2026 ──────────────────────────────────────────────────────────
    // Festive month: Rakhi gifts plus the annual health-insurance premium.
    Transaction(id: 'th01', transactionTitle: 'House Rent', categoryId: 'home', amount: 19000, type: TransactionType.expense, date: DateTime(2026, 8, 1), account: 'HDFC Bank', tags: ['home']),
    Transaction(id: 'th02', transactionTitle: 'Salary Credit', categoryId: 'savings', amount: 85000, type: TransactionType.income, date: DateTime(2026, 8, 1), account: 'HDFC Bank', tags: ['savings']),
    Transaction(id: 'th03', transactionTitle: 'Groww SIP', categoryId: 'savings', amount: 10000, type: TransactionType.expense, date: DateTime(2026, 8, 2), account: 'HDFC Bank', tags: ['savings']),
    Transaction(id: 'th04', transactionTitle: 'ACT Fibernet', categoryId: 'internet', amount: 1180, type: TransactionType.expense, date: DateTime(2026, 8, 3), account: 'HDFC Bank', tags: ['internet']),
    Transaction(id: 'th05', transactionTitle: 'GitHub Copilot', categoryId: 'work', amount: 850, type: TransactionType.expense, date: DateTime(2026, 8, 4), account: 'ICICI Bank', tags: ['work']),
    Transaction(id: 'th06', transactionTitle: 'D-Mart', categoryId: 'groceries', amount: 2420, type: TransactionType.expense, date: DateTime(2026, 8, 5), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'th07', transactionTitle: 'Jio Recharge', categoryId: 'phone', amount: 299, type: TransactionType.expense, date: DateTime(2026, 8, 6), account: 'HDFC Bank', tags: ['phone']),
    Transaction(id: 'th08', transactionTitle: 'HDFC Ergo Premium', categoryId: 'savings', amount: 12500, type: TransactionType.expense, date: DateTime(2026, 8, 7), account: 'HDFC Bank', note: 'Annual health insurance', tags: ['savings']),
    Transaction(id: 'th09', transactionTitle: 'BESCOM', categoryId: 'utilities', amount: 1580, type: TransactionType.expense, date: DateTime(2026, 8, 9), account: 'HDFC Bank', tags: ['utilities']),
    Transaction(id: 'th10', transactionTitle: 'Spotify', categoryId: 'music', amount: 119, type: TransactionType.expense, date: DateTime(2026, 8, 10), account: 'ICICI Bank', tags: ['music']),
    Transaction(id: 'th11', transactionTitle: 'Amazon', categoryId: 'gifts', amount: 1850, type: TransactionType.expense, date: DateTime(2026, 8, 12), account: 'ICICI Bank', note: 'Rakhi gifts', tags: ['gifts']),
    Transaction(id: 'th12', transactionTitle: 'Swiggy', categoryId: 'restaurant', amount: 410, type: TransactionType.expense, date: DateTime(2026, 8, 14), account: 'ICICI Bank', tags: ['restaurant']),
    Transaction(id: 'th13', transactionTitle: 'Netflix', categoryId: 'movies', amount: 649, type: TransactionType.expense, date: DateTime(2026, 8, 15), account: 'ICICI Bank', tags: ['movies']),
    Transaction(id: 'th14', transactionTitle: 'Third Wave Coffee', categoryId: 'coffee', amount: 420, type: TransactionType.expense, date: DateTime(2026, 8, 18), account: 'Cash', tags: ['coffee']),
    Transaction(id: 'th15', transactionTitle: 'Ola', categoryId: 'transport', amount: 350, type: TransactionType.expense, date: DateTime(2026, 8, 20), account: 'Cash', tags: ['transport']),
    Transaction(id: 'th16', transactionTitle: 'Udemy', categoryId: 'education', amount: 649, type: TransactionType.expense, date: DateTime(2026, 8, 22), account: 'ICICI Bank', note: 'Kubernetes course', tags: ['education']),
    Transaction(id: 'th17', transactionTitle: 'Blinkit', categoryId: 'groceries', amount: 740, type: TransactionType.expense, date: DateTime(2026, 8, 24), account: 'ICICI Bank', tags: ['groceries']),
    Transaction(id: 'th18', transactionTitle: 'Zomato', categoryId: 'restaurant', amount: 480, type: TransactionType.expense, date: DateTime(2026, 8, 28), account: 'HDFC Bank', tags: ['restaurant']),

    // ── July 2026 ────────────────────────────────────────────────────────────
    Transaction(id: 'tf01', transactionTitle: 'House Rent', categoryId: 'home', amount: 19000, type: TransactionType.expense, date: DateTime(2026, 7, 1), account: 'HDFC Bank', tags: ['home']),
    Transaction(id: 'tf02', transactionTitle: 'Salary Credit', categoryId: 'savings', amount: 85000, type: TransactionType.income, date: DateTime(2026, 7, 1), account: 'HDFC Bank', tags: ['savings']),
    Transaction(id: 'tf03', transactionTitle: 'Groww SIP', categoryId: 'savings', amount: 10000, type: TransactionType.expense, date: DateTime(2026, 7, 2), account: 'HDFC Bank', tags: ['savings']),
    Transaction(id: 'tf04', transactionTitle: 'ACT Fibernet', categoryId: 'internet', amount: 1180, type: TransactionType.expense, date: DateTime(2026, 7, 3), account: 'HDFC Bank', tags: ['internet']),
    Transaction(id: 'tf05', transactionTitle: 'GitHub Copilot', categoryId: 'work', amount: 850, type: TransactionType.expense, date: DateTime(2026, 7, 4), account: 'ICICI Bank', tags: ['work']),
    Transaction(id: 'tf06', transactionTitle: 'BigBasket', categoryId: 'groceries', amount: 2240, type: TransactionType.expense, date: DateTime(2026, 7, 5), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'tf07', transactionTitle: 'Jio Recharge', categoryId: 'phone', amount: 299, type: TransactionType.expense, date: DateTime(2026, 7, 6), account: 'HDFC Bank', tags: ['phone']),
    Transaction(id: 'tf08', transactionTitle: 'BESCOM', categoryId: 'utilities', amount: 1620, type: TransactionType.expense, date: DateTime(2026, 7, 8), account: 'HDFC Bank', tags: ['utilities']),
    Transaction(id: 'tf09', transactionTitle: 'Spotify', categoryId: 'music', amount: 119, type: TransactionType.expense, date: DateTime(2026, 7, 10), account: 'ICICI Bank', tags: ['music']),
    Transaction(id: 'tf10', transactionTitle: 'Practo Consult', categoryId: 'doctor', amount: 500, type: TransactionType.expense, date: DateTime(2026, 7, 11), account: 'ICICI Bank', tags: ['doctor']),
    Transaction(id: 'tf11', transactionTitle: 'Indian Oil', categoryId: 'transport', amount: 1800, type: TransactionType.expense, date: DateTime(2026, 7, 13), account: 'HDFC Bank', note: 'Full tank', tags: ['transport']),
    Transaction(id: 'tf12', transactionTitle: 'Netflix', categoryId: 'movies', amount: 649, type: TransactionType.expense, date: DateTime(2026, 7, 15), account: 'ICICI Bank', tags: ['movies']),
    Transaction(id: 'tf13', transactionTitle: 'Swiggy', categoryId: 'restaurant', amount: 460, type: TransactionType.expense, date: DateTime(2026, 7, 17), account: 'ICICI Bank', tags: ['restaurant']),
    Transaction(id: 'tf14', transactionTitle: 'PVR Cinemas', categoryId: 'movies', amount: 780, type: TransactionType.expense, date: DateTime(2026, 7, 19), account: 'ICICI Bank', tags: ['movies']),
    Transaction(id: 'tf15', transactionTitle: 'Blinkit', categoryId: 'groceries', amount: 850, type: TransactionType.expense, date: DateTime(2026, 7, 21), account: 'ICICI Bank', tags: ['groceries']),
    Transaction(id: 'tf16', transactionTitle: 'Amazon', categoryId: 'shopping', amount: 3200, type: TransactionType.expense, date: DateTime(2026, 7, 23), account: 'ICICI Bank', note: 'Mechanical keyboard', tags: ['shopping']),
    Transaction(id: 'tf17', transactionTitle: 'Uber', categoryId: 'transport', amount: 280, type: TransactionType.expense, date: DateTime(2026, 7, 26), account: 'HDFC Bank', tags: ['transport']),
    Transaction(id: 'tf18', transactionTitle: 'Zomato', categoryId: 'restaurant', amount: 390, type: TransactionType.expense, date: DateTime(2026, 7, 29), account: 'HDFC Bank', tags: ['restaurant']),

    // ── June 2026 ────────────────────────────────────────────────────────────
    // Freelance payout funds a WFH-setup splurge; AWS bill for a side project.
    Transaction(id: 'te01', transactionTitle: 'House Rent', categoryId: 'home', amount: 19000, type: TransactionType.expense, date: DateTime(2026, 6, 1), account: 'HDFC Bank', tags: ['home']),
    Transaction(id: 'te02', transactionTitle: 'Salary Credit', categoryId: 'savings', amount: 85000, type: TransactionType.income, date: DateTime(2026, 6, 1), account: 'HDFC Bank', tags: ['savings']),
    Transaction(id: 'te03', transactionTitle: 'Groww SIP', categoryId: 'savings', amount: 10000, type: TransactionType.expense, date: DateTime(2026, 6, 2), account: 'HDFC Bank', tags: ['savings']),
    Transaction(id: 'te04', transactionTitle: 'ACT Fibernet', categoryId: 'internet', amount: 1180, type: TransactionType.expense, date: DateTime(2026, 6, 3), account: 'HDFC Bank', tags: ['internet']),
    Transaction(id: 'te05', transactionTitle: 'GitHub Copilot', categoryId: 'work', amount: 850, type: TransactionType.expense, date: DateTime(2026, 6, 4), account: 'ICICI Bank', tags: ['work']),
    Transaction(id: 'te06', transactionTitle: 'D-Mart', categoryId: 'groceries', amount: 1980, type: TransactionType.expense, date: DateTime(2026, 6, 6), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'te07', transactionTitle: 'Jio Recharge', categoryId: 'phone', amount: 299, type: TransactionType.expense, date: DateTime(2026, 6, 6), account: 'HDFC Bank', tags: ['phone']),
    Transaction(id: 'te08', transactionTitle: 'BESCOM', categoryId: 'utilities', amount: 1750, type: TransactionType.expense, date: DateTime(2026, 6, 9), account: 'HDFC Bank', tags: ['utilities']),
    Transaction(id: 'te09', transactionTitle: 'Spotify', categoryId: 'music', amount: 119, type: TransactionType.expense, date: DateTime(2026, 6, 10), account: 'ICICI Bank', tags: ['music']),
    Transaction(id: 'te10', transactionTitle: 'Freelance Project', categoryId: 'savings', amount: 30000, type: TransactionType.income, date: DateTime(2026, 6, 12), account: 'HDFC Bank', note: 'API integration for client', tags: ['savings']),
    Transaction(id: 'te11', transactionTitle: 'Croma', categoryId: 'shopping', amount: 24500, type: TransactionType.expense, date: DateTime(2026, 6, 14), account: 'ICICI Bank', note: '27-inch monitor for WFH', tags: ['shopping']),
    Transaction(id: 'te12', transactionTitle: 'Swiggy', categoryId: 'restaurant', amount: 530, type: TransactionType.expense, date: DateTime(2026, 6, 15), account: 'ICICI Bank', tags: ['restaurant']),
    Transaction(id: 'te13', transactionTitle: 'Netflix', categoryId: 'movies', amount: 649, type: TransactionType.expense, date: DateTime(2026, 6, 15), account: 'ICICI Bank', tags: ['movies']),
    Transaction(id: 'te14', transactionTitle: 'Blue Tokai', categoryId: 'coffee', amount: 380, type: TransactionType.expense, date: DateTime(2026, 6, 18), account: 'Cash', tags: ['coffee']),
    Transaction(id: 'te15', transactionTitle: 'Rapido', categoryId: 'transport', amount: 120, type: TransactionType.expense, date: DateTime(2026, 6, 20), account: 'Cash', tags: ['transport']),
    Transaction(id: 'te16', transactionTitle: 'AWS', categoryId: 'work', amount: 920, type: TransactionType.expense, date: DateTime(2026, 6, 21), account: 'ICICI Bank', note: 'Side-project hosting', tags: ['work']),
    Transaction(id: 'te17', transactionTitle: 'BigBasket', categoryId: 'groceries', amount: 1540, type: TransactionType.expense, date: DateTime(2026, 6, 24), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'te18', transactionTitle: 'Zomato', categoryId: 'restaurant', amount: 360, type: TransactionType.expense, date: DateTime(2026, 6, 27), account: 'HDFC Bank', tags: ['restaurant']),

    // ── May 2026 ─────────────────────────────────────────────────────────────
    // Conference-trip month: flight, hotel, client dinner, airport cabs.
    Transaction(id: 'tc01', transactionTitle: 'House Rent', categoryId: 'home', amount: 19000, type: TransactionType.expense, date: DateTime(2026, 5, 1), account: 'HDFC Bank', tags: ['home']),
    Transaction(id: 'tc02', transactionTitle: 'Salary Credit', categoryId: 'savings', amount: 85000, type: TransactionType.income, date: DateTime(2026, 5, 1), account: 'HDFC Bank', tags: ['savings']),
    Transaction(id: 'tc03', transactionTitle: 'Groww SIP', categoryId: 'savings', amount: 10000, type: TransactionType.expense, date: DateTime(2026, 5, 2), account: 'HDFC Bank', tags: ['savings']),
    Transaction(id: 'tc04', transactionTitle: 'ACT Fibernet', categoryId: 'internet', amount: 1180, type: TransactionType.expense, date: DateTime(2026, 5, 3), account: 'HDFC Bank', tags: ['internet']),
    Transaction(id: 'tc05', transactionTitle: 'GitHub Copilot', categoryId: 'work', amount: 850, type: TransactionType.expense, date: DateTime(2026, 5, 4), account: 'ICICI Bank', tags: ['work']),
    Transaction(id: 'tc06', transactionTitle: 'BigBasket', categoryId: 'groceries', amount: 2100, type: TransactionType.expense, date: DateTime(2026, 5, 5), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'tc07', transactionTitle: 'Jio Recharge', categoryId: 'phone', amount: 299, type: TransactionType.expense, date: DateTime(2026, 5, 6), account: 'HDFC Bank', tags: ['phone']),
    Transaction(id: 'tc08', transactionTitle: 'BESCOM', categoryId: 'utilities', amount: 2250, type: TransactionType.expense, date: DateTime(2026, 5, 8), account: 'HDFC Bank', tags: ['utilities']),
    Transaction(id: 'tc09', transactionTitle: 'Spotify', categoryId: 'music', amount: 119, type: TransactionType.expense, date: DateTime(2026, 5, 10), account: 'ICICI Bank', tags: ['music']),
    Transaction(id: 'tc10', transactionTitle: 'IndiGo Airlines', categoryId: 'travel', amount: 5600, type: TransactionType.expense, date: DateTime(2026, 5, 12), account: 'ICICI Bank', note: 'BLR-DEL, tech conference', tags: ['travel']),
    Transaction(id: 'tc11', transactionTitle: 'OYO Rooms', categoryId: 'travel', amount: 4200, type: TransactionType.expense, date: DateTime(2026, 5, 13), account: 'ICICI Bank', note: '2 nights, conference stay', tags: ['travel']),
    Transaction(id: 'tc12', transactionTitle: 'Barbeque Nation', categoryId: 'restaurant', amount: 1850, type: TransactionType.expense, date: DateTime(2026, 5, 14), account: 'ICICI Bank', note: 'Client dinner', tags: ['restaurant']),
    Transaction(id: 'tc13', transactionTitle: 'Uber', categoryId: 'transport', amount: 640, type: TransactionType.expense, date: DateTime(2026, 5, 15), account: 'HDFC Bank', note: 'Airport drop', tags: ['transport']),
    Transaction(id: 'tc14', transactionTitle: 'Netflix', categoryId: 'movies', amount: 649, type: TransactionType.expense, date: DateTime(2026, 5, 15), account: 'ICICI Bank', tags: ['movies']),
    Transaction(id: 'tc15', transactionTitle: 'Zomato', categoryId: 'restaurant', amount: 420, type: TransactionType.expense, date: DateTime(2026, 5, 19), account: 'HDFC Bank', tags: ['restaurant']),
    Transaction(id: 'tc16', transactionTitle: 'Blinkit', categoryId: 'groceries', amount: 690, type: TransactionType.expense, date: DateTime(2026, 5, 22), account: 'ICICI Bank', tags: ['groceries']),
    Transaction(id: 'tc17', transactionTitle: 'Myntra', categoryId: 'shopping', amount: 2300, type: TransactionType.expense, date: DateTime(2026, 5, 24), account: 'ICICI Bank', tags: ['shopping']),
    Transaction(id: 'tc18', transactionTitle: 'Cult.fit', categoryId: 'fitness', amount: 1580, type: TransactionType.expense, date: DateTime(2026, 5, 26), account: 'ICICI Bank', tags: ['fitness']),

    // ── April 2026 ───────────────────────────────────────────────────────────
    Transaction(id: 'tb01', transactionTitle: 'House Rent', categoryId: 'home', amount: 19000, type: TransactionType.expense, date: DateTime(2026, 4, 1), account: 'HDFC Bank', tags: ['home']),
    Transaction(id: 'tb02', transactionTitle: 'Salary Credit', categoryId: 'savings', amount: 85000, type: TransactionType.income, date: DateTime(2026, 4, 1), account: 'HDFC Bank', tags: ['savings']),
    Transaction(id: 'tb03', transactionTitle: 'Groww SIP', categoryId: 'savings', amount: 10000, type: TransactionType.expense, date: DateTime(2026, 4, 2), account: 'HDFC Bank', tags: ['savings']),
    Transaction(id: 'tb04', transactionTitle: 'ACT Fibernet', categoryId: 'internet', amount: 1180, type: TransactionType.expense, date: DateTime(2026, 4, 3), account: 'HDFC Bank', tags: ['internet']),
    Transaction(id: 'tb05', transactionTitle: 'GitHub Copilot', categoryId: 'work', amount: 850, type: TransactionType.expense, date: DateTime(2026, 4, 4), account: 'ICICI Bank', tags: ['work']),
    Transaction(id: 'tb06', transactionTitle: 'D-Mart', categoryId: 'groceries', amount: 2350, type: TransactionType.expense, date: DateTime(2026, 4, 5), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'tb07', transactionTitle: 'Jio Recharge', categoryId: 'phone', amount: 299, type: TransactionType.expense, date: DateTime(2026, 4, 6), account: 'HDFC Bank', tags: ['phone']),
    Transaction(id: 'tb08', transactionTitle: 'Swiggy', categoryId: 'restaurant', amount: 480, type: TransactionType.expense, date: DateTime(2026, 4, 8), account: 'ICICI Bank', tags: ['restaurant']),
    Transaction(id: 'tb09', transactionTitle: 'BESCOM', categoryId: 'utilities', amount: 1900, type: TransactionType.expense, date: DateTime(2026, 4, 9), account: 'HDFC Bank', tags: ['utilities']),
    Transaction(id: 'tb10', transactionTitle: 'Spotify', categoryId: 'music', amount: 119, type: TransactionType.expense, date: DateTime(2026, 4, 10), account: 'ICICI Bank', tags: ['music']),
    Transaction(id: 'tb11', transactionTitle: 'Apollo Pharmacy', categoryId: 'doctor', amount: 620, type: TransactionType.expense, date: DateTime(2026, 4, 12), account: 'HDFC Bank', tags: ['doctor']),
    Transaction(id: 'tb12', transactionTitle: 'Indian Oil', categoryId: 'transport', amount: 2000, type: TransactionType.expense, date: DateTime(2026, 4, 13), account: 'HDFC Bank', note: 'Full tank', tags: ['transport']),
    Transaction(id: 'tb13', transactionTitle: 'Netflix', categoryId: 'movies', amount: 649, type: TransactionType.expense, date: DateTime(2026, 4, 15), account: 'ICICI Bank', tags: ['movies']),
    Transaction(id: 'tb14', transactionTitle: 'Udemy', categoryId: 'education', amount: 799, type: TransactionType.expense, date: DateTime(2026, 4, 18), account: 'ICICI Bank', note: 'System design course', tags: ['education']),
    Transaction(id: 'tb15', transactionTitle: 'Blinkit', categoryId: 'groceries', amount: 780, type: TransactionType.expense, date: DateTime(2026, 4, 20), account: 'ICICI Bank', tags: ['groceries']),
    Transaction(id: 'tb16', transactionTitle: 'Zomato', categoryId: 'restaurant', amount: 350, type: TransactionType.expense, date: DateTime(2026, 4, 24), account: 'HDFC Bank', tags: ['restaurant']),
    Transaction(id: 'tb17', transactionTitle: 'Amazon', categoryId: 'shopping', amount: 1450, type: TransactionType.expense, date: DateTime(2026, 4, 26), account: 'ICICI Bank', tags: ['shopping']),
    Transaction(id: 'tb18', transactionTitle: 'Uber', categoryId: 'transport', amount: 310, type: TransactionType.expense, date: DateTime(2026, 4, 28), account: 'HDFC Bank', tags: ['transport']),

    // ── January 2026 ────────────────────────────────────────────────────────
    Transaction(id: 'tj01', transactionTitle: 'House Rent', categoryId: 'home', amount: 18000, type: TransactionType.expense, date: DateTime(2026, 1, 1), account: 'HDFC Bank', tags: ['home']),
    Transaction(id: 'tj02', transactionTitle: 'Salary Credit', categoryId: 'savings', amount: 85000, type: TransactionType.income, date: DateTime(2026, 1, 27), account: 'HDFC Bank', tags: ['savings']),
    Transaction(id: 'tj03', transactionTitle: 'D-Mart', categoryId: 'groceries', amount: 1980, type: TransactionType.expense, date: DateTime(2026, 1, 5), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'tj04', transactionTitle: 'Swiggy', categoryId: 'restaurant', amount: 460, type: TransactionType.expense, date: DateTime(2026, 1, 9), account: 'ICICI Bank', tags: ['restaurant']),
    Transaction(id: 'tj05', transactionTitle: 'BESCOM', categoryId: 'utilities', amount: 2100, type: TransactionType.expense, date: DateTime(2026, 1, 12), account: 'HDFC Bank', tags: ['utilities']),
    Transaction(id: 'tj06', transactionTitle: 'Amazon', categoryId: 'shopping', amount: 3100, type: TransactionType.expense, date: DateTime(2026, 1, 14), account: 'ICICI Bank', tags: ['shopping']),
    Transaction(id: 'tj07', transactionTitle: 'Hotstar', categoryId: 'movies', amount: 299, type: TransactionType.expense, date: DateTime(2026, 1, 15), account: 'ICICI Bank', tags: ['movies']),
    Transaction(id: 'tj08', transactionTitle: 'Ola', categoryId: 'transport', amount: 175, type: TransactionType.expense, date: DateTime(2026, 1, 18), account: 'Cash', tags: ['transport']),
    Transaction(id: 'tj09', transactionTitle: 'BigBasket', categoryId: 'groceries', amount: 1400, type: TransactionType.expense, date: DateTime(2026, 1, 22), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'tj10', transactionTitle: 'Zomato', categoryId: 'restaurant', amount: 310, type: TransactionType.expense, date: DateTime(2026, 1, 26), account: 'HDFC Bank', tags: ['restaurant']),

    // ── December 2025 ────────────────────────────────────────────────────────
    Transaction(id: 'td01', transactionTitle: 'House Rent', categoryId: 'home', amount: 18000, type: TransactionType.expense, date: DateTime(2025, 12, 1), account: 'HDFC Bank', tags: ['home']),
    Transaction(id: 'td02', transactionTitle: 'Salary Credit', categoryId: 'savings', amount: 85000, type: TransactionType.income, date: DateTime(2025, 12, 27), account: 'HDFC Bank', tags: ['savings']),
    Transaction(id: 'td03', transactionTitle: 'BigBasket', categoryId: 'groceries', amount: 2450, type: TransactionType.expense, date: DateTime(2025, 12, 4), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'td04', transactionTitle: 'Zomato', categoryId: 'restaurant', amount: 580, type: TransactionType.expense, date: DateTime(2025, 12, 8), account: 'ICICI Bank', tags: ['restaurant']),
    Transaction(id: 'td05', transactionTitle: 'BESCOM', categoryId: 'utilities', amount: 1950, type: TransactionType.expense, date: DateTime(2025, 12, 10), account: 'HDFC Bank', tags: ['utilities']),
    Transaction(id: 'td06', transactionTitle: 'Myntra', categoryId: 'shopping', amount: 4200, type: TransactionType.expense, date: DateTime(2025, 12, 14), account: 'ICICI Bank', tags: ['shopping']),
    Transaction(id: 'td07', transactionTitle: 'Netflix', categoryId: 'movies', amount: 649, type: TransactionType.expense, date: DateTime(2025, 12, 15), account: 'ICICI Bank', tags: ['movies']),
    Transaction(id: 'td08', transactionTitle: 'Uber', categoryId: 'transport', amount: 450, type: TransactionType.expense, date: DateTime(2025, 12, 18), account: 'HDFC Bank', tags: ['transport']),
    Transaction(id: 'td09', transactionTitle: 'Amazon', categoryId: 'shopping', amount: 2800, type: TransactionType.expense, date: DateTime(2025, 12, 22), account: 'ICICI Bank', tags: ['shopping']),
    Transaction(id: 'td10', transactionTitle: 'Swiggy', categoryId: 'restaurant', amount: 420, type: TransactionType.expense, date: DateTime(2025, 12, 28), account: 'HDFC Bank', tags: ['restaurant']),

    // ── November 2025 ────────────────────────────────────────────────────────
    Transaction(id: 'tn01', transactionTitle: 'House Rent', categoryId: 'home', amount: 18000, type: TransactionType.expense, date: DateTime(2025, 11, 1), account: 'HDFC Bank', tags: ['home']),
    Transaction(id: 'tn02', transactionTitle: 'Salary Credit', categoryId: 'savings', amount: 85000, type: TransactionType.income, date: DateTime(2025, 11, 27), account: 'HDFC Bank', tags: ['savings']),
    Transaction(id: 'tn03', transactionTitle: 'D-Mart', categoryId: 'groceries', amount: 1750, type: TransactionType.expense, date: DateTime(2025, 11, 5), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'tn04', transactionTitle: 'Swiggy', categoryId: 'restaurant', amount: 390, type: TransactionType.expense, date: DateTime(2025, 11, 9), account: 'ICICI Bank', tags: ['restaurant']),
    Transaction(id: 'tn05', transactionTitle: 'BESCOM', categoryId: 'utilities', amount: 1680, type: TransactionType.expense, date: DateTime(2025, 11, 11), account: 'HDFC Bank', tags: ['utilities']),
    Transaction(id: 'tn06', transactionTitle: 'Decathlon', categoryId: 'shopping', amount: 2950, type: TransactionType.expense, date: DateTime(2025, 11, 16), account: 'ICICI Bank', tags: ['shopping']),
    Transaction(id: 'tn07', transactionTitle: 'Hotstar', categoryId: 'movies', amount: 299, type: TransactionType.expense, date: DateTime(2025, 11, 17), account: 'ICICI Bank', tags: ['movies']),
    Transaction(id: 'tn08', transactionTitle: 'Rapido', categoryId: 'transport', amount: 130, type: TransactionType.expense, date: DateTime(2025, 11, 20), account: 'Cash', tags: ['transport']),
    Transaction(id: 'tn09', transactionTitle: 'BigBasket', categoryId: 'groceries', amount: 1320, type: TransactionType.expense, date: DateTime(2025, 11, 24), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'tn10', transactionTitle: 'Zomato', categoryId: 'restaurant', amount: 280, type: TransactionType.expense, date: DateTime(2025, 11, 28), account: 'HDFC Bank', tags: ['restaurant']),

    // ── October 2025 ─────────────────────────────────────────────────────────
    Transaction(id: 'to01', transactionTitle: 'House Rent', categoryId: 'home', amount: 18000, type: TransactionType.expense, date: DateTime(2025, 10, 1), account: 'HDFC Bank', tags: ['home']),
    Transaction(id: 'to02', transactionTitle: 'Salary Credit', categoryId: 'savings', amount: 85000, type: TransactionType.income, date: DateTime(2025, 10, 27), account: 'HDFC Bank', tags: ['savings']),
    Transaction(id: 'to03', transactionTitle: 'D-Mart', categoryId: 'groceries', amount: 2100, type: TransactionType.expense, date: DateTime(2025, 10, 4), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'to04', transactionTitle: 'Zomato', categoryId: 'restaurant', amount: 495, type: TransactionType.expense, date: DateTime(2025, 10, 8), account: 'ICICI Bank', tags: ['restaurant']),
    Transaction(id: 'to05', transactionTitle: 'BESCOM', categoryId: 'utilities', amount: 1820, type: TransactionType.expense, date: DateTime(2025, 10, 11), account: 'HDFC Bank', tags: ['utilities']),
    Transaction(id: 'to06', transactionTitle: 'Amazon', categoryId: 'shopping', amount: 3500, type: TransactionType.expense, date: DateTime(2025, 10, 14), account: 'ICICI Bank', tags: ['shopping']),
    Transaction(id: 'to07', transactionTitle: 'Netflix', categoryId: 'movies', amount: 649, type: TransactionType.expense, date: DateTime(2025, 10, 15), account: 'ICICI Bank', tags: ['movies']),
    Transaction(id: 'to08', transactionTitle: 'Ola', categoryId: 'transport', amount: 220, type: TransactionType.expense, date: DateTime(2025, 10, 19), account: 'Cash', tags: ['transport']),
    Transaction(id: 'to09', transactionTitle: 'BigBasket', categoryId: 'groceries', amount: 1600, type: TransactionType.expense, date: DateTime(2025, 10, 23), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'to10', transactionTitle: 'Swiggy', categoryId: 'restaurant', amount: 350, type: TransactionType.expense, date: DateTime(2025, 10, 27), account: 'HDFC Bank', tags: ['restaurant']),

    // ── September 2025 ───────────────────────────────────────────────────────
    Transaction(id: 'ts01', transactionTitle: 'House Rent', categoryId: 'home', amount: 18000, type: TransactionType.expense, date: DateTime(2025, 9, 1), account: 'HDFC Bank', tags: ['home']),
    Transaction(id: 'ts02', transactionTitle: 'Salary Credit', categoryId: 'savings', amount: 85000, type: TransactionType.income, date: DateTime(2025, 9, 27), account: 'HDFC Bank', tags: ['savings']),
    Transaction(id: 'ts03', transactionTitle: 'BigBasket', categoryId: 'groceries', amount: 1900, type: TransactionType.expense, date: DateTime(2025, 9, 5), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'ts04', transactionTitle: 'Swiggy', categoryId: 'restaurant', amount: 420, type: TransactionType.expense, date: DateTime(2025, 9, 9), account: 'ICICI Bank', tags: ['restaurant']),
    Transaction(id: 'ts05', transactionTitle: 'BESCOM', categoryId: 'utilities', amount: 2200, type: TransactionType.expense, date: DateTime(2025, 9, 12), account: 'HDFC Bank', tags: ['utilities']),
    Transaction(id: 'ts06', transactionTitle: 'Myntra', categoryId: 'shopping', amount: 1500, type: TransactionType.expense, date: DateTime(2025, 9, 15), account: 'ICICI Bank', tags: ['shopping']),
    Transaction(id: 'ts07', transactionTitle: 'Hotstar', categoryId: 'movies', amount: 299, type: TransactionType.expense, date: DateTime(2025, 9, 17), account: 'ICICI Bank', tags: ['movies']),
    Transaction(id: 'ts08', transactionTitle: 'Uber', categoryId: 'transport', amount: 280, type: TransactionType.expense, date: DateTime(2025, 9, 21), account: 'HDFC Bank', tags: ['transport']),
    Transaction(id: 'ts09', transactionTitle: 'D-Mart', categoryId: 'groceries', amount: 1250, type: TransactionType.expense, date: DateTime(2025, 9, 25), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'ts10', transactionTitle: 'Zomato', categoryId: 'restaurant', amount: 330, type: TransactionType.expense, date: DateTime(2025, 9, 28), account: 'HDFC Bank', tags: ['restaurant']),

    // ── August 2025 ──────────────────────────────────────────────────────────
    Transaction(id: 'tg01', transactionTitle: 'House Rent', categoryId: 'home', amount: 18000, type: TransactionType.expense, date: DateTime(2025, 8, 1), account: 'HDFC Bank', tags: ['home']),
    Transaction(id: 'tg02', transactionTitle: 'Salary Credit', categoryId: 'savings', amount: 85000, type: TransactionType.income, date: DateTime(2025, 8, 27), account: 'HDFC Bank', tags: ['savings']),
    Transaction(id: 'tg03', transactionTitle: 'D-Mart', categoryId: 'groceries', amount: 2050, type: TransactionType.expense, date: DateTime(2025, 8, 3), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'tg04', transactionTitle: 'Zomato', categoryId: 'restaurant', amount: 510, type: TransactionType.expense, date: DateTime(2025, 8, 7), account: 'ICICI Bank', tags: ['restaurant']),
    Transaction(id: 'tg05', transactionTitle: 'BESCOM', categoryId: 'utilities', amount: 2380, type: TransactionType.expense, date: DateTime(2025, 8, 11), account: 'HDFC Bank', tags: ['utilities']),
    Transaction(id: 'tg06', transactionTitle: 'Amazon', categoryId: 'shopping', amount: 2700, type: TransactionType.expense, date: DateTime(2025, 8, 15), account: 'ICICI Bank', tags: ['shopping']),
    Transaction(id: 'tg07', transactionTitle: 'Netflix', categoryId: 'movies', amount: 649, type: TransactionType.expense, date: DateTime(2025, 8, 16), account: 'ICICI Bank', tags: ['movies']),
    Transaction(id: 'tg08', transactionTitle: 'Rapido', categoryId: 'transport', amount: 160, type: TransactionType.expense, date: DateTime(2025, 8, 20), account: 'Cash', tags: ['transport']),
    Transaction(id: 'tg09', transactionTitle: 'BigBasket', categoryId: 'groceries', amount: 1450, type: TransactionType.expense, date: DateTime(2025, 8, 24), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'tg10', transactionTitle: 'Swiggy', categoryId: 'restaurant', amount: 370, type: TransactionType.expense, date: DateTime(2025, 8, 28), account: 'HDFC Bank', tags: ['restaurant']),

    // ── July 2025 ────────────────────────────────────────────────────────────
    Transaction(id: 'tl01', transactionTitle: 'House Rent', categoryId: 'home', amount: 18000, type: TransactionType.expense, date: DateTime(2025, 7, 1), account: 'HDFC Bank', tags: ['home']),
    Transaction(id: 'tl02', transactionTitle: 'Salary Credit', categoryId: 'savings', amount: 85000, type: TransactionType.income, date: DateTime(2025, 7, 27), account: 'HDFC Bank', tags: ['savings']),
    Transaction(id: 'tl03', transactionTitle: 'BigBasket', categoryId: 'groceries', amount: 1800, type: TransactionType.expense, date: DateTime(2025, 7, 4), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'tl04', transactionTitle: 'Swiggy', categoryId: 'restaurant', amount: 440, type: TransactionType.expense, date: DateTime(2025, 7, 8), account: 'ICICI Bank', tags: ['restaurant']),
    Transaction(id: 'tl05', transactionTitle: 'BESCOM', categoryId: 'utilities', amount: 2050, type: TransactionType.expense, date: DateTime(2025, 7, 12), account: 'HDFC Bank', tags: ['utilities']),
    Transaction(id: 'tl06', transactionTitle: 'Flipkart', categoryId: 'shopping', amount: 1650, type: TransactionType.expense, date: DateTime(2025, 7, 16), account: 'ICICI Bank', tags: ['shopping']),
    Transaction(id: 'tl07', transactionTitle: 'Hotstar', categoryId: 'movies', amount: 299, type: TransactionType.expense, date: DateTime(2025, 7, 18), account: 'ICICI Bank', tags: ['movies']),
    Transaction(id: 'tl08', transactionTitle: 'Ola', categoryId: 'transport', amount: 190, type: TransactionType.expense, date: DateTime(2025, 7, 22), account: 'Cash', tags: ['transport']),
    Transaction(id: 'tl09', transactionTitle: 'D-Mart', categoryId: 'groceries', amount: 1350, type: TransactionType.expense, date: DateTime(2025, 7, 25), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'tl10', transactionTitle: 'Zomato', categoryId: 'restaurant', amount: 295, type: TransactionType.expense, date: DateTime(2025, 7, 29), account: 'HDFC Bank', tags: ['restaurant']),

    // ── June 2025 ────────────────────────────────────────────────────────────
    Transaction(id: 'tu01', transactionTitle: 'House Rent', categoryId: 'home', amount: 18000, type: TransactionType.expense, date: DateTime(2025, 6, 1), account: 'HDFC Bank', tags: ['home']),
    Transaction(id: 'tu02', transactionTitle: 'Salary Credit', categoryId: 'savings', amount: 85000, type: TransactionType.income, date: DateTime(2025, 6, 27), account: 'HDFC Bank', tags: ['savings']),
    Transaction(id: 'tu03', transactionTitle: 'D-Mart', categoryId: 'groceries', amount: 1920, type: TransactionType.expense, date: DateTime(2025, 6, 5), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'tu04', transactionTitle: 'Zomato', categoryId: 'restaurant', amount: 470, type: TransactionType.expense, date: DateTime(2025, 6, 9), account: 'ICICI Bank', tags: ['restaurant']),
    Transaction(id: 'tu05', transactionTitle: 'BESCOM', categoryId: 'utilities', amount: 1600, type: TransactionType.expense, date: DateTime(2025, 6, 12), account: 'HDFC Bank', tags: ['utilities']),
    Transaction(id: 'tu06', transactionTitle: 'Amazon', categoryId: 'shopping', amount: 2200, type: TransactionType.expense, date: DateTime(2025, 6, 15), account: 'ICICI Bank', tags: ['shopping']),
    Transaction(id: 'tu07', transactionTitle: 'Netflix', categoryId: 'movies', amount: 649, type: TransactionType.expense, date: DateTime(2025, 6, 17), account: 'ICICI Bank', tags: ['movies']),
    Transaction(id: 'tu08', transactionTitle: 'Rapido', categoryId: 'transport', amount: 145, type: TransactionType.expense, date: DateTime(2025, 6, 21), account: 'Cash', tags: ['transport']),
    Transaction(id: 'tu09', transactionTitle: 'BigBasket', categoryId: 'groceries', amount: 1280, type: TransactionType.expense, date: DateTime(2025, 6, 25), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'tu10', transactionTitle: 'Swiggy', categoryId: 'restaurant', amount: 310, type: TransactionType.expense, date: DateTime(2025, 6, 28), account: 'HDFC Bank', tags: ['restaurant']),

    // ── May 2025 ─────────────────────────────────────────────────────────────
    Transaction(id: 'tm01', transactionTitle: 'House Rent', categoryId: 'home', amount: 18000, type: TransactionType.expense, date: DateTime(2025, 5, 1), account: 'HDFC Bank', tags: ['home']),
    Transaction(id: 'tm02', transactionTitle: 'Salary Credit', categoryId: 'savings', amount: 85000, type: TransactionType.income, date: DateTime(2025, 5, 27), account: 'HDFC Bank', tags: ['savings']),
    Transaction(id: 'tm03', transactionTitle: 'BigBasket', categoryId: 'groceries', amount: 2300, type: TransactionType.expense, date: DateTime(2025, 5, 4), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'tm04', transactionTitle: 'Swiggy', categoryId: 'restaurant', amount: 395, type: TransactionType.expense, date: DateTime(2025, 5, 8), account: 'ICICI Bank', tags: ['restaurant']),
    Transaction(id: 'tm05', transactionTitle: 'BESCOM', categoryId: 'utilities', amount: 1720, type: TransactionType.expense, date: DateTime(2025, 5, 11), account: 'HDFC Bank', tags: ['utilities']),
    Transaction(id: 'tm06', transactionTitle: 'Myntra', categoryId: 'shopping', amount: 1800, type: TransactionType.expense, date: DateTime(2025, 5, 15), account: 'ICICI Bank', tags: ['shopping']),
    Transaction(id: 'tm07', transactionTitle: 'Hotstar', categoryId: 'movies', amount: 299, type: TransactionType.expense, date: DateTime(2025, 5, 17), account: 'ICICI Bank', tags: ['movies']),
    Transaction(id: 'tm08', transactionTitle: 'Ola', categoryId: 'transport', amount: 200, type: TransactionType.expense, date: DateTime(2025, 5, 21), account: 'Cash', tags: ['transport']),
    Transaction(id: 'tm09', transactionTitle: 'D-Mart', categoryId: 'groceries', amount: 1550, type: TransactionType.expense, date: DateTime(2025, 5, 25), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'tm10', transactionTitle: 'Zomato', categoryId: 'restaurant', amount: 360, type: TransactionType.expense, date: DateTime(2025, 5, 29), account: 'HDFC Bank', tags: ['restaurant']),
  ];

  /// Entries anchored to the device clock: today/yesterday rows plus full
  /// current- and previous-month blocks, so dev mode always has fresh data
  /// even after the fixed calendar above runs out.
  static final List<Transaction> _dynamicDummySource = [
    // Today & yesterday entries for Recent section demo
    Transaction(
      id: 't25',
      transactionTitle: 'Uber Eats',
      categoryId: 'restaurant',
      amount: 340,
      type: TransactionType.expense,
      date: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
      account: 'a2',
      tags: ['restaurant'],
    ),
    Transaction(
      id: 't26',
      transactionTitle: 'Jio Recharge',
      categoryId: 'phone',
      amount: 299,
      type: TransactionType.expense,
      date: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
      account: 'a1',
      tags: ['phone'],
    ),
    Transaction(
      id: 't27',
      transactionTitle: 'Salary Credit',
      categoryId: 'work',
      amount: 85000,
      type: TransactionType.income,
      date: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day - 1),
      account: 'a1',
      tags: ['work'],
    ),
    Transaction(
      id: 't28',
      transactionTitle: 'Amazon Prime',
      categoryId: 'movies',
      amount: 299,
      type: TransactionType.expense,
      date: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day - 1),
      account: 'a2',
      tags: ['movies'],
    ),

    // ── Current month (anchored to device clock) ─────────────────────────────
    Transaction(id: 'ta01', transactionTitle: 'House Rent', categoryId: 'home', amount: 19000, type: TransactionType.expense, date: _dm(0, 1), account: 'HDFC Bank', tags: ['home']),
    Transaction(id: 'ta02', transactionTitle: 'Salary Credit', categoryId: 'savings', amount: 85000, type: TransactionType.income, date: _dm(0, 1), account: 'HDFC Bank', tags: ['savings']),
    Transaction(id: 'ta03', transactionTitle: 'D-Mart', categoryId: 'groceries', amount: 2200, type: TransactionType.expense, date: _dm(0, 5), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'ta04', transactionTitle: 'Zomato', categoryId: 'restaurant', amount: 520, type: TransactionType.expense, date: _dm(0, 7), account: 'ICICI Bank', tags: ['restaurant']),
    Transaction(id: 'ta05', transactionTitle: 'BESCOM', categoryId: 'utilities', amount: 1750, type: TransactionType.expense, date: _dm(0, 8), account: 'HDFC Bank', tags: ['utilities']),
    Transaction(id: 'ta06', transactionTitle: 'Ola', categoryId: 'transport', amount: 210, type: TransactionType.expense, date: _dm(0, 10), account: 'Cash', tags: ['transport']),
    Transaction(id: 'ta07', transactionTitle: 'Flipkart', categoryId: 'shopping', amount: 1890, type: TransactionType.expense, date: _dm(0, 12), account: 'ICICI Bank', tags: ['shopping']),
    Transaction(id: 'ta08', transactionTitle: 'Swiggy', categoryId: 'restaurant', amount: 390, type: TransactionType.expense, date: _dm(0, 14), account: 'HDFC Bank', tags: ['restaurant']),
    Transaction(id: 'ta09', transactionTitle: 'BigBasket', categoryId: 'groceries', amount: 1650, type: TransactionType.expense, date: _dm(0, 16), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'ta10', transactionTitle: 'Netflix', categoryId: 'movies', amount: 649, type: TransactionType.expense, date: _dm(0, 18), account: 'ICICI Bank', tags: ['movies']),
    Transaction(id: 'ta11', transactionTitle: 'Uber', categoryId: 'transport', amount: 340, type: TransactionType.expense, date: _dm(0, 20), account: 'HDFC Bank', tags: ['transport']),
    Transaction(id: 'ta12', transactionTitle: 'Blinkit', categoryId: 'groceries', amount: 720, type: TransactionType.expense, date: _dm(0, 22), account: 'ICICI Bank', tags: ['groceries']),
    Transaction(id: 'ta13', transactionTitle: 'Rapido', categoryId: 'transport', amount: 95, type: TransactionType.expense, date: _dm(0, 24), account: 'Cash', tags: ['transport']),
    Transaction(id: 'ta14', transactionTitle: 'Spotify', categoryId: 'music', amount: 119, type: TransactionType.expense, date: _dm(0, 10), account: 'ICICI Bank', tags: ['music']),

    // ── Previous month (anchored to device clock) ────────────────────────────
    // Repeats Netflix/Spotify/Zomato/Swiggy so recurring-charge detection and
    // month-over-month comparisons have material in dev mode.
    Transaction(id: 'tp01', transactionTitle: 'House Rent', categoryId: 'home', amount: 19000, type: TransactionType.expense, date: _dm(1, 1), account: 'HDFC Bank', tags: ['home']),
    Transaction(id: 'tp02', transactionTitle: 'Salary Credit', categoryId: 'savings', amount: 85000, type: TransactionType.income, date: _dm(1, 1), account: 'HDFC Bank', tags: ['savings']),
    Transaction(id: 'tp03', transactionTitle: 'D-Mart', categoryId: 'groceries', amount: 2050, type: TransactionType.expense, date: _dm(1, 5), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'tp04', transactionTitle: 'BESCOM', categoryId: 'utilities', amount: 1690, type: TransactionType.expense, date: _dm(1, 8), account: 'HDFC Bank', tags: ['utilities']),
    Transaction(id: 'tp05', transactionTitle: 'Spotify', categoryId: 'music', amount: 119, type: TransactionType.expense, date: _dm(1, 10), account: 'ICICI Bank', tags: ['music']),
    Transaction(id: 'tp06', transactionTitle: 'Ola', categoryId: 'transport', amount: 260, type: TransactionType.expense, date: _dm(1, 12), account: 'Cash', tags: ['transport']),
    Transaction(id: 'tp07', transactionTitle: 'Netflix', categoryId: 'movies', amount: 649, type: TransactionType.expense, date: _dm(1, 18), account: 'ICICI Bank', tags: ['movies']),
    Transaction(id: 'tp08', transactionTitle: 'Swiggy', categoryId: 'restaurant', amount: 310, type: TransactionType.expense, date: _dm(1, 20), account: 'HDFC Bank', tags: ['restaurant']),
    Transaction(id: 'tp09', transactionTitle: 'Blinkit', categoryId: 'groceries', amount: 830, type: TransactionType.expense, date: _dm(1, 24), account: 'ICICI Bank', tags: ['groceries']),
    Transaction(id: 'tp10', transactionTitle: 'Amazon Prime', categoryId: 'movies', amount: 299, type: TransactionType.expense, date: _dm(1, 26), account: 'ICICI Bank', tags: ['movies']),
  ];
}

enum AccountType { bank, cash, credit }

class CardEntry {
  final String type;
  final String last4;
  final String network;
  final double? creditLimit;

  const CardEntry({
    required this.type,
    required this.last4,
    required this.network,
    this.creditLimit,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'last4': last4,
    'network': network,
    if (creditLimit != null) 'creditLimit': creditLimit,
  };

  factory CardEntry.fromJson(Map<String, dynamic> json) => CardEntry(
    type: json['type'] as String,
    last4: json['last4'] as String,
    network: json['network'] as String,
    creditLimit: (json['creditLimit'] as num?)?.toDouble(),
  );
}

class Account {
  final String id;
  final AccountType type;
  final double balance;
  final String? bank;
  final String? bankLogoPath;
  final String? cardIdentifier;
  final List<double> sparkline;
  final List<CardEntry> cards;
  final String baseCurrency;

  const Account({
    required this.id,
    required this.type,
    required this.balance,
    this.bank,
    this.bankLogoPath,
    this.cardIdentifier,
    required this.sparkline,
    this.cards = const [],
    this.baseCurrency = 'USD',
  });

  String get displayName => bank ?? (type == AccountType.cash ? 'Cash' : 'Account');

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'balance': balance,
    if (bank != null) 'bank': bank,
    if (bankLogoPath != null) 'bankLogoPath': bankLogoPath,
    if (cardIdentifier != null) 'cardIdentifier': cardIdentifier,
    'sparkline': sparkline,
    if (cards.isNotEmpty) 'cards': cards.map((c) => c.toJson()).toList(),
    'baseCurrency': baseCurrency,
  };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as String,
    type: AccountType.values.firstWhere((e) => e.name == json['type']),
    balance: (json['balance'] as num).toDouble(),
    bank: json['bank'] as String?,
    bankLogoPath: json['bankLogoPath'] as String?,
    cardIdentifier: json['cardIdentifier'] as String?,
    sparkline: (json['sparkline'] as List).cast<num>().map((e) => e.toDouble()).toList(),
    cards: (json['cards'] as List?)?.map((e) => CardEntry.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    baseCurrency: json['baseCurrency'] as String? ?? 'USD',
  );

  static const List<Account> dummyData = [
    Account(
      id: 'a1',
      type: AccountType.bank,
      balance: 42350,
      bank: 'HDFC Bank',
      bankLogoPath: 'assets/icons/banks/HDFC Bank.svg',
      sparkline: [38000, 55200, 42000, 48000, 36200, 42350],
      cards: [
        CardEntry(type: 'debit', last4: '4242', network: 'Visa'),
      ],
    ),
    Account(
      id: 'a2',
      type: AccountType.credit,
      balance: -8247,
      bank: 'ICICI Bank',
      bankLogoPath: 'assets/icons/banks/ICICI Bank.svg',
      cardIdentifier: '5071',
      sparkline: [-3000, -5500, -6800, -4200, -7900, -8247],
    ),
    Account(
      id: 'a4',
      type: AccountType.bank,
      balance: 18640,
      bank: 'State Bank of India',
      bankLogoPath: 'assets/icons/banks/State Bank of India.svg',
      sparkline: [15000, 17200, 16800, 19400, 17900, 18640],
    ),
    Account(
      id: 'a5',
      type: AccountType.bank,
      balance: 9820,
      bank: 'Axis Bank',
      bankLogoPath: 'assets/icons/banks/Axis bank.svg',
      sparkline: [8000, 11200, 9500, 10800, 9200, 9820],
    ),
    Account(
      id: 'a6',
      type: AccountType.bank,
      balance: 27300,
      bank: 'Kotak Mahindra Bank',
      bankLogoPath: 'assets/icons/banks/Kotak Mahindra Bank.svg',
      sparkline: [22000, 25600, 28100, 24300, 26800, 27300],
    ),
    Account(
      id: 'a7',
      type: AccountType.bank,
      balance: 5450,
      bank: 'Canara Bank',
      bankLogoPath: 'assets/icons/banks/Canara Bank.svg',
      sparkline: [4000, 5100, 4700, 6200, 5800, 5450],
    ),
    Account(
      id: 'a8',
      type: AccountType.bank,
      balance: 11200,
      bank: 'Punjab National Bank',
      bankLogoPath: 'assets/icons/banks/Punjab National Bank.svg',
      sparkline: [9000, 10400, 11800, 10200, 12100, 11200],
    ),
    Account(
      id: 'a3',
      type: AccountType.cash,
      balance: 3200,
      bankLogoPath: null,
      sparkline: [5000, 3500, 4200, 2800, 3800, 3200],
    ),
  ];
}

enum BudgetPeriod { monthly, weekly }

class Budget {
  final String categoryId;
  final double amount;
  final BudgetPeriod period;

  const Budget({
    required this.categoryId,
    required this.amount,
    required this.period,
  });

  Map<String, dynamic> toJson() => {
    'categoryId': categoryId,
    'amount': amount,
    'period': period.name,
  };

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
    categoryId: json['categoryId'] as String,
    amount: (json['amount'] as num).toDouble(),
    // orElse fallback: new field — existing persisted docs may lack 'period'
    period: BudgetPeriod.values.firstWhere(
      (p) => p.name == json['period'],
      orElse: () => BudgetPeriod.monthly,
    ),
  );

  static const List<Budget> budgets = [
    Budget(categoryId: 'restaurant', amount: 3000, period: BudgetPeriod.monthly),
    Budget(categoryId: 'groceries',  amount: 5000, period: BudgetPeriod.monthly),
    Budget(categoryId: 'transport',  amount: 2000, period: BudgetPeriod.monthly),
    Budget(categoryId: 'movies',     amount: 2000, period: BudgetPeriod.monthly),
    Budget(categoryId: 'shopping',   amount: 5000, period: BudgetPeriod.monthly),
    Budget(categoryId: 'utilities',  amount: 2500, period: BudgetPeriod.monthly),
  ];
}

class MonthlyData {
  final String month;
  final double amount;

  const MonthlyData({required this.month, required this.amount});

  static const List<MonthlyData> monthlyData = [
    MonthlyData(month: 'Oct', amount: 22400),
    MonthlyData(month: 'Nov', amount: 28650),
    MonthlyData(month: 'Dec', amount: 38200),
    MonthlyData(month: 'Jan', amount: 24100),
    MonthlyData(month: 'Feb', amount: 26800),
    MonthlyData(month: 'Mar', amount: 28452),
  ];
}
