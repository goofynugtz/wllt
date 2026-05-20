import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class DiagnosticsLogger {
  DiagnosticsLogger._();
  static final instance = DiagnosticsLogger._();

  /// `diagnostics_dev`     — flutter run (debug)
  /// `diagnostics_staging` — flutter run --profile
  /// `diagnostics`         — flutter run --release / production
  String get _collection {
    if (kDebugMode) return 'diagnostics_dev';
    if (kProfileMode) return 'diagnostics_staging';
    return 'diagnostics';
  }

  Future<bool> _ensureAuth() async {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }
      return auth.currentUser != null;
    } catch (e) {
      debugPrint('[Diagnostics] Anonymous auth failed: $e');
      return false;
    }
  }

  void logExchangeRateFailure({
    required String currency,
    required String date,
    required List<String> attempts,
  }) {
    debugPrint(
      '[Diagnostics:$_collection] Exchange rate failure — currency=$currency date=$date\n'
      '${attempts.map((a) => '  $a').join('\n')}',
    );

    _ensureAuth().then((authed) {
      if (!authed) return;
      FirebaseFirestore.instance
          .collection(_collection)
          .doc('exchange_rate')
          .collection('failures')
          .add({
            'type': 'exchange_rate_failure',
            'currency': currency,
            'date': date,
            'attempts': attempts,
            'platform': Platform.operatingSystem,
            'timestamp': FieldValue.serverTimestamp(),
          })
          .catchError((Object e) {
            debugPrint('[Diagnostics] Firestore write failed: $e');
          });
    });
  }
}
