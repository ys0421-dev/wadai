import 'dart:collection';

enum TopicSource { builtIn, userCreated, aiGenerated }

enum TopicScope { global, person }

/// A reusable unit of conversation. Favorite and archive state deliberately
/// live outside this value object so one Topic can be shared by many people.
class Topic {
  Topic({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.source,
    this.scope = TopicScope.global,
    this.ownerPersonId,
    this.openingQuestion = '',
    List<String> talkingPoints = const <String>[],
    this.note = '',
    this.createdAt,
  }) : _talkingPoints = UnmodifiableListView<String>(
         List<String>.from(talkingPoints),
       ) {
    if ((scope == TopicScope.global && ownerPersonId != null) ||
        (scope == TopicScope.person &&
            (ownerPersonId == null || ownerPersonId!.trim().isEmpty)) ||
        (source == TopicSource.builtIn &&
            (scope != TopicScope.global || ownerPersonId != null))) {
      throw ArgumentError('Invalid topic scope');
    }
  }

  final String id;
  final String title;
  final String categoryId;
  final String openingQuestion;
  final List<String> _talkingPoints;
  final String note;
  final TopicSource source;
  final TopicScope scope;
  final String? ownerPersonId;
  final DateTime? createdAt;

  /// Never exposes the internally held mutable list.
  List<String> get talkingPoints => List.unmodifiable(_talkingPoints);

  bool get isCustom => source == TopicSource.userCreated;
  bool get isPersonScoped => scope == TopicScope.person;

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
    scope: scope,
    ownerPersonId: ownerPersonId,
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
    'scope': scope.name,
    'ownerPersonId': ownerPersonId,
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
      'scope',
      'ownerPersonId',
    };
    if (json.length != keys.length ||
        json.keys.any((key) => !keys.contains(key)) ||
        json['id'] is! String ||
        json['title'] is! String ||
        json['categoryId'] is! String ||
        json['openingQuestion'] is! String ||
        json['note'] is! String ||
        json['source'] is! String ||
        json['scope'] is! String ||
        json['talkingPoints'] is! List ||
        (json['talkingPoints'] as List).any((value) => value is! String)) {
      throw const FormatException('Invalid topic');
    }
    final source = _sourceFromName(json['source'] as String);
    final scope = _scopeFromName(json['scope'] as String);
    final ownerPersonId = json['ownerPersonId'];
    if (ownerPersonId != null && ownerPersonId is! String) {
      throw const FormatException('Invalid ownerPersonId');
    }
    final createdAt = _parseCreatedAt(json['createdAt']);
    return Topic(
      id: json['id'] as String,
      title: json['title'] as String,
      categoryId: json['categoryId'] as String,
      openingQuestion: json['openingQuestion'] as String,
      talkingPoints: (json['talkingPoints'] as List).cast<String>(),
      note: json['note'] as String,
      source: source,
      scope: scope,
      ownerPersonId: ownerPersonId as String?,
      createdAt: createdAt,
    );
  }

  /// Reads the v5 conversation-topic representation as a global topic.
  factory Topic.fromV5Json(Map<String, dynamic> json) {
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
        json.keys.any((key) => !keys.contains(key))) {
      throw const FormatException('Invalid v5 topic');
    }
    final topic = Topic.fromJson(<String, dynamic>{
      ...json,
      'scope': TopicScope.global.name,
      'ownerPersonId': null,
    });
    if (topic.source == TopicSource.aiGenerated) {
      throw const FormatException('Invalid v5 source');
    }
    return topic;
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
    final source = _sourceFromName(json['source'] as String);
    if (source != TopicSource.userCreated) {
      throw const FormatException('Invalid v4 source');
    }
    return Topic(
      id: json['id'] as String,
      title: title,
      categoryId: json['categoryId'] as String,
      openingQuestion: fallbackOpeningQuestion(title),
      note: json['description'] as String,
      source: source,
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

  static TopicScope _scopeFromName(String name) {
    for (final scope in TopicScope.values) {
      if (scope.name == name) return scope;
    }
    throw const FormatException('Invalid scope');
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
