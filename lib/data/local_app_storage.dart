import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/person.dart';
import '../models/person_topic.dart';
import '../models/topic.dart';
import 'topic_catalog.dart';

class StorageFormatException implements Exception {
  const StorageFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The whole mutable application state. Built-in topics are intentionally not
/// serialized: their IDs are the durable reference used by the saved sets.
class LocalAppData {
  const LocalAppData({
    required this.customTopics,
    required this.favoriteIds,
    required this.archivedIds,
    required this.persons,
    required this.personTopics,
    required this.needsMigration,
  });

  final List<Topic> customTopics;
  final Set<String> favoriteIds;
  final Set<String> archivedIds;
  final List<Person> persons;
  final List<PersonTopic> personTopics;
  final bool needsMigration;

  factory LocalAppData.empty() => const LocalAppData(
    customTopics: <Topic>[],
    favoriteIds: <String>{},
    archivedIds: <String>{},
    persons: <Person>[],
    personTopics: <PersonTopic>[],
    needsMigration: false,
  );
}

class LocalAppStorage {
  static const snapshotKey = 'wadee_app_data';
  static const customTopicsKey = 'custom_topics';
  static const favoriteIdsKey = 'favorite_topic_ids';
  static const schemaVersion = 6;

  Future<LocalAppData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final snapshot = prefs.getString(snapshotKey);
    if (snapshot != null) return _parseSnapshot(snapshot);

    final legacyTopics = prefs.getString(customTopicsKey);
    final legacyFavorites = prefs.getStringList(favoriteIdsKey);
    if (legacyTopics == null && legacyFavorites == null) {
      return LocalAppData.empty();
    }
    final topics = legacyTopics == null
        ? <Topic>[]
        : _parseLegacyTopics(jsonDecode(legacyTopics));
    final favorites = legacyFavorites == null
        ? _legacyEmbeddedFavoriteIds(legacyTopics)
        : legacyFavorites
              .map((id) => legacyStaticTopicIdToBuiltinId[id] ?? id)
              .toSet();
    final data = LocalAppData(
      customTopics: topics,
      favoriteIds: favorites,
      archivedIds: <String>{},
      persons: const <Person>[],
      personTopics: const <PersonTopic>[],
      needsMigration: true,
    );
    _validate(data);
    return data;
  }

  Future<void> saveSnapshot({
    required List<Topic> customTopics,
    required Iterable<String> favoriteIds,
    required Iterable<String> archivedIds,
    required List<Person> persons,
    required List<PersonTopic> personTopics,
  }) async {
    final data = LocalAppData(
      customTopics: List<Topic>.unmodifiable(customTopics),
      favoriteIds: Set<String>.from(favoriteIds),
      archivedIds: Set<String>.from(archivedIds),
      persons: List<Person>.unmodifiable(persons),
      personTopics: List<PersonTopic>.unmodifiable(personTopics),
      needsMigration: false,
    );
    _validate(data);
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(
      snapshotKey,
      jsonEncode(<String, Object>{
        'schemaVersion': schemaVersion,
        'customTopics': data.customTopics
            .map((topic) => topic.toJson())
            .toList(),
        'favoriteTopicIds': data.favoriteIds.toList(),
        'archivedTopicIds': data.archivedIds.toList(),
        'persons': data.persons.map((person) => person.toJson()).toList(),
        'personTopics': data.personTopics.map((item) => item.toJson()).toList(),
      }),
    );
    if (!saved) throw const StorageFormatException('Failed to save data');
  }

  LocalAppData _parseSnapshot(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const StorageFormatException('Invalid snapshot');
      }
      final map = Map<String, dynamic>.from(decoded);
      final version = map['schemaVersion'];
      if (version is! int) {
        throw const StorageFormatException('Invalid version');
      }
      if (version == schemaVersion) return _parseV6(map);
      if (version == 5) return _parseV5(map);
      if (version == 4) return _parseV4(map);
      if (version == 3) return _parseV3(map);
      if (version == 2) return _parseV2(map);
      if (version == 1) return _parseV1(map);
      throw const StorageFormatException('Unsupported version');
    } on StorageFormatException {
      rethrow;
    } catch (_) {
      throw const StorageFormatException('Invalid snapshot');
    }
  }

  LocalAppData _parseV6(Map<String, dynamic> map) {
    final data = LocalAppData(
      customTopics: _parseCurrentTopics(map['customTopics']),
      favoriteIds: _parseIds(map['favoriteTopicIds']),
      archivedIds: _parseIds(map['archivedTopicIds']),
      persons: _parsePersons(map['persons']),
      personTopics: _parsePersonTopics(map['personTopics']),
      needsMigration: false,
    );
    _validate(data);
    return data;
  }

  LocalAppData _parseV5(Map<String, dynamic> map) {
    final data = LocalAppData(
      customTopics: _parseV5Topics(map['customTopics']),
      favoriteIds: _parseIds(map['favoriteTopicIds']),
      archivedIds: _parseIds(map['archivedTopicIds']),
      persons: _parsePersons(map['persons']),
      personTopics: _parsePersonTopics(map['personTopics']),
      needsMigration: true,
    );
    _validate(data);
    return data;
  }

  /// v4 already has PersonProfile, but its topics use description instead of
  /// an opening question, talking points and note.
  LocalAppData _parseV4(Map<String, dynamic> map) {
    final data = LocalAppData(
      customTopics: _parseV4Topics(map['customTopics']),
      favoriteIds: _parseIds(map['favoriteTopicIds']),
      archivedIds: _parseIds(map['archivedTopicIds']),
      persons: _parsePersons(map['persons']),
      personTopics: _parsePersonTopics(map['personTopics']),
      needsMigration: true,
    );
    _validate(data);
    return data;
  }

  /// v3 has the current topic relation status but people have no profile.
  LocalAppData _parseV3(Map<String, dynamic> map) {
    final data = LocalAppData(
      customTopics: _parseV4Topics(map['customTopics']),
      favoriteIds: _parseIds(map['favoriteTopicIds']),
      archivedIds: _parseIds(map['archivedTopicIds']),
      persons: _parseLegacyPersons(map['persons']),
      personTopics: _parsePersonTopics(map['personTopics']),
      needsMigration: true,
    );
    _validate(data);
    return data;
  }

  LocalAppData _parseV2(Map<String, dynamic> map) {
    final data = LocalAppData(
      customTopics: _parseV4Topics(map['customTopics']),
      favoriteIds: _parseIds(map['favoriteTopicIds']),
      archivedIds: _parseIds(map['archivedTopicIds']),
      persons: _parseLegacyPersons(map['persons']),
      personTopics: _parseV2PersonTopics(map['personTopics']),
      needsMigration: true,
    );
    _validate(data);
    return data;
  }

  LocalAppData _parseV1(Map<String, dynamic> map) {
    final data = LocalAppData(
      customTopics: _parseLegacyTopics(map['customTopics']),
      favoriteIds: _parseIds(map['favoriteTopicIds']),
      archivedIds: <String>{},
      persons: const <Person>[],
      personTopics: const <PersonTopic>[],
      needsMigration: true,
    );
    _validate(data);
    return data;
  }

  List<Topic> _parseCurrentTopics(Object? value) => _parseList<Topic>(
    value,
    (item) => Topic.fromJson(item),
    'Invalid custom topics',
  );

  List<Topic> _parseV5Topics(Object? value) =>
      _parseList<Topic>(value, Topic.fromV5Json, 'Invalid v5 custom topics');

  List<Topic> _parseV4Topics(Object? value) =>
      _parseList<Topic>(value, Topic.fromV4Json, 'Invalid custom topics');

  List<Topic> _parseLegacyTopics(Object? value) => _parseList<Topic>(
    value,
    (item) => Topic.fromLegacyJson(item),
    'Invalid legacy custom topics',
  );

  List<Person> _parsePersons(Object? value) =>
      _parseList<Person>(value, Person.fromJson, 'Invalid persons');

  List<Person> _parseLegacyPersons(Object? value) =>
      _parseList<Person>(value, Person.fromLegacyJson, 'Invalid persons');

  List<PersonTopic> _parsePersonTopics(Object? value) =>
      _parseList<PersonTopic>(
        value,
        PersonTopic.fromJson,
        'Invalid person topics',
      );

  List<PersonTopic> _parseV2PersonTopics(Object? value) =>
      _parseList<PersonTopic>(
        value,
        PersonTopic.fromV2Json,
        'Invalid person topics',
      );

  List<T> _parseList<T>(
    Object? value,
    T Function(Map<String, dynamic>) parser,
    String message,
  ) {
    if (value is! List) throw StorageFormatException(message);
    try {
      return value
          .map((item) {
            if (item is! Map) throw StorageFormatException(message);
            return parser(Map<String, dynamic>.from(item));
          })
          .toList(growable: false);
    } on StorageFormatException {
      rethrow;
    } catch (_) {
      throw StorageFormatException(message);
    }
  }

  Set<String> _parseIds(Object? value) {
    if (value is! List || value.any((id) => id is! String)) {
      throw const StorageFormatException('Invalid ID list');
    }
    return value.cast<String>().toSet();
  }

  Set<String> _legacyEmbeddedFavoriteIds(String? rawTopics) {
    if (rawTopics == null) return <String>{};
    final decoded = jsonDecode(rawTopics);
    if (decoded is! List) {
      throw const StorageFormatException('Invalid legacy topics');
    }
    try {
      return decoded
          .whereType<Map>()
          .where((item) => item['isFavorite'] == true)
          .map((item) => item['id'])
          .whereType<String>()
          .toSet();
    } catch (_) {
      throw const StorageFormatException('Invalid legacy topics');
    }
  }

  void _validate(LocalAppData data) {
    final builtinIds = createStaticTopics().map((topic) => topic.id).toSet();
    final customIds = <String>{};
    for (final topic in data.customTopics) {
      if (topic.source == TopicSource.builtIn ||
          topic.id.isEmpty ||
          topic.title.trim().isEmpty ||
          topic.openingQuestion.trim().isEmpty ||
          !customIds.add(topic.id) ||
          builtinIds.contains(topic.id)) {
        throw const StorageFormatException('Invalid custom topics');
      }
    }
    final personIds = <String>{};
    for (final person in data.persons) {
      if (person.id.isEmpty ||
          person.displayName.trim().isEmpty ||
          !personIds.add(person.id)) {
        throw const StorageFormatException('Invalid persons');
      }
    }
    final knownTopics = <String>{...builtinIds, ...customIds};
    final personTopicsByTopic = <String, Set<String>>{};
    final pairs = <String>{};
    for (final personTopic in data.personTopics) {
      if (!personIds.contains(personTopic.personId) ||
          !knownTopics.contains(personTopic.topicId) ||
          !pairs.add(personTopic.pairKey)) {
        throw const StorageFormatException('Invalid person topics');
      }
      personTopicsByTopic
          .putIfAbsent(personTopic.topicId, () => <String>{})
          .add(personTopic.personId);
    }
    for (final topic in data.customTopics) {
      if ((topic.scope == TopicScope.global && topic.ownerPersonId != null) ||
          (topic.scope == TopicScope.person &&
              (!personIds.contains(topic.ownerPersonId) ||
                  personTopicsByTopic[topic.id]?.length != 1 ||
                  !personTopicsByTopic[topic.id]!.contains(
                    topic.ownerPersonId,
                  )))) {
        throw const StorageFormatException('Invalid topic scope');
      }
    }
    for (final id in data.favoriteIds) {
      Topic? topic;
      for (final candidate in data.customTopics) {
        if (candidate.id == id) {
          topic = candidate;
          break;
        }
      }
      if (topic != null && topic.scope == TopicScope.person) {
        throw const StorageFormatException('Person topic cannot be favorite');
      }
    }
  }
}
