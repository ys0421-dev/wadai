class PersonTopic {
  const PersonTopic({
    required this.personId,
    required this.topicId,
    required this.note,
    required this.createdAt,
  });

  final String personId;
  final String topicId;
  final String note;
  final DateTime createdAt;

  String get pairKey => '$personId\u0000$topicId';

  PersonTopic copyWith({String? note}) => PersonTopic(
    personId: personId,
    topicId: topicId,
    note: note ?? this.note,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'personId': personId,
    'topicId': topicId,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PersonTopic.fromJson(Map<String, dynamic> json) {
    if (json['personId'] is! String ||
        json['topicId'] is! String ||
        json['note'] is! String ||
        json['createdAt'] is! String) {
      throw const FormatException('Invalid person topic');
    }
    final createdAt = DateTime.tryParse(json['createdAt'] as String);
    if (createdAt == null) throw const FormatException('Invalid createdAt');
    return PersonTopic(
      personId: json['personId'] as String,
      topicId: json['topicId'] as String,
      note: json['note'] as String,
      createdAt: createdAt,
    );
  }
}
