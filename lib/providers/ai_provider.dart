import 'package:flutter/foundation.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';

enum AiModelState { notDownloaded, downloading, ready, error }

class AiProvider extends ChangeNotifier {
  final StorageService _storage;

  AiModelState _state = AiModelState.notDownloaded;
  double _downloadProgress = 0.0;
  bool _isPro = false;

  AiModelState get state => _state;
  double get downloadProgress => _downloadProgress;
  bool get isEnabled => _storage.aiEnabled;

  /// True only when model is loaded AND user has Pro subscription.
  bool get isReady => _state == AiModelState.ready && _isPro;

  AiProvider(this._storage);

  /// Called by ChangeNotifierProxyProvider when subscription status changes.
  void updateIsPro(bool isPro) {
    if (_isPro == isPro) return;
    _isPro = isPro;
    notifyListeners();
  }

  /// Called on app launch. Determines initial state in background — does not block UI.
  Future<void> init() async {
    await AiService.instance.init(); // flutter_gemma runtime init (no-op if already done)

    if (!_isPro) {
      _state = AiModelState.notDownloaded;
      notifyListeners();
      return;
    }
    if (!isEnabled) {
      _state = AiModelState.notDownloaded;
      notifyListeners();
      return;
    }
    // isEnabled=true → check if model file is installed
    final exists = await AiService.instance.modelFileExists;
    if (!exists) {
      // Model was deleted externally — reset enabled flag
      await _storage.setAiEnabled(false);
      _state = AiModelState.notDownloaded;
      notifyListeners();
      return;
    }
    // File exists → load model in background, set ready optimistically
    _state = AiModelState.ready;
    notifyListeners();
    try {
      await AiService.instance.initModel();
    } catch (e) {
      debugPrint('[AiProvider] Model init failed: $e');
      _state = AiModelState.error;
      notifyListeners();
    }
  }

  /// Download model then initialize. Called when user confirms in settings.
  Future<void> enableAndDownload() async {
    if (!_isPro) return;
    _state = AiModelState.downloading;
    _downloadProgress = 0.0;
    notifyListeners();

    try {
      await AiService.instance.downloadModel(
        onProgress: (p) {
          _downloadProgress = p;
          notifyListeners();
        },
      );
      await AiService.instance.initModel();
      await _storage.setAiEnabled(true);
      _state = AiModelState.ready;
    } catch (e) {
      debugPrint('[AiProvider] Download/init failed: $e');
      _state = AiModelState.error;
      await _storage.setAiEnabled(false);
    }
    notifyListeners();
  }

  /// Delete model file and reset state. Called when user toggles off.
  Future<void> disable() async {
    await AiService.instance.deleteModel();
    await _storage.setAiEnabled(false);
    _state = AiModelState.notDownloaded;
    _downloadProgress = 0.0;
    notifyListeners();
  }

  /// Reset error state so user can retry download.
  void clearError() {
    if (_state == AiModelState.error) {
      _state = AiModelState.notDownloaded;
      notifyListeners();
    }
  }
}
