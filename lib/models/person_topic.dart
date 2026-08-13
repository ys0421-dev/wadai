enum PersonTopicStatus {
  planned('これから話す'),
  discussed('話した'),
  revisit('また話す');

  const PersonTopicStatus(this.label);
  final String label;
}

class PersonTopic {
  const PersonTopic({
    required this.personId,
    required this.topicId,
    required this.note,
    required this.createdAt,
    this.status = PersonTopicStatus.planned,
  });

  final String personId;
  final String topicId;
  final String note;
  final DateTime createdAt;
  final PersonTopicStatus status;

  String get pairKey => '$personId\u0000$topicId';

  PersonTopic copyWith({String? note, PersonTopicStatus? status}) =>
      PersonTopic(
        personId: personId,
        topicId: topicId,
        note: note ?? this.note,
        createdAt: createdAt,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'personId': personId,
    'topicId': topicId,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
  };

  factory PersonTopic.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'];
    if (statusName is! String) {
      throw const FormatException('Invalid person topic');
    }
    final statuses = PersonTopicStatus.values.where(
      (status) => status.name == statusName,
    );
    if (statuses.length != 1) {
      throw const FormatException('Invalid person topic');
    }
    return _fromJson(json, statuses.single);
  }

  factory PersonTopic.fromV2Json(Map<String, dynamic> json) =>
      _fromJson(json, PersonTopicStatus.planned);

  static PersonTopic _fromJson(
    Map<String, dynamic> json,
    PersonTopicStatus status,
  ) {
    if (json['personId'] is! String ||
        json['topicId'] is! String ||
        json['note'] is! String ||
        json['createdAt'] is! String) {
      throw const FormatException('Invalid person topic');
    }
    final createdAt = DateTime.tryParse(json['createdAt'] as String);
    if (createdAt == null) {
      throw const FormatException('Invalid person topic');
    }
    return PersonTopic(
      personId: json['personId'] as String,
      topicId: json['topicId'] as String,
      note: json['note'] as String,
      createdAt: createdAt,
      status: status,
    );
  }
}
