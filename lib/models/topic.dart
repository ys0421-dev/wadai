import 'dart:collection';

enum TopicSource { builtIn, userCreated }

/// A reusable unit of conversation. Favorite and archive state deliberately
/// live outside this value object so one Topic can be shared by many people.
class Topic {
  Topic({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.source,
    this.openingQuestion = '',
    List<String> talkingPoints = const <String>[],
    this.note = '',
    this.createdAt,
  }) : _talkingPoints = UnmodifiableListView<String>(
         List<String>.from(talkingPoints),
       );

  final String id;
  final String title;
  final String categoryId;
  final String openingQuestion;
  final List<String> _talkingPoints;
  final String note;
  final TopicSource source;
  final DateTime? createdAt;

  /// Never exposes the internally held mutable list.
  List<String> get talkingPoints => List.unmodifiable(_talkingPoints);

  bool get isCustom => source == TopicSource.userCreated;

  Topic copyWith({
    String? title,
    String? categoryId,
    String? openingQuestion,
    List<String>? talkingPoints,
    String? note,
  }) => Topic(
    id: id,
    title: title ?? this.title,
    categoryId: categoryId ?? this.categoryId,
    openingQuestion: openingQuestion ?? this.openingQuestion,
    talkingPoints: talkingPoints ?? _talkingPoints,
    note: note ?? this.note,
    source: source,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'categoryId': categoryId,
    'openingQuestion': openingQuestion,
    'talkingPoints': List<String>.from(_talkingPoints),
    'note': note,
    'source': source.name,
    'createdAt': createdAt?.toIso8601String(),
  };

  factory Topic.fromJson(Map<String, dynamic> json) {
    const keys = <String>{
      'id',
      'title',
      'categoryId',
      'openingQuestion',
      'talkingPoints',
      'note',
      'source',
      'createdAt',
    };
    if (json.length != keys.length ||
        json.keys.any((key) => !keys.contains(key)) ||
        json['id'] is! String ||
        json['title'] is! String ||
        json['categoryId'] is! String ||
        json['openingQuestion'] is! String ||
        json['note'] is! String ||
        json['source'] is! String ||
        json['talkingPoints'] is! List ||
        (json['talkingPoints'] as List).any((value) => value is! String)) {
      throw const FormatException('Invalid topic');
    }
    final source = _sourceFromName(json['source'] as String);
    final createdAt = _parseCreatedAt(json['createdAt']);
    return Topic(
      id: json['id'] as String,
      title: json['title'] as String,
      categoryId: json['categoryId'] as String,
      openingQuestion: json['openingQuestion'] as String,
      talkingPoints: (json['talkingPoints'] as List).cast<String>(),
      note: json['note'] as String,
      source: source,
      createdAt: createdAt,
    );
  }

  /// Reads schemas up through v4 and preserves their description as note.
  factory Topic.fromV4Json(Map<String, dynamic> json) {
    if (json['id'] is! String ||
        json['title'] is! String ||
        json['categoryId'] is! String ||
        json['description'] is! String ||
        json['source'] is! String) {
      throw const FormatException('Invalid v4 topic');
    }
    final title = json['title'] as String;
    return Topic(
      id: json['id'] as String,
      title: title,
      categoryId: json['categoryId'] as String,
      openingQuestion: fallbackOpeningQuestion(title),
      note: json['description'] as String,
      source: _sourceFromName(json['source'] as String),
      createdAt: _parseCreatedAt(json['createdAt']),
    );
  }

  /// Reads the Phase 1–3 custom-topic representation.
  factory Topic.fromLegacyJson(Map<String, dynamic> json) {
    if (json['id'] is! String ||
        json['title'] is! String ||
        json['categoryId'] is! String ||
        (json['description'] != null && json['description'] is! String) ||
        (json['isCustom'] != null && json['isCustom'] is! bool)) {
      throw const FormatException('Invalid legacy topic');
    }
    if (json['isCustom'] == false) {
      throw const FormatException('Not a custom topic');
    }
    final title = json['title'] as String;
    return Topic(
      id: json['id'] as String,
      title: title,
      categoryId: json['categoryId'] as String,
      openingQuestion: fallbackOpeningQuestion(title),
      note: json['description'] as String? ?? '',
      source: TopicSource.userCreated,
      createdAt: _parseCreatedAt(json['createdAt']),
    );
  }

  static String fallbackOpeningQuestion(String title) =>
      '「${title.trim()}」について、どう思いますか？';

  static TopicSource _sourceFromName(String name) {
    for (final source in TopicSource.values) {
      if (source.name == name) return source;
    }
    throw const FormatException('Invalid source');
  }

  static DateTime? _parseCreatedAt(Object? value) {
    if (value != null && value is! String) {
      throw const FormatException('Invalid createdAt');
    }
    final parsed = value == null ? null : DateTime.tryParse(value as String);
    if (value != null && parsed == null) {
      throw const FormatException('Invalid createdAt');
    }
    return parsed;
  }
}
