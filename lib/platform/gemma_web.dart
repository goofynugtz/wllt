import 'dart:async';

// Web stub for flutter_gemma — all operations are no-ops.

enum ModelType { gemmaIt, gemma4 }
enum ModelFileType { task, litertlm }

class FlutterGemma {
  static Future<void> initialize({String? huggingFaceToken}) async {}
  static Future<bool> isModelInstalled(String modelId) async => false;
  static _ModelInstaller installModel({
    required ModelType modelType,
    ModelFileType fileType = ModelFileType.task,
  }) =>
      _ModelInstaller();
  static Future<InferenceModel> getActiveModel({required int maxTokens}) async =>
      InferenceModel._();
  static Future<void> uninstallModel(String modelId) async {}
}

class _ModelInstaller {
  _ModelInstaller fromNetwork(String url, {String? token, bool? foreground}) => this;
  _ModelInstaller withProgress(void Function(int) cb) => this;
  _ModelInstaller withCancelToken(CancelToken token) => this;
  Future<void> install() async {}
}

class CancelToken {
  bool isCancelled = false;
  void cancel([String reason = 'Operation cancelled']) => isCancelled = true;
  static bool isCancel(Object error) => error is DownloadCancelledException;
}

class DownloadCancelledException implements Exception {
  final String message;
  DownloadCancelledException(this.message);
  @override
  String toString() => 'DownloadCancelledException: $message';
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
