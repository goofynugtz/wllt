import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wllt/models/suggested_action.dart';
import 'package:wllt/providers/suggested_actions_provider.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('wllt_actions_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk('suggested_actions');
    await Hive.close();
  });

  tearDownAll(() => tempDir.deleteSync(recursive: true));

  test('starts empty', () async {
    final p = SuggestedActionsProvider();
    await p.init();
    expect(p.actions, isEmpty);
  });

  test('add stores action with text and done=false', () async {
    final p = SuggestedActionsProvider();
    await p.init();
    await p.add('Cancel Netflix to save ₹649/month');
    expect(p.actions, hasLength(1));
    expect(p.actions.first.text, 'Cancel Netflix to save ₹649/month');
    expect(p.actions.first.done, isFalse);
  });

  test('add with duplicate text is a no-op', () async {
    final p = SuggestedActionsProvider();
    await p.init();
    await p.add('same text');
    await p.add('same text');
    expect(p.actions, hasLength(1));
    expect(p.contains('same text'), isTrue);
    expect(p.contains('other'), isFalse);
  });

  test('toggleDone flips and persists', () async {
    final p = SuggestedActionsProvider();
    await p.init();
    await p.add('do a thing');
    final id = p.actions.first.id;
    await p.toggleDone(id);
    expect(p.actions.first.done, isTrue);
    await p.toggleDone(id);
    expect(p.actions.first.done, isFalse);
  });

  test('remove deletes the action', () async {
    final p = SuggestedActionsProvider();
    await p.init();
    await p.add('to be removed');
    await p.remove(p.actions.first.id);
    expect(p.actions, isEmpty);
  });

  test('actions survive provider re-instantiation', () async {
    final p1 = SuggestedActionsProvider();
    await p1.init();
    await p1.add('persist me');
    await p1.toggleDone(p1.actions.first.id);

    final p2 = SuggestedActionsProvider();
    await p2.init();
    expect(p2.actions, hasLength(1));
    expect(p2.actions.first.text, 'persist me');
    expect(p2.actions.first.done, isTrue);
  });

  test('notifies listeners on mutations', () async {
    final p = SuggestedActionsProvider();
    await p.init();
    var notified = 0;
    p.addListener(() => notified++);
    await p.add('a');
    await p.toggleDone(p.actions.first.id);
    await p.remove(p.actions.first.id);
    expect(notified, 3);
  });

  test('rapid adds never collide or overwrite', () async {
    final p = SuggestedActionsProvider();
    await p.init();
    for (var i = 0; i < 10; i++) {
      await p.add('action $i');
    }
    expect(p.actions, hasLength(10));
  });

  test('actions sorted newest first by createdAt', () async {
    final box = await Hive.openBox<String>('suggested_actions');
    await box.put('1', SuggestedAction(
        id: '1', text: 'older', createdAt: DateTime(2026, 1, 1)).encode());
    await box.put('2', SuggestedAction(
        id: '2', text: 'newer', createdAt: DateTime(2026, 1, 2)).encode());

    final p = SuggestedActionsProvider();
    await p.init();
    expect(p.actions.first.text, 'newer');
    expect(p.actions.last.text, 'older');
  });

  test('corrupt box row is skipped, not fatal', () async {
    final box = await Hive.openBox<String>('suggested_actions');
    await box.put('bad', 'not json at all');
    await box.put('1', SuggestedAction(
        id: '1', text: 'valid', createdAt: DateTime(2026, 1, 1)).encode());

    final p = SuggestedActionsProvider();
    await p.init();
    expect(p.actions, hasLength(1));
    expect(p.actions.first.text, 'valid');
    await p.add('still works');
    expect(p.actions, hasLength(2));
  });
}
