import 'package:cloud_firestore/cloud_firestore.dart';

class InsightCard {
  final String weekKey;
  final String text;
  final DateTime generatedAt;

  const InsightCard({
    required this.weekKey,
    required this.text,
    required this.generatedAt,
  });

  Map<String, dynamic> toJson() => {
        'weekKey': weekKey,
        'text': text,
        'generatedAt': Timestamp.fromDate(generatedAt),
      };

  factory InsightCard.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data()!;
    return InsightCard(
      weekKey: snap.id,
      text: d['text'] as String? ?? '',
      generatedAt: (d['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
