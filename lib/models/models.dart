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
    tags: ((json['tags'] as List?) ?? []).cast<String>(),
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
      account: 'HDFC Bank',
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
      account: 'HDFC Bank',
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
      account: 'HDFC Bank',
      tags: ['savings'],
    ),
    Transaction(
      id: 't5',
      transactionTitle: 'Swiggy',
      categoryId: 'restaurant',
      amount: 450,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 27),
      account: 'ICICI Bank',
      tags: ['restaurant'],
    ),
    Transaction(
      id: 't6',
      transactionTitle: 'Ola',
      categoryId: 'transport',
      amount: 180,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 26),
      account: 'HDFC Bank',
      tags: ['transport'],
    ),
    Transaction(
      id: 't7',
      transactionTitle: 'Netflix',
      categoryId: 'movies',
      amount: 649,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 26),
      account: 'ICICI Bank',
      tags: ['movies'],
    ),
    Transaction(
      id: 't8',
      transactionTitle: 'Zomato',
      categoryId: 'restaurant',
      amount: 349,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 25),
      account: 'HDFC Bank',
      tags: ['restaurant'],
    ),
    Transaction(
      id: 't9',
      transactionTitle: 'BESCOM',
      categoryId: 'utilities',
      amount: 1850,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 25),
      account: 'HDFC Bank',
      tags: ['utilities'],
    ),
    Transaction(
      id: 't10',
      transactionTitle: 'Amazon',
      categoryId: 'shopping',
      amount: 2399,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 24),
      account: 'ICICI Bank',
      tags: ['shopping'],
    ),
    Transaction(
      id: 't11',
      transactionTitle: 'Decathlon',
      categoryId: 'shopping',
      amount: 3200,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 24),
      account: 'ICICI Bank',
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
      account: 'ICICI Bank',
      tags: ['movies'],
    ),
    Transaction(
      id: 't14',
      transactionTitle: 'D-Mart',
      categoryId: 'groceries',
      amount: 2100,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 20),
      account: 'HDFC Bank',
      tags: ['groceries'],
    ),
    Transaction(
      id: 't15',
      transactionTitle: 'Myntra',
      categoryId: 'shopping',
      amount: 1899,
      type: TransactionType.expense,
      date: DateTime(2026, 3, 18),
      account: 'ICICI Bank',
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
      account: 'ICICI Bank',
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
      account: 'ICICI Bank',
      tags: ['movies'],
    ),
    Transaction(
      id: 't19',
      transactionTitle: 'Freelance Project',
      categoryId: 'savings',
      amount: 25000,
      type: TransactionType.income,
      date: DateTime(2026, 3, 15),
      account: 'HDFC Bank',
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
      account: 'HDFC Bank',
      tags: ['home'],
    ),
    Transaction(
      id: 't21',
      transactionTitle: 'Salary Credit',
      categoryId: 'savings',
      amount: 85000,
      type: TransactionType.income,
      date: DateTime(2026, 2, 27),
      account: 'HDFC Bank',
      tags: ['savings'],
    ),
    Transaction(
      id: 't22',
      transactionTitle: 'Swiggy',
      categoryId: 'restaurant',
      amount: 380,
      type: TransactionType.expense,
      date: DateTime(2026, 2, 25),
      account: 'HDFC Bank',
      tags: ['restaurant'],
    ),
    Transaction(
      id: 't23',
      transactionTitle: 'BigBasket',
      categoryId: 'groceries',
      amount: 1890,
      type: TransactionType.expense,
      date: DateTime(2026, 2, 20),
      account: 'HDFC Bank',
      tags: ['groceries'],
    ),
    Transaction(
      id: 't24',
      transactionTitle: 'Uber',
      categoryId: 'transport',
      amount: 420,
      type: TransactionType.expense,
      date: DateTime(2026, 2, 18),
      account: 'ICICI Bank',
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
      account: 'ICICI Bank',
      tags: ['restaurant'],
    ),
    Transaction(
      id: 't26',
      transactionTitle: 'Jio Recharge',
      categoryId: 'phone',
      amount: 299,
      type: TransactionType.expense,
      date: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
      account: 'HDFC Bank',
      tags: ['phone'],
    ),
    Transaction(
      id: 't27',
      transactionTitle: 'Salary Credit',
      categoryId: 'work',
      amount: 95000,
      type: TransactionType.income,
      date: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day - 1),
      account: 'HDFC Bank',
      tags: ['work'],
    ),
    Transaction(
      id: 't28',
      transactionTitle: 'Amazon Prime',
      categoryId: 'movies',
      amount: 299,
      type: TransactionType.expense,
      date: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day - 1),
      account: 'ICICI Bank',
      tags: ['movies'],
    ),

    // ── April 2026 (current month) ──────────────────────────────────────────
    Transaction(id: 'ta01', transactionTitle: 'House Rent', categoryId: 'home', amount: 19000, type: TransactionType.expense, date: DateTime(2026, 4, 1), account: 'HDFC Bank', tags: ['home']),
    Transaction(id: 'ta02', transactionTitle: 'Salary Credit', categoryId: 'savings', amount: 90000, type: TransactionType.income, date: DateTime(2026, 4, 1), account: 'HDFC Bank', tags: ['savings']),
    Transaction(id: 'ta03', transactionTitle: 'D-Mart', categoryId: 'groceries', amount: 2200, type: TransactionType.expense, date: DateTime(2026, 4, 5), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'ta04', transactionTitle: 'Zomato', categoryId: 'restaurant', amount: 520, type: TransactionType.expense, date: DateTime(2026, 4, 7), account: 'ICICI Bank', tags: ['restaurant']),
    Transaction(id: 'ta05', transactionTitle: 'BESCOM', categoryId: 'utilities', amount: 1750, type: TransactionType.expense, date: DateTime(2026, 4, 8), account: 'HDFC Bank', tags: ['utilities']),
    Transaction(id: 'ta06', transactionTitle: 'Ola', categoryId: 'transport', amount: 210, type: TransactionType.expense, date: DateTime(2026, 4, 10), account: 'Cash', tags: ['transport']),
    Transaction(id: 'ta07', transactionTitle: 'Flipkart', categoryId: 'shopping', amount: 1890, type: TransactionType.expense, date: DateTime(2026, 4, 12), account: 'ICICI Bank', tags: ['shopping']),
    Transaction(id: 'ta08', transactionTitle: 'Swiggy', categoryId: 'restaurant', amount: 390, type: TransactionType.expense, date: DateTime(2026, 4, 14), account: 'HDFC Bank', tags: ['restaurant']),
    Transaction(id: 'ta09', transactionTitle: 'BigBasket', categoryId: 'groceries', amount: 1650, type: TransactionType.expense, date: DateTime(2026, 4, 16), account: 'HDFC Bank', tags: ['groceries']),
    Transaction(id: 'ta10', transactionTitle: 'Netflix', categoryId: 'movies', amount: 649, type: TransactionType.expense, date: DateTime(2026, 4, 18), account: 'ICICI Bank', tags: ['movies']),
    Transaction(id: 'ta11', transactionTitle: 'Uber', categoryId: 'transport', amount: 340, type: TransactionType.expense, date: DateTime(2026, 4, 20), account: 'HDFC Bank', tags: ['transport']),
    Transaction(id: 'ta12', transactionTitle: 'Blinkit', categoryId: 'groceries', amount: 720, type: TransactionType.expense, date: DateTime(2026, 4, 22), account: 'ICICI Bank', tags: ['groceries']),
    Transaction(id: 'ta13', transactionTitle: 'Rapido', categoryId: 'transport', amount: 95, type: TransactionType.expense, date: DateTime(2026, 4, 24), account: 'Cash', tags: ['transport']),

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

  const Account({
    required this.id,
    required this.type,
    required this.balance,
    this.bank,
    this.bankLogoPath,
    this.cardIdentifier,
    required this.sparkline,
    this.cards = const [],
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
  );

  static const List<Account> dummyData = [
    Account(
      id: 'a1',
      type: AccountType.bank,
      balance: 42350,
      bank: 'HDFC Bank',
      bankLogoPath: 'assets/icons/banks/hdfc.svg',
      sparkline: [38000, 55200, 42000, 48000, 36200, 42350],
    ),
    Account(
      id: 'a2',
      type: AccountType.credit,
      balance: -8247,
      bank: 'ICICI Bank',
      bankLogoPath: 'assets/icons/banks/icici.svg',
      cardIdentifier: '5071',
      sparkline: [-3000, -5500, -6800, -4200, -7900, -8247],
    ),
    Account(
      id: 'a4',
      type: AccountType.bank,
      balance: 18640,
      bank: 'State Bank of India',
      bankLogoPath: 'assets/icons/banks/sbi.svg',
      sparkline: [15000, 17200, 16800, 19400, 17900, 18640],
    ),
    Account(
      id: 'a5',
      type: AccountType.bank,
      balance: 9820,
      bank: 'Axis Bank',
      bankLogoPath: 'assets/icons/banks/axis.svg',
      sparkline: [8000, 11200, 9500, 10800, 9200, 9820],
    ),
    Account(
      id: 'a6',
      type: AccountType.bank,
      balance: 27300,
      bank: 'Kotak Mahindra Bank',
      bankLogoPath: 'assets/icons/banks/kotak.svg',
      sparkline: [22000, 25600, 28100, 24300, 26800, 27300],
    ),
    Account(
      id: 'a7',
      type: AccountType.bank,
      balance: 5450,
      bank: 'Canara Bank',
      bankLogoPath: 'assets/icons/banks/canara.svg',
      sparkline: [4000, 5100, 4700, 6200, 5800, 5450],
    ),
    Account(
      id: 'a8',
      type: AccountType.bank,
      balance: 11200,
      bank: 'Punjab National Bank',
      bankLogoPath: 'assets/icons/banks/pnb.svg',
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
