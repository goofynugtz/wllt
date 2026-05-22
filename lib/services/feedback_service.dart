import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

class FeedbackService {
  static String get _collection {
    if (kDebugMode) return 'feedback_dev';
    if (kProfileMode) return 'feedback_staging';
    return 'feedback';
  }

  static Future<bool> _ensureAuth() async {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }
      return auth.currentUser != null;
    } catch (e) {
      debugPrint('[Feedback] Anonymous auth failed: $e');
      return false;
    }
  }

  static Future<void> submitFeedback({
    required String sentiment,
    required String trigger,
    required String userId,
    String? message,
    String appVersion = '1.0.0',
  }) async {
    final authed = await _ensureAuth();
    if (!authed) {
      debugPrint('[Feedback] Skipping write — auth unavailable');
      return;
    }
    await FirebaseFirestore.instance.collection(_collection).add({
      'sentiment': sentiment,
      'message': message,
      'userId': userId,
      'trigger': trigger,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'appVersion': appVersion,
      'createdAt': FieldValue.serverTimestamp(),
    });
    debugPrint('[Feedback:$_collection] Written — sentiment=$sentiment trigger=$trigger');
  }

  static Future<void> requestReview() async {
    final review = InAppReview.instance;
    if (await review.isAvailable()) {
      await review.requestReview();
    }
  }
}
