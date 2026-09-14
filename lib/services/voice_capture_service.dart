import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum VoiceCaptureError { permissionDenied, notAvailable, noMatch }

/// Thin wrapper around `speech_to_text`: requests mic permission, starts a
/// single-utterance listen, and reports the final transcript or a typed
/// error. [speech] is constructor-injectable for the same reason other
/// services in this codebase take their platform dependency in the
/// constructor, even though no test exercises it today — mocking
/// permission_handler's platform channel would require introducing a DI
/// abstraction nothing else in this codebase has, purely for test coverage
/// (the existing `Permission.sms` calls in layout_screen.dart and
/// settings_screen.dart are likewise untested).
class VoiceCaptureService {
  final SpeechToText _speech;

  VoiceCaptureService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  Future<bool> start({
    required void Function(String transcript) onFinalResult,
    required void Function(VoiceCaptureError error) onError,
  }) async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      onError(VoiceCaptureError.permissionDenied);
      return false;
    }

    final available = await _speech.initialize(
      onError: (_) => onError(VoiceCaptureError.notAvailable),
    );
    if (!available) {
      onError(VoiceCaptureError.notAvailable);
      return false;
    }

    await _speech.listen(
      onResult: (result) {
        if (!result.finalResult) return;
        final words = result.recognizedWords.trim();
        if (words.isEmpty) {
          onError(VoiceCaptureError.noMatch);
        } else {
          onFinalResult(words);
        }
      },
    );
    return true;
  }

  void stop() => _speech.stop();
}
