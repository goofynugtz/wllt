import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart'
    if (dart.library.html) '../platform/gemma_web.dart';

import 'device_capability.dart';

typedef ProgressCallback = void Function(double progress);

/// Download source + display info for one on-device model tier. Both tiers
/// use MediaPipe LlmInference (.task) format and ModelType.gemmaIt, so the
/// chat prompt template ([ChatAdapter]) never has to know which is active.
class _ModelSpec {
  final String hfUrl;
  final String selfHostedUrl; // '' if not configured for this tier
  final String displayName;
  final String sizeLabel;

  const _ModelSpec({
    required this.hfUrl,
    required this.selfHostedUrl,
    required this.displayName,
    required this.sizeLabel,
  });
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
  static const _smallSpec = _ModelSpec(
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
  static const _bigSpec = _ModelSpec(
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
  bool _isBigTier = false;

  bool get isInitialized => _model != null;

  /// True once [init] has resolved this device to the larger model tier.
  bool get isBigTier => _isBigTier;

  _ModelSpec get _spec => _isBigTier ? _bigSpec : _smallSpec;

  /// User-facing name/size of whichever tier this device is on — for
  /// settings copy. Reflects the small tier's numbers until [init] resolves.
  String get modelDisplayName => _spec.displayName;
  String get modelSizeLabel => _spec.sizeLabel;

  /// Model ID used internally by flutter_gemma. Always derived from the HF
  /// filename (both tiers' self-hosted copies must be named identically) so
  /// it can never drift out of sync with what a download actually installs,
  /// and never throws even when no self-hosted URL is configured yet.
  String get _modelId => Uri.parse(_spec.hfUrl).pathSegments.last;

  String get _modelUrl {
    final spec = _spec;
    if (_hfToken != null) return spec.hfUrl;
    if (spec.selfHostedUrl.isEmpty) {
      throw StateError(
        'AiService: no self-hosted URL configured for the ${spec.displayName} '
        'tier. Pass --dart-define=MODEL_URL_4B=https://your-host/... (or '
        '--dart-define=HF_TOKEN=hf_xxx for testing against the gated '
        'Hugging Face repo).',
      );
    }
    return spec.selfHostedUrl;
  }

  /// One-time initialization: resolves the device's model tier by RAM, then
  /// starts the flutter_gemma runtime. Call once at app startup.
  Future<void> init() async {
    if (_gemmaInitialized) return;
    _isBigTier = await DeviceCapability.supportsBigModel;
    await FlutterGemma.initialize(
      huggingFaceToken: _hfToken,
    );
    _gemmaInitialized = true;
  }

  /// Returns true if this tier's model file is installed on this device.
  Future<bool> get modelFileExists async {
    return FlutterGemma.isModelInstalled(_modelId);
  }

  /// Download and install the model. Calls [onProgress] with 0.0–1.0.
  /// Throws on network or storage errors, or if this tier has no configured
  /// download source (see [_bigSpec]).
  Future<void> downloadModel({required ProgressCallback onProgress}) async {
    await FlutterGemma.installModel(modelType: ModelType.gemmaIt)
        .fromNetwork(_modelUrl, token: _hfToken)
        .withProgress((int pct) => onProgress(pct / 100.0))
        .install();
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

  /// Delete the installed model and reset initialized state.
  /// Closes the loaded model first — the native engine keeps the file
  /// mmap'd, so deleting without closing leaves the ~555 MB held on disk
  /// until the process exits.
  Future<void> deleteModel() async {
    final model = _model;
    _model = null;
    if (model != null) {
      try {
        await model.close();
      } catch (e) {
        debugPrint('[AiService] Model close failed: $e');
      }
    }
    final installed = await FlutterGemma.isModelInstalled(_modelId);
    if (installed) {
      await FlutterGemma.uninstallModel(_modelId);
      debugPrint('[AiService] Model deleted');
    }
  }
}
