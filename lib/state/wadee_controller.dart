import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;

import '../data/topic_catalog.dart';
import '../data/local_app_storage.dart';
import '../models/category.dart';
import '../models/person.dart';
import '../models/person_topic.dart';
import '../models/topic.dart';
import '../models/topic_draft.dart';

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
    _allTopics.where(
      (topic) =>
          topic.scope == TopicScope.global && !_archivedIds.contains(topic.id),
    ),
  );
  List<Topic> get allTopicsIncludingArchived => List.unmodifiable(
    _allTopics.where((topic) => topic.scope == TopicScope.global),
  );
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
    final topic = state.topicById(id);
    if (topic == null ||
        state.archivedIds.contains(id) ||
        topic.scope != TopicScope.global) {
      return null;
    }
    final candidate = state.copy();
    if (!candidate.favoriteIds.add(id)) candidate.favoriteIds.remove(id);
    return candidate;
  });

  Future<bool> addTopic({
    required String title,
    required String categoryId,
    String? openingQuestion,
    Iterable<String> talkingPoints = const <String>[],
    String note = '',
  }) => _enqueueMutation((state) {
    final trimmedTitle = title.trim();
    final trimmedQuestion =
        (openingQuestion ?? Topic.fallbackOpeningQuestion(trimmedTitle)).trim();
    if (trimmedTitle.isEmpty ||
        trimmedQuestion.isEmpty ||
        !_isKnownCategory(categoryId) ||
        _hasDuplicate(
          state,
          title: trimmedTitle,
          openingQuestion: trimmedQuestion,
        )) {
      return null;
    }
    final candidate = state.copy();
    final now = DateTime.now();
    candidate.allTopics.add(
      Topic(
        id: _nextId('custom', candidate, now),
        title: trimmedTitle,
        categoryId: categoryId.trim(),
        openingQuestion: trimmedQuestion,
        talkingPoints: _normalizedTalkingPoints(talkingPoints),
        note: note.trim(),
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
    String? openingQuestion,
    Iterable<String> talkingPoints = const <String>[],
    String note = '',
  }) => _enqueueMutation((state) {
    final index = state.allTopics.indexWhere((topic) => topic.id == id);
    if (index == -1 ||
        state.archivedIds.contains(id) ||
        state.allTopics[index].source != TopicSource.userCreated) {
      return null;
    }
    final trimmedTitle = title.trim();
    final trimmedQuestion =
        (openingQuestion ?? Topic.fallbackOpeningQuestion(trimmedTitle)).trim();
    if (trimmedTitle.isEmpty ||
        trimmedQuestion.isEmpty ||
        !_isKnownCategory(categoryId) ||
        _hasDuplicate(
          state,
          title: trimmedTitle,
          openingQuestion: trimmedQuestion,
          excludingId: id,
          ownerPersonId: state.allTopics[index].ownerPersonId,
        )) {
      return null;
    }
    final candidate = state.copy();
    candidate.allTopics[index] = candidate.allTopics[index].copyWith(
      title: trimmedTitle,
      categoryId: categoryId.trim(),
      openingQuestion: trimmedQuestion,
      talkingPoints: _normalizedTalkingPoints(talkingPoints),
      note: note.trim(),
    );
    return candidate;
  });

  static List<String> _normalizedTalkingPoints(Iterable<String> values) =>
      values
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);

  static String _duplicateKey(String title, String openingQuestion) =>
      '${title.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase()}\u0000'
      '${openingQuestion.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase()}';

  static bool _isKnownCategory(String value) =>
      categories.any((category) => category.id == value.trim());

  static bool _hasDuplicate(
    _AppState state, {
    required String title,
    required String openingQuestion,
    String? excludingId,
    String? ownerPersonId,
  }) {
    final key = _duplicateKey(title, openingQuestion);
    return state.allTopics.any(
      (topic) =>
          topic.id != excludingId &&
          (topic.scope == TopicScope.global ||
              (ownerPersonId != null &&
                  topic.ownerPersonId == ownerPersonId)) &&
          _duplicateKey(topic.title, topic.openingQuestion) == key,
    );
  }

  bool hasDuplicateTopicForPerson({
    required String personId,
    required String title,
    required String openingQuestion,
    String? excludingId,
  }) => _hasDuplicate(
    _currentState(),
    title: title,
    openingQuestion: openingQuestion,
    excludingId: excludingId,
    ownerPersonId: personId,
  );

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

  Future<String?> addPerson({
    required String displayName,
    String note = '',
    PersonProfile profile = const PersonProfile(),
  }) {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty || loadState != AppLoadState.ready) {
      return Future<String?>.value(null);
    }
    return _enqueueValueMutation<String>((state) {
      final candidate = state.copy();
      final now = DateTime.now();
      final id = _nextId('person', candidate, now);
      candidate.persons.add(
        Person(
          id: id,
          displayName: trimmed,
          note: note.trim(),
          createdAt: now,
          profile: profile.normalized(),
        ),
      );
      return _ValueCandidate<String>(candidate, id);
    });
  }

  Future<bool> updatePerson({
    required String id,
    required String displayName,
    required String note,
    PersonProfile? profile,
  }) {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return Future<bool>.value(false);
    return _enqueueMutation((state) {
      final index = state.persons.indexWhere((person) => person.id == id);
      if (index == -1) return null;
      final candidate = state.copy();
      candidate.persons[index] = candidate.persons[index].copyWith(
        displayName: trimmed,
        note: note.trim(),
        profile: (profile ?? state.persons[index].profile).normalized(),
      );
      return candidate;
    });
  }

  Future<bool> deletePerson(String id) => _enqueueMutation((state) {
    if (!state.persons.any((person) => person.id == id)) return null;
    final candidate = state.copy();
    final ownedIds = candidate.allTopics
        .where((topic) => topic.ownerPersonId == id)
        .map((topic) => topic.id)
        .toSet();
    candidate
      ..persons.removeWhere((person) => person.id == id)
      ..allTopics.removeWhere((topic) => ownedIds.contains(topic.id))
      ..personTopics.removeWhere(
        (item) => item.personId == id || ownedIds.contains(item.topicId),
      )
      ..favoriteIds.removeWhere(ownedIds.contains)
      ..archivedIds.removeWhere(ownedIds.contains);
    return candidate;
  });

  Future<bool> assignTopicToPerson({
    required String personId,
    required String topicId,
    String note = '',
  }) => _enqueueMutation((state) {
    final topic = state.topicById(topicId);
    if (!state.hasPerson(personId) ||
        topic == null ||
        state.archivedIds.contains(topicId) ||
        (topic.scope == TopicScope.person && topic.ownerPersonId != personId) ||
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
    if (ids.any((id) {
      final topic = state.topicById(id);
      return topic == null ||
          state.archivedIds.contains(id) ||
          assignedIds.contains(id) ||
          (topic.scope == TopicScope.person && topic.ownerPersonId != personId);
    })) {
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
    final candidate = state.copy();
    final topic = candidate.topicById(topicId);
    if (topic?.scope == TopicScope.person) {
      candidate
        ..allTopics.removeWhere((item) => item.id == topicId)
        ..personTopics.removeWhere((item) => item.topicId == topicId)
        ..favoriteIds.remove(topicId)
        ..archivedIds.remove(topicId);
    } else {
      candidate.personTopics.removeAt(index);
    }
    return candidate;
  });

  Future<List<String>?> addAiGeneratedTopicsToPerson(
    String personId,
    Iterable<TopicDraft> drafts,
  ) => _enqueueValueMutation<List<String>>((state) {
    final values = drafts.toList(growable: false);
    if (!state.hasPerson(personId) || values.isEmpty) return null;
    final normalized = <TopicDraft>[];
    final keys = <String>{};
    for (final draft in values) {
      final title = draft.title.trim();
      final openingQuestion = draft.openingQuestion.trim();
      if (title.isEmpty ||
          openingQuestion.isEmpty ||
          !_isKnownCategory(draft.categoryId) ||
          _hasDuplicate(
            state,
            title: title,
            openingQuestion: openingQuestion,
            ownerPersonId: personId,
          ) ||
          !keys.add(_duplicateKey(title, openingQuestion))) {
        return null;
      }
      normalized.add(
        TopicDraft(
          title: title,
          categoryId: draft.categoryId.trim(),
          openingQuestion: openingQuestion,
          talkingPoints: _normalizedTalkingPoints(draft.talkingPoints),
          note: draft.note.trim(),
        ),
      );
    }
    final candidate = state.copy();
    final now = DateTime.now();
    final ids = <String>[];
    for (final draft in normalized) {
      final id = _nextId('ai', candidate, now);
      ids.add(id);
      candidate.allTopics.add(
        Topic(
          id: id,
          title: draft.title,
          categoryId: draft.categoryId,
          openingQuestion: draft.openingQuestion,
          talkingPoints: draft.talkingPoints,
          note: draft.note,
          source: TopicSource.aiGenerated,
          scope: TopicScope.person,
          ownerPersonId: personId,
          createdAt: now,
        ),
      );
      candidate.personTopics.add(
        PersonTopic(personId: personId, topicId: id, note: '', createdAt: now),
      );
    }
    return _ValueCandidate<List<String>>(candidate, List.unmodifiable(ids));
  });

  Future<bool> promotePersonTopicToGlobal(String topicId) => _enqueueMutation((
    state,
  ) {
    final index = state.allTopics.indexWhere((topic) => topic.id == topicId);
    if (index == -1 || state.allTopics[index].scope != TopicScope.person) {
      return null;
    }
    final topic = state.allTopics[index];
    if (_hasDuplicate(
      state,
      title: topic.title,
      openingQuestion: topic.openingQuestion,
      excludingId: topicId,
    )) {
      return null;
    }
    final candidate = state.copy();
    candidate.allTopics[index] = Topic(
      id: topic.id,
      title: topic.title,
      categoryId: topic.categoryId,
      openingQuestion: topic.openingQuestion,
      talkingPoints: topic.talkingPoints,
      note: topic.note,
      source: topic.source,
      createdAt: topic.createdAt,
    );
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
        .where((topic) => topic.source != TopicSource.builtIn)
        .toList(growable: false),
    favoriteIds: favoriteIds,
    archivedIds: archivedIds,
    persons: persons,
    personTopics: personTopics,
    needsMigration: false,
  );

  bool hasTopic(String id) => allTopics.any((topic) => topic.id == id);
  Topic? topicById(String id) {
    for (final topic in allTopics) {
      if (topic.id == id) return topic;
    }
    return null;
  }

  bool hasActiveTopic(String id) => hasTopic(id) && !archivedIds.contains(id);
  bool hasPerson(String id) => persons.any((person) => person.id == id);
}
