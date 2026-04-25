import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

enum TransactionType { expense, income }

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
    IconData? lucideIcon;
    if (json['iconCodePoint'] != null) {
      lucideIcon = IconData(
        json['iconCodePoint'] as int,
        fontFamily: json['iconFontFamily'] as String?,
        fontPackage: json['iconFontPackage'] as String?,
      );
    }
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
    tags: (json['tags'] as List).cast<String>(),
    note: json['note'] as String?,
  );

  static List<Transaction> dummyData = [
    Transaction(
      id: 't1',
      transactionTitle: 'Big Bazaar',
      categoryId: 'groceries',
      amount: 1240,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 28),
      account: 'HDFC Savings',
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
      account: 'HDFC Savings',
      tags: ['doctor'],
    ),
    Transaction(
      id: 't3',
      transactionTitle: 'Blue Tokai',
      categoryId: 'restaurant',
      amount: 220,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 28),
      account: 'Cash',
      tags: ['restaurant'],
    ),
    Transaction(
      id: 't4',
      transactionTitle: 'Salary Credit',
      categoryId: 'savings',
      amount: 85000,
      type: TransactionType.income,
      date: DateTime(2026, 3, 27),
      account: 'HDFC Savings',
      tags: ['savings'],
    ),
    Transaction(
      id: 't5',
      transactionTitle: 'Swiggy',
      categoryId: 'restaurant',
      amount: 450,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 27),
      account: 'ICICI Credit Card',
      tags: ['restaurant'],
    ),
    Transaction(
      id: 't6',
      transactionTitle: 'Ola',
      categoryId: 'transport',
      amount: 180,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 26),
      account: 'HDFC Savings',
      tags: ['transport'],
    ),
    Transaction(
      id: 't7',
      transactionTitle: 'Netflix',
      categoryId: 'movies',
      amount: 649,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 26),
      account: 'ICICI Credit Card',
      tags: ['movies'],
    ),
    Transaction(
      id: 't8',
      transactionTitle: 'Zomato',
      categoryId: 'restaurant',
      amount: 349,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 25),
      account: 'HDFC Savings',
      tags: ['restaurant'],
    ),
    Transaction(
      id: 't9',
      transactionTitle: 'BESCOM',
      categoryId: 'utilities',
      amount: 1850,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 25),
      account: 'HDFC Savings',
      tags: ['utilities'],
    ),
    Transaction(
      id: 't10',
      transactionTitle: 'Amazon',
      categoryId: 'shopping',
      amount: 2399,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 24),
      account: 'ICICI Credit Card',
      tags: ['shopping'],
    ),
    Transaction(
      id: 't11',
      transactionTitle: 'Decathlon',
      categoryId: 'shopping',
      amount: 3200,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 24),
      account: 'ICICI Credit Card',
      tags: ['shopping'],
    ),
    Transaction(
      id: 't12',
      transactionTitle: 'BMTC Bus',
      categoryId: 'transport',
      amount: 35,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 23),
      account: 'Cash',
      tags: ['transport'],
    ),
    Transaction(
      id: 't13',
      transactionTitle: 'Inox Movies',
      categoryId: 'movies',
      amount: 380,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 22),
      account: 'ICICI Credit Card',
      tags: ['movies'],
    ),
    Transaction(
      id: 't14',
      transactionTitle: 'D-Mart',
      categoryId: 'groceries',
      amount: 2100,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 20),
      account: 'HDFC Savings',
      tags: ['groceries'],
    ),
    Transaction(
      id: 't15',
      transactionTitle: 'Myntra',
      categoryId: 'shopping',
      amount: 1899,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 18),
      account: 'ICICI Credit Card',
      tags: ['shopping'],
    ),
    Transaction(
      id: 't16',
      transactionTitle: 'Rapido',
      categoryId: 'transport',
      amount: 90,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 19),
      account: 'Cash',
      tags: ['transport'],
    ),
    Transaction(
      id: 't17',
      transactionTitle: 'Blinkit',
      categoryId: 'groceries',
      amount: 650,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 17),
      account: 'ICICI Credit Card',
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
      account: 'ICICI Credit Card',
      tags: ['movies'],
    ),
    Transaction(
      id: 't19',
      transactionTitle: 'Freelance Project',
      categoryId: 'savings',
      amount: 25000,
      type: TransactionType.income,
      date: DateTime(2026, 3, 15),
      account: 'HDFC Savings',
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
      account: 'HDFC Savings',
      tags: ['home'],
    ),
    Transaction(
      id: 't21',
      transactionTitle: 'Salary Credit',
      categoryId: 'savings',
      amount: 85000,
      type: TransactionType.income,
      date: DateTime(2026, 2, 27),
      account: 'HDFC Savings',
      tags: ['savings'],
    ),
    Transaction(
      id: 't22',
      transactionTitle: 'Swiggy',
      categoryId: 'restaurant',
      amount: 380,
      type: TransactionType.expense,
      date: DateTime(2026, 2, 25),
      account: 'HDFC Savings',
      tags: ['restaurant'],
    ),
    Transaction(
      id: 't23',
      transactionTitle: 'BigBasket',
      categoryId: 'groceries',
      amount: 1890,
      type: TransactionType.expense,
      date: DateTime(2026, 2, 20),
      account: 'HDFC Savings',
      tags: ['groceries'],
    ),
    Transaction(
      id: 't24',
      transactionTitle: 'Uber',
      categoryId: 'transport',
      amount: 420,
      type: TransactionType.expense,
      date: DateTime(2026, 2, 18),
      account: 'ICICI Credit Card',
      tags: ['transport'],
    ),
    // Today & yesterday entries for Recent section demo
    Transaction(
      id: 't25',
      transactionTitle: 'Uber Eats',
      categoryId: 'restaurant',
      amount: 340,
      type: TransactionType.expense,
      date: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
      account: 'ICICI Credit Card',
      tags: ['restaurant'],
    ),
    Transaction(
      id: 't26',
      transactionTitle: 'Jio Recharge',
      categoryId: 'phone',
      amount: 299,
      type: TransactionType.expense,
      date: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
      account: 'HDFC Savings',
      tags: ['phone'],
    ),
    Transaction(
      id: 't27',
      transactionTitle: 'Salary Credit',
      categoryId: 'work',
      amount: 95000,
      type: TransactionType.income,
      date: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day - 1),
      account: 'HDFC Savings',
      tags: ['work'],
    ),
    Transaction(
      id: 't28',
      transactionTitle: 'Amazon Prime',
      categoryId: 'movies',
      amount: 299,
      type: TransactionType.expense,
      date: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day - 1),
      account: 'ICICI Credit Card',
      tags: ['movies'],
    ),
  ];
}

enum AccountType { bank, cash, credit }

class Account {
  final String id;
  final String name;
  final AccountType type;
  final double balance;
  final String? bank;
  final String? bankLogoPath;
  final String? cardIdentifier;
  final List<double> sparkline;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.bank,
    this.bankLogoPath,
    this.cardIdentifier,
    required this.sparkline,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'balance': balance,
    if (bank != null) 'bank': bank,
    if (bankLogoPath != null) 'bankLogoPath': bankLogoPath,
    if (cardIdentifier != null) 'cardIdentifier': cardIdentifier,
    'sparkline': sparkline,
  };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as String,
    name: json['name'] as String,
    type: AccountType.values.firstWhere((e) => e.name == json['type']),
    balance: (json['balance'] as num).toDouble(),
    bank: json['bank'] as String?,
    bankLogoPath: json['bankLogoPath'] as String?,
    cardIdentifier: json['cardIdentifier'] as String?,
    sparkline: (json['sparkline'] as List).cast<num>().map((e) => e.toDouble()).toList(),
  );

  static const List<Account> dummyData = [
    Account(
      id: 'a1',
      name: 'HDFC Savings',
      type: AccountType.bank,
      balance: 42350,
      bank: 'HDFC Bank',
      bankLogoPath: 'assets/icons/banks/hdfc.svg',
      sparkline: [38000, 55200, 42000, 48000, 36200, 42350],
    ),
    Account(
      id: 'a2',
      name: 'ICICI Credit Card',
      type: AccountType.credit,
      balance: -8247,
      bank: 'ICICI Bank',
      bankLogoPath: 'assets/icons/banks/icici.svg',
      cardIdentifier: '5071',
      sparkline: [-3000, -5500, -6800, -4200, -7900, -8247],
    ),
    Account(
      id: 'a4',
      name: 'SBI Savings',
      type: AccountType.bank,
      balance: 18640,
      bank: 'State Bank of India',
      bankLogoPath: 'assets/icons/banks/sbi.svg',
      sparkline: [15000, 17200, 16800, 19400, 17900, 18640],
    ),
    Account(
      id: 'a5',
      name: 'Axis Bank',
      type: AccountType.bank,
      balance: 9820,
      bank: 'Axis Bank',
      bankLogoPath: 'assets/icons/banks/axis.svg',
      sparkline: [8000, 11200, 9500, 10800, 9200, 9820],
    ),
    Account(
      id: 'a6',
      name: 'Kotak Savings',
      type: AccountType.bank,
      balance: 27300,
      bank: 'Kotak Mahindra Bank',
      bankLogoPath: 'assets/icons/banks/kotak.svg',
      sparkline: [22000, 25600, 28100, 24300, 26800, 27300],
    ),
    Account(
      id: 'a7',
      name: 'Canara Bank',
      type: AccountType.bank,
      balance: 5450,
      bank: 'Canara Bank',
      bankLogoPath: 'assets/icons/banks/canara.svg',
      sparkline: [4000, 5100, 4700, 6200, 5800, 5450],
    ),
    Account(
      id: 'a8',
      name: 'PNB Account',
      type: AccountType.bank,
      balance: 11200,
      bank: 'Punjab National Bank',
      bankLogoPath: 'assets/icons/banks/pnb.svg',
      sparkline: [9000, 10400, 11800, 10200, 12100, 11200],
    ),
    Account(
      id: 'a3',
      name: 'Cash',
      type: AccountType.cash,
      balance: 3200,
      bankLogoPath: null,
      sparkline: [5000, 3500, 4200, 2800, 3800, 3200],
    ),
  ];
}

class Budget {
  final String categoryId;
  final double budget;

  const Budget({required this.categoryId, required this.budget});

  static const List<Budget> budgets = [
    Budget(categoryId: 'restaurant', budget: 3000),
    Budget(categoryId: 'groceries', budget: 5000),
    Budget(categoryId: 'transport', budget: 2000),
    Budget(categoryId: 'movies', budget: 2000),
    Budget(categoryId: 'shopping', budget: 5000),
    Budget(categoryId: 'utilities', budget: 2500),
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

class SmsParsed {
  final String id;
  final String bank;
  final String transactionTitle;
  final double amount;
  final String date;
  final String categoryId;

  const SmsParsed({
    required this.id,
    required this.bank,
    required this.transactionTitle,
    required this.amount,
    required this.date,
    required this.categoryId,
  });

  static const List<SmsParsed> smsParsed = [
    SmsParsed(
      id: 's1',
      bank: 'HDFC Bank',
      transactionTitle: 'Zomato',
      amount: 349,
      date: '2 mins ago',
      categoryId: 'restaurant',
    ),
    SmsParsed(
      id: 's2',
      bank: 'ICICI Bank',
      transactionTitle: 'Uber',
      amount: 234,
      date: '1 hour ago',
      categoryId: 'transport',
    ),
    SmsParsed(
      id: 's3',
      bank: 'HDFC Bank',
      transactionTitle: 'Swiggy Instamart',
      amount: 892,
      date: 'Yesterday',
      categoryId: 'groceries',
    ),
  ];
}
