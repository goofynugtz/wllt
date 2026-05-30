// Web stub for receive_sharing_intent — returns empty streams/lists.
import 'dart:async';

enum SharedMediaType { text, image, video, file, url }

class SharedMediaFile {
  final SharedMediaType type;
  final String? message;
  const SharedMediaFile({required this.type, this.message});
}

class _SharingIntentInstance {
  Stream<List<SharedMediaFile>> getMediaStream() => const Stream.empty();
  Future<List<SharedMediaFile>> getInitialMedia() async => [];
}

class ReceiveSharingIntent {
  static final _SharingIntentInstance instance = _SharingIntentInstance();
}
