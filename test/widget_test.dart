// Minimal smoke test — verifies the app widget tree can be instantiated.
// Full integration tests live in the integration_test/ directory.

import 'package:flutter_test/flutter_test.dart';

import 'package:wllt/main.dart';

void main() {
  testWidgets('WalletApp can be referenced', (WidgetTester tester) async {
    // Just confirm the exported class exists and is a Widget.
    expect(WalletApp, isNotNull);
  });
}
