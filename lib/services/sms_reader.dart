import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';

class SmsMessage {
  final String? id;
  final String sender;
  final String body;
  final DateTime date;

  const SmsMessage({this.id, required this.sender, required this.body, required this.date});
}

class SmsReader {
  static Future<List<SmsMessage>> readSince(DateTime since) async {
    try {
      final query = SmsQuery();
      final messages = await query.querySms(
        kinds: [SmsQueryKind.inbox],
      );
      return messages
          .where((m) =>
              m.body != null &&
              m.sender != null &&
              (m.dateSent?.isAfter(since) ?? false))
          .map((m) => SmsMessage(
                id: m.id?.toString(),
                sender: m.sender!,
                body: m.body!,
                date: m.dateSent ?? DateTime.now(),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
