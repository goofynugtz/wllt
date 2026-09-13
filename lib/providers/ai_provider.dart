import 'package:flutter/foundation.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';

enum AiModelState { notDownloaded, downloading, ready, error }

class AiProvider extends ChangeNotifier {
  final StorageService _storage;

  AiModelState _state = AiModelState.notDownloaded;
  double _downloadProgress = 0.0;
  String? _downloadingId;
  bool _isPro = false;

  AiModelState get state => _state;
  double get downloadProgress => _downloadProgress;
  bool get isEnabled => _storage.aiEnabled;

  /// Name/size of whichever on-device model tier this device resolved to —
  /// for settings copy. Small-tier numbers until [init] resolves.
  String get modelDisplayName => AiService.instance.modelDisplayName;
  String get modelSizeLabel => AiService.instance.modelSizeLabel;

  // ── Dev-mode model lab ────────────────────────────────────────────────
  // Only meaningful when [StorageService.devMode] is true — the settings
  // screen routes to a model-picker page instead of the plain on/off switch.
  // The model catalog itself comes from ModelManifestService, not here.

  ModelSpec get activeSpec => AiService.instance.activeSpec;
  String get activeModelId => AiService.instance.activeModelId;

  /// Id of the model currently downloading, if any (only one at a time).
  String? get downloadingId => _downloadingId;

  Future<bool> isModelDownloaded(String id) =>
      AiService.instance.isModelDownloaded(id);

  /// Download [spec]. Does not activate it — call [selectActiveModel]
  /// afterwards. Cancel via [cancelDownload].
  Future<void> downloadModel(ModelSpec spec) async {
    _downloadingId = spec.id;
    _downloadProgress = 0.0;
    notifyListeners();
    try {
      await AiService.instance.downloadModel(
        spec,
        onProgress: (p) {
          _downloadProgress = p;
          notifyListeners();
        },
      );
    } finally {
      _downloadingId = null;
      notifyListeners();
    }
  }

  /// Cancels the in-flight [downloadModel] call, if any.
  void cancelDownload() => AiService.instance.cancelDownload();

  /// Make [spec] (must already be downloaded) the active model and load it.
  Future<void> selectActiveModel(ModelSpec spec) async {
    _state = AiModelState.downloading; // reusing as a generic "busy" state
    notifyListeners();
    try {
      await AiService.instance.setActiveModel(spec);
      await _storage.setActiveModel({
        'url': spec.hfUrl,
        'displayName': spec.displayName,
        'sizeLabel': spec.sizeLabel,
      });
      await _storage.setAiEnabled(true);
      _state = AiModelState.ready;
    } catch (e) {
      debugPrint('[AiProvider] Model switch failed: $e');
      _state = AiModelState.error;
    }
    notifyListeners();
  }

  /// Delete the downloaded [spec]. If it was the active model, disables AI
  /// features the same way [disable] does.
  Future<void> deleteDownloadedModel(ModelSpec spec) async {
    await AiService.instance.deleteModel(spec);
    if (spec.id == activeModelId) {
      await _storage.setAiEnabled(false);
      _state = AiModelState.notDownloaded;
    }
    notifyListeners();
  }

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
    final devMode = _storage.devMode;
    // flutter_gemma runtime init (no-op if already done). Dev mode resolves
    // the active model from the persisted model-lab pick (no network call
    // needed to reload it); release auto-picks by device RAM.
    ModelSpec? devActiveSpec;
    if (devMode) {
      final saved = _storage.activeModel;
      if (saved != null) {
        devActiveSpec = ModelSpec.direct(
          url: saved['url']!,
          displayName: saved['displayName']!,
          sizeLabel: saved['sizeLabel']!,
        );
      }
    }
    await AiService.instance.init(devMode: devMode, devActiveSpec: devActiveSpec);

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

  /// True if the active model's file is already on disk (survives
  /// toggle-off crashes, reinstalls that keep app data, etc.). Checked
  /// before offering a download.
  Future<bool> get isActiveModelDownloaded => AiService.instance.modelFileExists;

  /// Download model then initialize. Called when user confirms in settings.
  /// Skips the network entirely if the file is already installed.
  Future<void> enableAndDownload() async {
    if (!_isPro) return;
    _state = AiModelState.downloading;
    _downloadProgress = 0.0;
    notifyListeners();

    try {
      if (!await AiService.instance.modelFileExists) {
        await AiService.instance.downloadModel(
          AiService.instance.activeSpec,
          onProgress: (p) {
            _downloadProgress = p;
            notifyListeners();
          },
        );
      }
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
    await AiService.instance.deleteModel(AiService.instance.activeSpec);
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
