import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_review/in_app_review.dart';

class FeedbackService {
  static Future<void> _ensureAuth() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
  }

  static Future<void> submitFeedback({
    required String sentiment,
    required String trigger,
    required String userId,
    String? message,
    String appVersion = '1.0.0',
  }) async {
    await _ensureAuth();
    // TEMP: remove this throw after confirming error path works
    // throw Exception('force-fail test');
    await FirebaseFirestore.instance.collection('feedback').add({
      'sentiment': sentiment,
      'message': message,
      'userId': userId,
      'trigger': trigger,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'appVersion': appVersion,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> requestReview() async {
    final review = InAppReview.instance;
    if (await review.isAvailable()) {
      await review.requestReview();
    }
  }
}
