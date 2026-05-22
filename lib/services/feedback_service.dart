import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:in_app_review/in_app_review.dart';

class FeedbackService {
  static Future<void> submitFeedback({
    required String message,
    required String trigger,
    required String userId,
    String appVersion = '1.0.0',
  }) async {
    await FirebaseFirestore.instance.collection('feedback').add({
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
