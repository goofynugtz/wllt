import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart'
    if (dart.library.html) '../platform/gemma_web.dart';

import 'device_capability.dart';

typedef ProgressCallback = void Function(double progress);

/// Download source + display info for one on-device model. The Gemma 3
/// tiers use MediaPipe LlmInference (.task format, ModelType.gemmaIt) so
/// [ChatAdapter]'s prompt template never has to know which is active; Gemma 4
/// models use the newer LiteRT-LM runtime (.litertlm, ModelType.gemma4) —
/// flutter_gemma's Session API handles that difference internally, so
/// [ChatAdapter] doesn't have to care about this split either.
class ModelSpec {
  final String hfUrl;
  final String selfHostedUrl; // '' if not configured for this model
  final String displayName;
  final String sizeLabel;
  final ModelType modelType;

  const ModelSpec({
    required this.hfUrl,
    required this.selfHostedUrl,
    required this.displayName,
    required this.sizeLabel,
    this.modelType = ModelType.gemmaIt,
  });

  /// A model whose download url is fixed and needs no HF-token resolution
  /// (e.g. dev-mode model-lab entries fetched from a public R2 manifest).
  factory ModelSpec.direct({
    required String url,
    required String displayName,
    required String sizeLabel,
    ModelType modelType = ModelType.gemmaIt,
  }) =>
      ModelSpec(
        hfUrl: url,
        selfHostedUrl: url,
        displayName: displayName,
        sizeLabel: sizeLabel,
        modelType: modelType,
      );

  /// Install id used by flutter_gemma. Derived from the HF filename (both
  /// tiers' self-hosted copies must be named identically) so it can never
  /// drift out of sync with what a download actually installs.
  String get id => Uri.parse(hfUrl).pathSegments.last;

  /// Derived from the file extension — .litertlm models load via
  /// flutter_gemma's LiteRT-LM path, everything else (.task) via the legacy
  /// MediaPipe path.
  ModelFileType get fileType =>
      id.endsWith('.litertlm') ? ModelFileType.litertlm : ModelFileType.task;
}

class AiService {
  AiService._();
  static final instance = AiService._();

  // Source resolution (both tiers):
  //   HF_TOKEN provided → Hugging Face (gated Gemma repo, token required)
  //   no HF_TOKEN       → self-hosted URL (default for all builds)
  //   flutter run --dart-define=HF_TOKEN=hf_xxx
  //   flutter run --dart-define=MODEL_URL=https://your-bucket/gemma3-1b-it-int4.task
  //   flutter run --dart-define=MODEL_URL_4B=https://your-bucket/gemma-3n-E4B-it-int4.task
  // NOTE: dart-define values are embedded in the binary. HF token is for
  // testing builds only — public releases must ship without it.
  static const _smallSpec = ModelSpec(
    hfUrl:
        'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task',
    selfHostedUrl: String.fromEnvironment(
      'MODEL_URL',
      defaultValue:
          'https://pub-c5cf7c64e3d44baea74a98f0d802eab7.r2.dev/gemma3-1b-it-int4.task',
    ),
    displayName: 'Gemma 3 1B',
    sizeLabel: '~600 MB',
  );
  // Gemma 3n E4B — the "4B"-class tier. No plain mobile-CPU .task build of
  // the larger, non-nano Gemma 3 4B is published (litert-community only
  // ships that one as web/WASM bundles); this is the real deployable
  // equivalent for MediaPipe LlmInference on Android/iOS.
  // selfHostedUrl has no default — there's no public, ungated CPU build to
  // fall back to, so this MUST be configured (or use HF_TOKEN for testing)
  // before the big tier can actually download. See [downloadModel].
  static const _bigSpec = ModelSpec(
    hfUrl:
        'https://huggingface.co/google/gemma-3n-E4B-it-litert-preview/resolve/main/gemma-3n-E4B-it-int4.task',
    selfHostedUrl: String.fromEnvironment('MODEL_URL_4B'),
    displayName: 'Gemma 3n E4B',
    sizeLabel: '~6.5 GB',
  );

  static const _hfTokenEnv = String.fromEnvironment('HF_TOKEN');
  static String? get _hfToken => _hfTokenEnv.isEmpty ? null : _hfTokenEnv;

  InferenceModel? _model;
  bool _gemmaInitialized = false;
  ModelSpec _activeSpec = _smallSpec;
  CancelToken? _downloadCancelToken;

  bool get isInitialized => _model != null;

  /// The model currently active (loaded or about to load).
  ModelSpec get activeSpec => _activeSpec;
  String get activeModelId => _activeSpec.id;

  /// User-facing name/size of whichever model is active — for settings copy.
  /// Reflects the small model's numbers until [init] resolves.
  String get modelDisplayName => _activeSpec.displayName;
  String get modelSizeLabel => _activeSpec.sizeLabel;

  String _urlFor(ModelSpec spec) {
    if (_hfToken != null) return spec.hfUrl;
    if (spec.selfHostedUrl.isEmpty) {
      throw StateError(
        'AiService: no self-hosted URL configured for the ${spec.displayName} '
        'model. Pass --dart-define=MODEL_URL_4B=https://your-host/... (or '
        '--dart-define=HF_TOKEN=hf_xxx for testing against the gated '
        'Hugging Face repo).',
      );
    }
    return spec.selfHostedUrl;
  }

  /// One-time initialization: resolves the active model (dev mode: the
  /// persisted [devActiveSpec], or the small model's default if the lab has
  /// no pick yet; release: auto-pick by device RAM), then starts the
  /// flutter_gemma runtime. Call once at app startup.
  Future<void> init({bool devMode = false, ModelSpec? devActiveSpec}) async {
    if (_gemmaInitialized) return;
    if (devMode) {
      if (devActiveSpec != null) _activeSpec = devActiveSpec;
    } else {
      _activeSpec =
          await DeviceCapability.supportsBigModel ? _bigSpec : _smallSpec;
    }
    await FlutterGemma.initialize(
      huggingFaceToken: _hfToken,
    );
    _gemmaInitialized = true;
  }

  /// Returns true if the active model's file is installed on this device.
  Future<bool> get modelFileExists async {
    return FlutterGemma.isModelInstalled(_activeSpec.id);
  }

  /// Returns true if the given model (by [ModelSpec.id]) is installed.
  Future<bool> isModelDownloaded(String id) => FlutterGemma.isModelInstalled(id);

  /// Download and install [spec]. Calls [onProgress] with 0.0–1.0. Does not
  /// activate it unless it's already the active model — see [setActiveModel].
  /// Cancel with [cancelDownload]; a user cancellation returns normally
  /// rather than throwing. Throws on network/storage errors, or if this
  /// model has no configured download source (see [_bigSpec]).
  Future<void> downloadModel(
    ModelSpec spec, {
    required ProgressCallback onProgress,
  }) async {
    final token = CancelToken();
    _downloadCancelToken = token;
    try {
      await FlutterGemma.installModel(modelType: spec.modelType, fileType: spec.fileType)
          .fromNetwork(_urlFor(spec), token: _hfToken, foreground: true)
          .withProgress((int pct) => onProgress(pct / 100.0))
          .withCancelToken(token)
          .install();
    } on DownloadCancelledException {
      return;
    } finally {
      _downloadCancelToken = null;
    }
    // install() auto-activates whatever it just installed inside the plugin
    // — if that wasn't the model this app considers active, and the real
    // active one is already on disk, re-assert it (also a no-op install, no
    // re-download) so the plugin's active pointer doesn't drift from ours.
    if (spec.id != _activeSpec.id && await FlutterGemma.isModelInstalled(_activeSpec.id)) {
      await FlutterGemma.installModel(modelType: _activeSpec.modelType, fileType: _activeSpec.fileType)
          .fromNetwork(_urlFor(_activeSpec), token: _hfToken)
          .install();
    }
  }

  /// Cancels the in-flight [downloadModel] call, if any.
  void cancelDownload() => _downloadCancelToken?.cancel('User cancelled');

  /// Switch the active model to [spec] (must already be downloaded) and load
  /// it into memory, closing whatever was previously loaded. No-op if
  /// [spec] is already active and loaded.
  Future<void> setActiveModel(ModelSpec spec) async {
    if (spec.id == _activeSpec.id && _model != null) return;
    final old = _model;
    _model = null;
    if (old != null) {
      try {
        await old.close();
      } catch (e) {
        debugPrint('[AiService] Model close failed: $e');
      }
    }
    // Idempotent — file is already downloaded, so this just flips the
    // plugin's internal active pointer without a network call.
    await FlutterGemma.installModel(modelType: spec.modelType, fileType: spec.fileType)
        .fromNetwork(_urlFor(spec), token: _hfToken)
        .install();
    _activeSpec = spec;
    await initModel();
  }

  /// Load model weights into memory. Call after confirming model is installed.
  /// Safe to call multiple times — no-op if already initialized.
  Future<void> initModel() async {
    if (_model != null) return;
    // 1024: chat prompt (facts + trimmed history) plus a 150-token reply
    // needs more headroom than the one-shot summary/insight prompts.
    _model = await FlutterGemma.getActiveModel(maxTokens: 1024);
    debugPrint('[AiService] Model loaded ($modelDisplayName)');
  }

  /// Run inference with [prompt]. Creates and closes a session per call.
  /// [temperature]: randomness (0.1 = deterministic, 0.4 = creative)
  /// [maxTokens]: max response length in tokens
  /// Throws if model is not initialized or if inference times out.
  Future<String> infer(
    String prompt, {
    double temperature = 0.1,
    int maxTokens = 60,
  }) async {
    final model = _model;
    if (model == null) {
      throw StateError('AiService: model not initialized — call initModel() first');
    }

    final session = await model.createSession(
      temperature: temperature,
      topK: 1,
      randomSeed: 1,
    );
    try {
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      return await session
          .getResponse()
          .timeout(const Duration(seconds: 10));
    } finally {
      await session.close();
    }
  }

  /// Streams inference for [prompt] one raw token delta at a time. Creates
  /// and closes a session per call, same as [infer]. [temperature]:
  /// randomness (0.1 = deterministic, 0.4 = creative). Times out (throwing
  /// TimeoutException) if no chunk arrives within 10s — this is a per-chunk
  /// idle timeout, not a cap on total reply time.
  ///
  /// Unlike [infer] (used for deterministic extraction — categorization,
  /// SMS parsing — where near-greedy decoding is wanted), this samples from
  /// the top 40 tokens with a fresh random seed each call. [infer]'s
  /// `topK: 1` makes it near-argmax regardless of temperature, which is
  /// correct for extraction but produces repetitive, near-identical phrasing
  /// for the conversational replies this method streams for chat.
  Stream<String> inferStream(
    String prompt, {
    double temperature = 0.1,
  }) async* {
    final model = _model;
    if (model == null) {
      throw StateError('AiService: model not initialized — call initModel() first');
    }

    final session = await model.createSession(
      temperature: temperature,
      topK: 40,
      randomSeed: Random().nextInt(1 << 32),
    );
    try {
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      yield* session.getResponseAsync().timeout(const Duration(seconds: 10));
    } finally {
      await session.close();
    }
  }

  /// Delete [spec]. Closes the loaded model first if [spec] is the active
  /// one — the native engine keeps the file mmap'd, so deleting without
  /// closing leaves it held on disk until the process exits.
  Future<void> deleteModel(ModelSpec spec) async {
    if (spec.id == _activeSpec.id) {
      final model = _model;
      _model = null;
      if (model != null) {
        try {
          await model.close();
        } catch (e) {
          debugPrint('[AiService] Model close failed: $e');
        }
      }
    }
    final installed = await FlutterGemma.isModelInstalled(spec.id);
    if (installed) {
      await FlutterGemma.uninstallModel(spec.id);
      debugPrint('[AiService] Model deleted (${spec.id})');
    }
  }
}
