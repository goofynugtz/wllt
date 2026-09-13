import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_gemma/flutter_gemma.dart'
    if (dart.library.html) '../platform/gemma_web.dart' hide ModelSpec;

import 'ai_service.dart';

/// Dev-mode model catalog for the model lab. Cloudflare R2 doesn't allow
/// listing a bucket's contents without S3 credentials (which we won't ship
/// in the app binary), so the catalog instead comes from a hand-maintained
/// manifest.json uploaded to the same public bucket used for downloads.
///
/// Expected shape:
/// ```json
/// [
///   {"name": "Gemma 3 1B", "filename": "gemma3-1b-it-int4.task", "sizeBytes": 629145600},
///   {"name": "Gemma 4 E2B", "filename": "gemma-4-E2B-it.litertlm", "sizeBytes": 2588147712, "modelType": "gemma4"}
/// ]
/// ```
/// The download url for each entry is always `$_baseUrl$filename`. `fileType`
/// (.task vs .litertlm) is derived from the filename automatically —
/// `modelType` isn't, so it's an explicit field; omit it for the default
/// Gemma 3 family (`gemmaIt`), set `"gemma4"` for Gemma 4 E2B/E4B entries.
class ModelManifestService {
  ModelManifestService._();

  static const _baseUrl = 'https://pub-c5cf7c64e3d44baea74a98f0d802eab7.r2.dev/';
  static const _manifestUrl = '${_baseUrl}manifest.json';

  static Future<List<ModelSpec>> fetch() async {
    final res = await http.get(Uri.parse(_manifestUrl));
    if (res.statusCode != 200) {
      throw Exception('Model manifest fetch failed (HTTP ${res.statusCode})');
    }
    final entries = jsonDecode(res.body) as List<dynamic>;
    return entries.map((e) {
      final map = e as Map<String, dynamic>;
      final filename = map['filename'] as String;
      final sizeBytes = map['sizeBytes'] as int;
      return ModelSpec.direct(
        url: '$_baseUrl$filename',
        displayName: map['name'] as String,
        sizeLabel: _formatBytes(sizeBytes),
        modelType: map['modelType'] == 'gemma4' ? ModelType.gemma4 : ModelType.gemmaIt,
      );
    }).toList();
  }

  static String _formatBytes(int bytes) {
    const gb = 1024 * 1024 * 1024;
    const mb = 1024 * 1024;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
    return '${(bytes / mb).toStringAsFixed(2)} MB';
  }
}
