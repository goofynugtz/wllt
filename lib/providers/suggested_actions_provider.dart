import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/suggested_action.dart';

/// Device-local "Suggested Actions" checklist saved from insight chat.
/// One JSON string per action in the `suggested_actions` Hive box, keyed
/// by the action id.
class SuggestedActionsProvider extends ChangeNotifier {
  static const _boxName = 'suggested_actions';

  Box<String>? _box;
  List<SuggestedAction> _actions = [];

  /// Newest first.
  List<SuggestedAction> get actions => List.unmodifiable(_actions);

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
    _reload();
  }

  void _reload({bool notify = true}) {
    final box = _box;
    if (box == null) return;
    final loaded = <SuggestedAction>[];
    for (final value in box.values) {
      try {
        loaded.add(SuggestedAction.decode(value));
      } catch (_) {
        // Skip corrupt rows — one bad entry must not hide the rest.
      }
    }
    _actions = loaded..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (notify) notifyListeners();
  }

  bool contains(String text) => _actions.any((a) => a.text == text);

  Future<void> add(String text) async {
    if (contains(text)) return;
    final now = DateTime.now();
    var id = now.millisecondsSinceEpoch.toString();
    var n = 1;
    while (_box?.containsKey(id) ?? false) {
      id = '${now.millisecondsSinceEpoch}-${n++}';
    }
    final action = SuggestedAction(id: id, text: text, createdAt: now);
    await _box?.put(id, action.encode());
    _reload();
  }

  Future<void> toggleDone(String id) async {
    final idx = _actions.indexWhere((a) => a.id == id);
    if (idx == -1) return;
    final updated = _actions[idx].copyWith(done: !_actions[idx].done);
    await _box?.put(id, updated.encode());
    _reload();
  }

  Future<void> remove(String id) async {
    await _box?.delete(id);
    _reload();
  }
}
