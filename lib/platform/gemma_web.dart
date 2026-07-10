import 'dart:async';

// Web stub for flutter_gemma — all operations are no-ops.

enum ModelType { gemmaIt }

class FlutterGemma {
  static Future<void> initialize({String? huggingFaceToken}) async {}
  static Future<bool> isModelInstalled(String modelId) async => false;
  static _ModelInstaller installModel({required ModelType modelType}) =>
      _ModelInstaller();
  static Future<InferenceModel> getActiveModel({required int maxTokens}) async =>
      InferenceModel._();
  static Future<void> uninstallModel(String modelId) async {}
}

class _ModelInstaller {
  _FromNetwork fromNetwork(String url, {String? token}) => _FromNetwork();
}

class _FromNetwork {
  _WithProgress withProgress(void Function(int) cb) => _WithProgress();
}

class _WithProgress {
  Future<void> install() async {}
}

class InferenceModel {
  InferenceModel._();
  Future<Session> createSession({
    double temperature = 0.1,
    int topK = 1,
    int randomSeed = 1,
  }) async =>
      Session._();
  Future<void> close() async {}
}

class Session {
  Session._();
  Future<void> addQueryChunk(Message message) async {}
  Future<String> getResponse() async => '';
  Stream<String> getResponseAsync() async* {}
  Future<void> close() async {}
}

class Message {
  Message._();
  static Message text({required String text, required bool isUser}) =>
      Message._();
}
