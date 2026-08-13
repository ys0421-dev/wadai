import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;

import '../data/topic_catalog.dart';
import '../data/local_app_storage.dart';
import '../models/category.dart';
import '../models/person.dart';
import '../models/person_topic.dart';
import '../models/topic.dart';

enum AppLoadState { initial, loading, ready, error }

class WadeeController extends ChangeNotifier {
  WadeeController({LocalAppStorage? storage})
    : _storage = storage ?? LocalAppStorage();

  final LocalAppStorage _storage;
  List<Topic> _allTopics = createStaticTopics();
  Set<String> _favoriteIds = <String>{};
  Set<String> _archivedIds = <String>{};
  List<Person> _persons = <Person>[];
  List<PersonTopic> _personTopics = <PersonTopic>[];
  Future<void> _writeQueue = Future<void>.value();
  AppLoadState loadState = AppLoadState.initial;
  String? lastError;

  List<Topic> get topics => List.unmodifiable(
    _allTopics.where((topic) => !_archivedIds.contains(topic.id)),
  );
  List<Topic> get allTopicsIncludingArchived => List.unmodifiable(_allTopics);
  List<Topic> get customTopics => List.unmodifiable(
    topics.where((topic) => topic.source == TopicSource.userCreated),
  );
  List<Topic> get favoriteTopics => List.unmodifiable(
    topics.where((topic) => _favoriteIds.contains(topic.id)),
  );
  List<Person> get persons => List.unmodifiable(_persons);
  List<PersonTopic> get personTopics => List.unmodifiable(_personTopics);
  Set<String> get favoriteTopicIds => Set.unmodifiable(_favoriteIds);
  Set<String> get archivedTopicIds => Set.unmodifiable(_archivedIds);

  bool isFavorite(String topicId) => _favoriteIds.contains(topicId);
  bool isArchived(String topicId) => _archivedIds.contains(topicId);

  Topic? topicById(String id) {
    if (_archivedIds.contains(id)) return null;
    return _topicByIdIncludingArchived(id);
  }

  Topic? topicByIdIncludingArchived(String id) =>
      _topicByIdIncludingArchived(id);

  Person? personById(String id) {
    for (final person in _persons) {
      if (person.id == id) return person;
    }
    return null;
  }

  List<PersonTopic> personTopicsFor(String personId) => List.unmodifiable(
    _personTopics.where((item) => item.personId == personId),
  );

  PersonTopic? personTopic(String personId, String topicId) {
    for (final item in _personTopics) {
      if (item.personId == personId && item.topicId == topicId) return item;
    }
    return null;
  }

  String categoryName(String categoryId) => categories
      .firstWhere(
        (category) => category.id == categoryId,
        orElse: () => const Category(id: 'unknown', name: 'その他'),
      )
      .name;

  Future<void> load() async {
    if (loadState == AppLoadState.loading || loadState == AppLoadState.ready) {
      return;
    }
    loadState = AppLoadState.loading;
    lastError = null;
    notifyListeners();
    try {
      final data = await _storage.load();
      if (data.needsMigration) await _save(data);
      _commit(_AppState.fromData(data));
      loadState = AppLoadState.ready;
      lastError = null;
    } catch (_) {
      loadState = AppLoadState.error;
      lastError = 'データを読み込めませんでした。再試行してください。';
    }
    notifyListeners();
  }

  Future<bool> toggleFavorite(String id) => _enqueueMutation((state) {
    if (!state.hasActiveTopic(id)) return null;
    final candidate = state.copy();
    if (!candidate.favoriteIds.add(id)) candidate.favoriteIds.remove(id);
    return candidate;
  });

  Future<bool> addTopic({
    required String title,
    required String categoryId,
    required String description,
  }) => _enqueueMutation((state) {
    final candidate = state.copy();
    final now = DateTime.now();
    candidate.allTopics.add(
      Topic(
        id: _nextId('custom', candidate, now),
        title: title,
        categoryId: categoryId,
        description: description,
        source: TopicSource.userCreated,
        createdAt: now,
      ),
    );
    return candidate;
  });

  Future<bool> updateTopic({
    required String id,
    required String title,
    required String categoryId,
    required String description,
  }) => _enqueueMutation((state) {
    final index = state.allTopics.indexWhere((topic) => topic.id == id);
    if (index == -1 ||
        state.archivedIds.contains(id) ||
        state.allTopics[index].source != TopicSource.userCreated) {
      return null;
    }
    final candidate = state.copy();
    candidate.allTopics[index] = candidate.allTopics[index].copyWith(
      title: title,
      categoryId: categoryId,
      description: description,
    );
    return candidate;
  });

  Future<bool> archiveTopic(String id) => _enqueueMutation((state) {
    if (!state.hasTopic(id) || state.archivedIds.contains(id)) return null;
    final candidate = state.copy()..archivedIds.add(id);
    return candidate;
  });

  Future<bool> restoreTopic(String id) => _enqueueMutation((state) {
    if (!state.hasTopic(id) || !state.archivedIds.contains(id)) return null;
    final candidate = state.copy()..archivedIds.remove(id);
    return candidate;
  });

  Future<String?> addPerson({required String displayName, String note = ''}) {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty || loadState != AppLoadState.ready) {
      return Future<String?>.value(null);
    }
    return _enqueueValueMutation<String>((state) {
      final candidate = state.copy();
      final now = DateTime.now();
      final id = _nextId('person', candidate, now);
      candidate.persons.add(
        Person(id: id, displayName: trimmed, note: note, createdAt: now),
      );
      return _ValueCandidate<String>(candidate, id);
    });
  }

  Future<bool> updatePerson({
    required String id,
    required String displayName,
    required String note,
  }) {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return Future<bool>.value(false);
    return _enqueueMutation((state) {
      final index = state.persons.indexWhere((person) => person.id == id);
      if (index == -1) return null;
      final candidate = state.copy();
      candidate.persons[index] = candidate.persons[index].copyWith(
        displayName: trimmed,
        note: note,
      );
      return candidate;
    });
  }

  Future<bool> deletePerson(String id) => _enqueueMutation((state) {
    if (!state.persons.any((person) => person.id == id)) return null;
    final candidate = state.copy()
      ..persons.removeWhere((person) => person.id == id)
      ..personTopics.removeWhere((item) => item.personId == id);
    return candidate;
  });

  Future<bool> assignTopicToPerson({
    required String personId,
    required String topicId,
    String note = '',
  }) => _enqueueMutation((state) {
    if (!state.hasPerson(personId) ||
        !state.hasActiveTopic(topicId) ||
        state.personTopics.any(
          (item) => item.personId == personId && item.topicId == topicId,
        )) {
      return null;
    }
    final candidate = state.copy()
      ..personTopics.add(
        PersonTopic(
          personId: personId,
          topicId: topicId,
          note: note,
          createdAt: DateTime.now(),
        ),
      );
    return candidate;
  });

  /// Assigns every supplied active, unassigned topic in one persisted update.
  ///
  /// Validation deliberately happens inside the write queue, so a pending
  /// mutation cannot make this operation partially succeed or create a
  /// duplicate relation.
  Future<bool> assignTopicsToPerson({
    required String personId,
    required Iterable<String> topicIds,
  }) => _enqueueMutation((state) {
    final ids = Set<String>.from(topicIds);
    if (ids.isEmpty || !state.hasPerson(personId)) return null;

    final assignedIds = state.personTopics
        .where((item) => item.personId == personId)
        .map((item) => item.topicId)
        .toSet();
    if (ids.any(
      (id) => !state.hasActiveTopic(id) || assignedIds.contains(id),
    )) {
      return null;
    }

    final candidate = state.copy();
    final now = DateTime.now();
    candidate.personTopics.addAll(
      ids.map(
        (id) => PersonTopic(
          personId: personId,
          topicId: id,
          note: '',
          createdAt: now,
        ),
      ),
    );
    return candidate;
  });

  Future<bool> updatePersonTopicNote({
    required String personId,
    required String topicId,
    required String note,
  }) => _enqueueMutation((state) {
    final index = state.personTopics.indexWhere(
      (item) => item.personId == personId && item.topicId == topicId,
    );
    if (index == -1) return null;
    final candidate = state.copy();
    candidate.personTopics[index] = candidate.personTopics[index].copyWith(
      note: note,
    );
    return candidate;
  });

  Future<bool> updatePersonTopicStatus({
    required String personId,
    required String topicId,
    required PersonTopicStatus status,
  }) => _enqueueMutation((state) {
    final index = state.personTopics.indexWhere(
      (item) => item.personId == personId && item.topicId == topicId,
    );
    if (index == -1) return null;
    final candidate = state.copy();
    candidate.personTopics[index] = candidate.personTopics[index].copyWith(
      status: status,
    );
    return candidate;
  });

  Future<bool> removeTopicFromPerson({
    required String personId,
    required String topicId,
  }) => _enqueueMutation((state) {
    final index = state.personTopics.indexWhere(
      (item) => item.personId == personId && item.topicId == topicId,
    );
    if (index == -1) return null;
    final candidate = state.copy()..personTopics.removeAt(index);
    return candidate;
  });

  Future<bool> _enqueueMutation(_AppState? Function(_AppState state) change) =>
      _enqueueValueMutation<bool>((state) {
        final candidate = change(state);
        return candidate == null
            ? null
            : _ValueCandidate<bool>(candidate, true);
      }).then((value) => value ?? false);

  Future<T?> _enqueueValueMutation<T>(
    _ValueCandidate<T>? Function(_AppState state) change,
  ) {
    if (loadState != AppLoadState.ready) return Future<T?>.value(null);
    final operation = _writeQueue.then((_) async {
      if (loadState != AppLoadState.ready) return null;
      final changed = change(_currentState());
      if (changed == null) return null;
      try {
        await _save(changed.state.toData());
        _commit(changed.state);
        lastError = null;
        notifyListeners();
        return changed.value;
      } catch (_) {
        lastError = '保存に失敗しました。もう一度試してください。';
        notifyListeners();
        return null;
      }
    });
    _writeQueue = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  Future<void> _save(LocalAppData data) => _storage.saveSnapshot(
    customTopics: data.customTopics,
    favoriteIds: data.favoriteIds,
    archivedIds: data.archivedIds,
    persons: data.persons,
    personTopics: data.personTopics,
  );

  _AppState _currentState() => _AppState(
    allTopics: List<Topic>.from(_allTopics),
    favoriteIds: Set<String>.from(_favoriteIds),
    archivedIds: Set<String>.from(_archivedIds),
    persons: List<Person>.from(_persons),
    personTopics: List<PersonTopic>.from(_personTopics),
  );

  void _commit(_AppState state) {
    _allTopics = state.allTopics;
    _favoriteIds = state.favoriteIds;
    _archivedIds = state.archivedIds;
    _persons = state.persons;
    _personTopics = state.personTopics;
  }

  Topic? _topicByIdIncludingArchived(String id) {
    for (final topic in _allTopics) {
      if (topic.id == id) return topic;
    }
    return null;
  }

  String _nextId(String prefix, _AppState state, DateTime now) {
    final reserved = <String>{
      ...state.allTopics.map((topic) => topic.id),
      ...state.persons.map((person) => person.id),
      ...state.favoriteIds,
      ...state.archivedIds,
    };
    final base = '$prefix-${now.microsecondsSinceEpoch}';
    var candidate = base;
    var suffix = 1;
    while (!reserved.add(candidate)) {
      candidate = '$base-$suffix';
      suffix++;
    }
    return candidate;
  }

  void clearError() {
    lastError = null;
  }
}

class _ValueCandidate<T> {
  const _ValueCandidate(this.state, this.value);
  final _AppState state;
  final T value;
}

class _AppState {
  _AppState({
    required this.allTopics,
    required this.favoriteIds,
    required this.archivedIds,
    required this.persons,
    required this.personTopics,
  });

  factory _AppState.fromData(LocalAppData data) => _AppState(
    allTopics: <Topic>[...createStaticTopics(), ...data.customTopics],
    favoriteIds: Set<String>.from(data.favoriteIds),
    archivedIds: Set<String>.from(data.archivedIds),
    persons: List<Person>.from(data.persons),
    personTopics: List<PersonTopic>.from(data.personTopics),
  );

  final List<Topic> allTopics;
  final Set<String> favoriteIds;
  final Set<String> archivedIds;
  final List<Person> persons;
  final List<PersonTopic> personTopics;

  _AppState copy() => _AppState(
    allTopics: List<Topic>.from(allTopics),
    favoriteIds: Set<String>.from(favoriteIds),
    archivedIds: Set<String>.from(archivedIds),
    persons: List<Person>.from(persons),
    personTopics: List<PersonTopic>.from(personTopics),
  );

  LocalAppData toData() => LocalAppData(
    customTopics: allTopics
        .where((topic) => topic.source == TopicSource.userCreated)
        .toList(growable: false),
    favoriteIds: favoriteIds,
    archivedIds: archivedIds,
    persons: persons,
    personTopics: personTopics,
    needsMigration: false,
  );

  bool hasTopic(String id) => allTopics.any((topic) => topic.id == id);
  bool hasActiveTopic(String id) => hasTopic(id) && !archivedIds.contains(id);
  bool hasPerson(String id) => persons.any((person) => person.id == id);
}
