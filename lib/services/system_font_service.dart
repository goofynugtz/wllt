import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Loads the device's active system font into Flutter at startup by reading
/// the raw font bytes from the Android native layer.
///
/// This bypasses Flutter/minikin's name-based font resolution, which does not
/// reflect OEM font overrides (e.g. Samsung's custom font settings).
class SystemFontService {
  static const _channel = MethodChannel('com.goofynugtz.wllt/system_font');

  /// The font family name registered with Flutter's FontLoader.
  static const familyName = 'SystemDefault';

  /// Fetches font bytes from the native layer, registers the font with
  /// [FontLoader], and returns [familyName] for use in [ThemeData].
  ///
  /// Returns `'sans-serif'` on failure (native call unavailable, font file
  /// unreadable, or non-Android platform).
  static Future<String> loadSystemFont() async {
    if (kIsWeb) return 'sans-serif';
    try {
      final bytes =
          await _channel.invokeMethod<Uint8List>('getSystemFontBytes');
      if (bytes == null || bytes.isEmpty) return 'sans-serif';

      final loader = FontLoader(familyName);
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
      return familyName;
    } on PlatformException {
      return 'sans-serif';
    }
  }
}
