class Person {
  const Person({
    required this.id,
    required this.displayName,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String displayName;
  final String note;
  final DateTime createdAt;

  Person copyWith({String? displayName, String? note}) => Person(
    id: id,
    displayName: displayName ?? this.displayName,
    note: note ?? this.note,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'displayName': displayName,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Person.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! String ||
        json['displayName'] is! String ||
        json['note'] is! String ||
        json['createdAt'] is! String) {
      throw const FormatException('Invalid person');
    }
    final createdAt = DateTime.tryParse(json['createdAt'] as String);
    if (createdAt == null) throw const FormatException('Invalid createdAt');
    return Person(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      note: json['note'] as String,
      createdAt: createdAt,
    );
  }
}
