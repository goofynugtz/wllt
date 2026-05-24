import 'package:hive_flutter/hive_flutter.dart';

class FeedbackStore {
  static const _boxName = 'ai_feedback';

  late Box<String> _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  /// Returns user-corrected category for [merchant], or null if no correction exists.
  String? lookup(String merchant) {
    return _box.get(_key(merchant));
  }

  /// Records that user chose [userChose] when AI suggested [aiSuggested] for [merchant].
  Future<void> recordCorrection({
    required String merchant,
    required String aiSuggested,
    required String userChose,
  }) async {
    await _box.put(_key(merchant), userChose);
  }

  String _key(String merchant) => merchant.toLowerCase().trim();
}
