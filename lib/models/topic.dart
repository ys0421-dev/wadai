enum TopicSource { builtIn, userCreated }

/// A reusable conversation topic. Favorite and archive state deliberately live
/// outside this value object so one Topic can be shared by many people.
class Topic {
  const Topic({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.source,
    this.description = '',
    this.createdAt,
  });

  final String id;
  final String title;
  final String categoryId;
  final String description;
  final TopicSource source;
  final DateTime? createdAt;

  bool get isCustom => source == TopicSource.userCreated;

  Topic copyWith({String? title, String? categoryId, String? description}) =>
      Topic(
        id: id,
        title: title ?? this.title,
        categoryId: categoryId ?? this.categoryId,
        description: description ?? this.description,
        source: source,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'categoryId': categoryId,
    'description': description,
    'source': source.name,
    'createdAt': createdAt?.toIso8601String(),
  };

  factory Topic.fromJson(Map<String, dynamic> json) {
    final sourceName = json['source'];
    if (sourceName is! String) throw const FormatException('Invalid source');
    final source = TopicSource.values.where(
      (value) => value.name == sourceName,
    );
    if (source.length != 1) throw const FormatException('Invalid source');
    final createdAt = json['createdAt'];
    if (createdAt != null && createdAt is! String) {
      throw const FormatException('Invalid createdAt');
    }
    final parsedCreatedAt = createdAt == null
        ? null
        : DateTime.tryParse(createdAt);
    if (createdAt != null && parsedCreatedAt == null) {
      throw const FormatException('Invalid createdAt');
    }
    if (json['id'] is! String ||
        json['title'] is! String ||
        json['categoryId'] is! String ||
        json['description'] is! String) {
      throw const FormatException('Invalid topic');
    }
    return Topic(
      id: json['id'] as String,
      title: json['title'] as String,
      categoryId: json['categoryId'] as String,
      description: json['description'] as String,
      source: source.single,
      createdAt: parsedCreatedAt,
    );
  }

  /// Reads the Phase 1–3 custom-topic representation.
  factory Topic.fromLegacyJson(Map<String, dynamic> json) {
    final createdAt = json['createdAt'];
    if (createdAt != null && createdAt is! String) {
      throw const FormatException('Invalid createdAt');
    }
    final parsedCreatedAt = createdAt == null
        ? null
        : DateTime.tryParse(createdAt);
    if (createdAt != null && parsedCreatedAt == null) {
      throw const FormatException('Invalid createdAt');
    }
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
    return Topic(
      id: json['id'] as String,
      title: json['title'] as String,
      categoryId: json['categoryId'] as String,
      description: json['description'] as String? ?? '',
      source: TopicSource.userCreated,
      createdAt: parsedCreatedAt,
    );
  }
}
