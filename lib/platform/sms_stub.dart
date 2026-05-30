// Web stub for flutter_sms_inbox.
// SmsMessage here is the package's type; the local SmsMessage in sms_reader.dart
// shadows it. These stubs exist only to satisfy the SmsQuery / SmsQueryKind symbols.

class SmsMessage {
  final dynamic id;
  final String? body;
  final String? sender;
  final DateTime? dateSent;
  const SmsMessage({this.id, this.body, this.sender, this.dateSent});
}

enum SmsQueryKind { inbox }

class SmsQuery {
  Future<List<SmsMessage>> querySms({
    List<SmsQueryKind> kinds = const [],
  }) async =>
      [];
}
