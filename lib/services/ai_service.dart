import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

typedef ProgressCallback = void Function(double progress);

class AiService {
  AiService._();
  static final instance = AiService._();

  // Model configuration — developer must replace with actual values
  // Get the model from Kaggle or Hugging Face in MediaPipe LlmInference (.task) format
  // See: https://ai.google.dev/edge/mediapipe/solutions/genai/llm_inference
  static const _modelUrl =
      'https://huggingface.co/REPLACE_WITH_GEMMA3_1B_MODEL_REPO/resolve/main/gemma3-1b-it-cpu-int4.task';
  // If the model requires a Hugging Face token:
  static const String? _hfToken = null; // 'hf_REPLACE_WITH_TOKEN';
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
    _model = await FlutterGemma.getActiveModel(maxTokens: 512);
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

  /// Delete the installed model and reset initialized state.
  Future<void> deleteModel() async {
    _model = null;
    final installed = await FlutterGemma.isModelInstalled(_modelId);
    if (installed) {
      await FlutterGemma.uninstallModel(_modelId);
      debugPrint('[AiService] Model deleted');
    }
  }
}
