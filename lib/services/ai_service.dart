import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart'
    if (dart.library.html) '../platform/gemma_web.dart';

typedef ProgressCallback = void Function(double progress);

class AiService {
  AiService._();
  static final instance = AiService._();

  // Gemma 3 1B int4 in MediaPipe LlmInference (.task) format.
  // Source resolution:
  //   HF_TOKEN provided → Hugging Face (gated Gemma repo, token required)
  //   no HF_TOKEN       → self-hosted MODEL_URL (default for all builds)
  //   flutter run --dart-define=HF_TOKEN=hf_xxx
  //   flutter run --dart-define=MODEL_URL=https://your-bucket/gemma3-1b-it-int4.task
  // NOTE: dart-define values are embedded in the binary. HF token is for
  // testing builds only — public releases must ship without it.
  static const _hfUrl =
      'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task';
  static const _selfHostedUrl = String.fromEnvironment(
    'MODEL_URL',
    defaultValue:
        'https://pub-c5cf7c64e3d44baea74a98f0d802eab7.r2.dev/gemma3-1b-it-int4.task',
  );
  static const _hfTokenEnv = String.fromEnvironment('HF_TOKEN');
  static String? get _hfToken => _hfTokenEnv.isEmpty ? null : _hfTokenEnv;
  static String get _modelUrl => _hfToken == null ? _selfHostedUrl : _hfUrl;
  // Model ID used internally by flutter_gemma — matches the filename part of _modelUrl
  static const _modelId = 'gemma3-1b-it-cpu-int4.task';

  InferenceModel? _model;
  bool _gemmaInitialized = false;

  bool get isInitialized => _model != null;

  /// One-time initialization of the flutter_gemma runtime. Call once at app startup.
  Future<void> init() async {
    if (_gemmaInitialized) return;
    await FlutterGemma.initialize(
      huggingFaceToken: _hfToken,
    );
    _gemmaInitialized = true;
  }

  /// Returns true if the model file is installed on this device.
  Future<bool> get modelFileExists async {
    return FlutterGemma.isModelInstalled(_modelId);
  }

  /// Download and install the model. Calls [onProgress] with 0.0–1.0.
  /// Throws on network or storage errors.
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
    debugPrint('[AiService] Model loaded');
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
