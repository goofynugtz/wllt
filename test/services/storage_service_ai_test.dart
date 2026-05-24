import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wllt/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('aiEnabled defaults to false', () async {
    final storage = StorageService();
    await storage.init();
    expect(storage.aiEnabled, false);
  });

  test('setAiEnabled persists value', () async {
    final storage = StorageService();
    await storage.init();
    await storage.setAiEnabled(true);
    expect(storage.aiEnabled, true);
    await storage.setAiEnabled(false);
    expect(storage.aiEnabled, false);
  });
}
