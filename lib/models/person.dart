enum PersonRelationship {
  friend('友人'),
  colleague('同僚'),
  supervisor('上司'),
  junior('後輩'),
  family('家族'),
  partner('恋人'),
  firstMeeting('初対面'),
  other('その他');

  const PersonRelationship(this.label);

  final String label;
}

enum PersonCloseness {
  newlyMet('知り合ったばかり'),
  acquaintance('顔見知り'),
  casual('気軽に話せる'),
  close('親しい');

  const PersonCloseness(this.label);

  final String label;
}

enum PersonAgeGroup {
  teens('10代'),
  twenties('20代'),
  thirties('30代'),
  forties('40代'),
  fifties('50代'),
  sixtiesOrOlder('60代以上');

  const PersonAgeGroup(this.label);

  final String label;
}

/// Optional information that helps tailor conversation suggestions to a person.
class PersonProfile {
  const PersonProfile({
    this.relationship,
    this.closeness,
    this.ageGroup,
    this.interests = '',
    this.workOrSchool = '',
    this.recentEvents = '',
    this.likelyInterests = '',
    this.commonTopics = '',
    this.topicsToAvoid = '',
    this.nextQuestions = '',
  });

  final PersonRelationship? relationship;
  final PersonCloseness? closeness;
  final PersonAgeGroup? ageGroup;
  final String interests;
  final String workOrSchool;
  final String recentEvents;
  final String likelyInterests;
  final String commonTopics;
  final String topicsToAvoid;
  final String nextQuestions;

  bool get isEmpty => orderedEntries.isEmpty;

  PersonProfile copyWith({
    PersonRelationship? relationship,
    bool clearRelationship = false,
    PersonCloseness? closeness,
    bool clearCloseness = false,
    PersonAgeGroup? ageGroup,
    bool clearAgeGroup = false,
    String? interests,
    String? workOrSchool,
    String? recentEvents,
    String? likelyInterests,
    String? commonTopics,
    String? topicsToAvoid,
    String? nextQuestions,
  }) => PersonProfile(
    relationship: clearRelationship ? null : relationship ?? this.relationship,
    closeness: clearCloseness ? null : closeness ?? this.closeness,
    ageGroup: clearAgeGroup ? null : ageGroup ?? this.ageGroup,
    interests: interests ?? this.interests,
    workOrSchool: workOrSchool ?? this.workOrSchool,
    recentEvents: recentEvents ?? this.recentEvents,
    likelyInterests: likelyInterests ?? this.likelyInterests,
    commonTopics: commonTopics ?? this.commonTopics,
    topicsToAvoid: topicsToAvoid ?? this.topicsToAvoid,
    nextQuestions: nextQuestions ?? this.nextQuestions,
  );

  /// Removes incidental input whitespace before storing or using this profile.
  PersonProfile normalized() => PersonProfile(
    relationship: relationship,
    closeness: closeness,
    ageGroup: ageGroup,
    interests: interests.trim(),
    workOrSchool: workOrSchool.trim(),
    recentEvents: recentEvents.trim(),
    likelyInterests: likelyInterests.trim(),
    commonTopics: commonTopics.trim(),
    topicsToAvoid: topicsToAvoid.trim(),
    nextQuestions: nextQuestions.trim(),
  );

  /// Ordered, non-empty labels and values suitable for an AI input prompt.
  List<MapEntry<String, String>> get orderedEntries {
    final profile = normalized();
    return <MapEntry<String, String>>[
      if (profile.relationship != null)
        MapEntry('関係性', profile.relationship!.label),
      if (profile.closeness != null) MapEntry('親密度', profile.closeness!.label),
      if (profile.ageGroup != null) MapEntry('年代', profile.ageGroup!.label),
      if (profile.interests.isNotEmpty) MapEntry('趣味・好きなもの', profile.interests),
      if (profile.workOrSchool.isNotEmpty)
        MapEntry('仕事・学校', profile.workOrSchool),
      if (profile.recentEvents.isNotEmpty)
        MapEntry('最近の出来事', profile.recentEvents),
      if (profile.likelyInterests.isNotEmpty)
        MapEntry('興味がありそうなこと', profile.likelyInterests),
      if (profile.commonTopics.isNotEmpty)
        MapEntry('よく話すこと', profile.commonTopics),
      if (profile.nextQuestions.isNotEmpty)
        MapEntry('次に聞きたいこと', profile.nextQuestions),
      if (profile.topicsToAvoid.isNotEmpty)
        MapEntry('避けたい話題', profile.topicsToAvoid),
    ];
  }

  Map<String, String> toStructuredMap() =>
      Map<String, String>.fromEntries(orderedEntries);

  Map<String, dynamic> toJson() {
    final profile = normalized();
    return <String, dynamic>{
      'relationship': profile.relationship?.name,
      'closeness': profile.closeness?.name,
      'ageGroup': profile.ageGroup?.name,
      'interests': profile.interests,
      'workOrSchool': profile.workOrSchool,
      'recentEvents': profile.recentEvents,
      'likelyInterests': profile.likelyInterests,
      'commonTopics': profile.commonTopics,
      'topicsToAvoid': profile.topicsToAvoid,
      'nextQuestions': profile.nextQuestions,
    };
  }

  factory PersonProfile.fromJson(Map<String, dynamic> json) {
    const keys = <String>{
      'relationship',
      'closeness',
      'ageGroup',
      'interests',
      'workOrSchool',
      'recentEvents',
      'likelyInterests',
      'commonTopics',
      'topicsToAvoid',
      'nextQuestions',
    };
    if (json.length != keys.length ||
        json.keys.any((key) => !keys.contains(key)) ||
        !_nullableEnum(json['relationship'], PersonRelationship.values) ||
        !_nullableEnum(json['closeness'], PersonCloseness.values) ||
        !_nullableEnum(json['ageGroup'], PersonAgeGroup.values) ||
        <Object?>[
          json['interests'],
          json['workOrSchool'],
          json['recentEvents'],
          json['likelyInterests'],
          json['commonTopics'],
          json['topicsToAvoid'],
          json['nextQuestions'],
        ].any((value) => value is! String)) {
      throw const FormatException('Invalid person profile');
    }
    return PersonProfile(
      relationship: _enumByName(
        json['relationship'],
        PersonRelationship.values,
      ),
      closeness: _enumByName(json['closeness'], PersonCloseness.values),
      ageGroup: _enumByName(json['ageGroup'], PersonAgeGroup.values),
      interests: json['interests'] as String,
      workOrSchool: json['workOrSchool'] as String,
      recentEvents: json['recentEvents'] as String,
      likelyInterests: json['likelyInterests'] as String,
      commonTopics: json['commonTopics'] as String,
      topicsToAvoid: json['topicsToAvoid'] as String,
      nextQuestions: json['nextQuestions'] as String,
    ).normalized();
  }

  static bool _nullableEnum<T extends Enum>(Object? value, List<T> values) =>
      value == null ||
      (value is String && values.any((item) => item.name == value));

  static T? _enumByName<T extends Enum>(Object? value, List<T> values) {
    if (value == null) return null;
    return values.firstWhere((item) => item.name == value);
  }
}

class Person {
  const Person({
    required this.id,
    required this.displayName,
    required this.note,
    required this.createdAt,
    this.profile = const PersonProfile(),
  });

  final String id;
  final String displayName;
  final String note;
  final DateTime createdAt;
  final PersonProfile profile;

  /// Structured non-empty profile values for conversation suggestion inputs.
  Map<String, String> get structuredProfile => profile.toStructuredMap();

  Person copyWith({
    String? displayName,
    String? note,
    PersonProfile? profile,
  }) => Person(
    id: id,
    displayName: displayName ?? this.displayName,
    note: note ?? this.note,
    createdAt: createdAt,
    profile: profile ?? this.profile,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'displayName': displayName,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
    'profile': profile.toJson(),
  };

  factory Person.fromJson(Map<String, dynamic> json) {
    const keys = <String>{'id', 'displayName', 'note', 'createdAt', 'profile'};
    if (json.length != keys.length ||
        json.keys.any((key) => !keys.contains(key)) ||
        json['id'] is! String ||
        json['displayName'] is! String ||
        json['note'] is! String ||
        json['createdAt'] is! String ||
        json['profile'] is! Map) {
      throw const FormatException('Invalid person');
    }
    final createdAt = DateTime.tryParse(json['createdAt'] as String);
    if (createdAt == null) throw const FormatException('Invalid createdAt');
    return Person(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      note: json['note'] as String,
      createdAt: createdAt,
      profile: PersonProfile.fromJson(
        Map<String, dynamic>.from(json['profile'] as Map),
      ),
    );
  }

  /// v2/v3 persisted people did not include a profile.
  factory Person.fromLegacyJson(Map<String, dynamic> json) {
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
