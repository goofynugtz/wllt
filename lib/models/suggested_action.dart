import 'dart:convert';

/// One saved LLM suggestion in the "Suggested Actions" checklist.
/// Stored device-only as a JSON string in the `suggested_actions` Hive box.
class SuggestedAction {
  final String id;
  final String text;
  final DateTime createdAt;
  final bool done;

  const SuggestedAction({
    required this.id,
    required this.text,
    required this.createdAt,
    this.done = false,
  });

  SuggestedAction copyWith({bool? done}) => SuggestedAction(
        id: id,
        text: text,
        createdAt: createdAt,
        done: done ?? this.done,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'done': done,
      };

  factory SuggestedAction.fromJson(Map<String, dynamic> json) =>
      SuggestedAction(
        id: json['id'] as String,
        text: json['text'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
                DateTime.now(),
        done: json['done'] as bool? ?? false,
      );

  String encode() => jsonEncode(toJson());

  factory SuggestedAction.decode(String source) =>
      SuggestedAction.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
