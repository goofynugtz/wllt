import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserService {
  static String get _collection {
    if (kDebugMode) return 'users_dev';
    if (kProfileMode) return 'users_staging';
    return 'users';
  }

  static Future<bool> _ensureAuth() async {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }
      return auth.currentUser != null;
    } catch (e) {
      debugPrint('[UserService] Anonymous auth failed: $e');
      return false;
    }
  }

  static Future<void> upsertUser({
    required String authMode,
    String? email,
    String? displayName,
    String appVersion = '1.0.0',
  }) async {
    final authed = await _ensureAuth();
    if (!authed) {
      debugPrint('[UserService] Skipping upsert — auth unavailable');
      return;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final docRef = FirebaseFirestore.instance.collection(_collection).doc(uid);

    await docRef.set(
      {
        'authMode': authMode,
        'email': email,
        'displayName': displayName,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'appVersion': appVersion,
        'lastSeen': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // firstSeen only written if doc is new (merge won't overwrite existing field)
    final snap = await docRef.get();
    if (snap.data()?['firstSeen'] == null) {
      await docRef.update({'firstSeen': FieldValue.serverTimestamp()});
    }

    debugPrint('[UserService:$_collection] Upserted uid=$uid authMode=$authMode');
  }
}
