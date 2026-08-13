import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wadai/app/app_shell.dart';
import 'package:wadai/app/wadai_app.dart';
import 'package:wadai/data/topic_catalog.dart';
import 'package:wadai/data/local_app_storage.dart';
import 'package:wadai/features/people/people_screen.dart';
import 'package:wadai/features/people/person_detail_screen.dart';
import 'package:wadai/features/people/person_topic_detail_screen.dart';
import 'package:wadai/features/people/topic_picker_screen.dart';
import 'package:wadai/features/topics/topics_screen.dart';
import 'package:wadai/features/topics/topic_detail_screen.dart';
import 'package:wadai/features/topics/topic_tile.dart';
import 'package:wadai/features/topics/category_icon.dart';
import 'package:wadai/models/person.dart';
import 'package:wadai/models/person_topic.dart';
import 'package:wadai/models/topic.dart';
import 'package:wadai/state/wadee_controller.dart';

class MemoryStorage extends LocalAppStorage {
  MemoryStorage(
    this.data, {
    this.failSaves = false,
    this.failLoads = false,
    this.delay = false,
  });
  LocalAppData data;
  bool failSaves;
  bool failLoads;
  bool delay;
  int saveCalls = 0;

  @override
  Future<LocalAppData> load() async {
    if (delay) await Future<void>.delayed(const Duration(milliseconds: 1));
    if (failLoads) throw Exception('load');
    return data;
  }

  @override
  Future<void> saveSnapshot({
    required List<Topic> customTopics,
    required Iterable<String> favoriteIds,
    required Iterable<String> archivedIds,
    required List<Person> persons,
    required List<PersonTopic> personTopics,
  }) async {
    if (delay) await Future<void>.delayed(const Duration(milliseconds: 1));
    saveCalls++;
    if (failSaves) throw Exception('save');
    data = appData(
      customTopics: customTopics,
      favoriteIds: Set<String>.from(favoriteIds),
      archivedIds: Set<String>.from(archivedIds),
      persons: persons,
      personTopics: personTopics,
    );
  }
}

LocalAppData appData({
  List<Topic> customTopics = const <Topic>[],
  Set<String> favoriteIds = const <String>{},
  Set<String> archivedIds = const <String>{},
  List<Person> persons = const <Person>[],
  List<PersonTopic> personTopics = const <PersonTopic>[],
  bool needsMigration = false,
}) => LocalAppData(
  customTopics: customTopics,
  favoriteIds: favoriteIds,
  archivedIds: archivedIds,
  persons: persons,
  personTopics: personTopics,
  needsMigration: needsMigration,
);

Topic custom(String id, {String title = 'custom', String description = ''}) =>
    Topic(
      id: id,
      title: title,
      categoryId: 'other',
      description: description,
      source: TopicSource.userCreated,
      createdAt: DateTime.utc(2026),
    );

Future<WadeeController> ready({LocalAppStorage? storage}) async {
  final store = WadeeController(storage: storage);
  await store.load();
  return store;
}

Future<void> applyTopicFilters(
  WidgetTester tester, {
  String? display,
  String? category,
  String? sort,
}) async {
  await tester.tap(find.byTooltip('絞り込みと並び替え'));
  await tester.pumpAndSettle();
  if (display != null) {
    await tester.tap(find.text(display).last);
    await tester.pump();
  }
  if (category != null) {
    await tester.drag(
      find.byKey(const Key('topic-filter-sheet-list')),
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(category).last);
    await tester.pump();
  }
  if (sort != null) {
    await tester.drag(
      find.byKey(const Key('topic-filter-sheet-list')),
      const Offset(0, -480),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(sort).last);
    await tester.pump();
  }
  await tester.tap(
    find.descendant(
      of: find.byType(FilledButton),
      matching: find.textContaining('件を表示'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('migration and validation', () {
    test('v1 migrates to v3 and preserves favorites', () async {
      final builtin = createStaticTopics().first;
      SharedPreferences.setMockInitialValues(<String, Object>{
        LocalAppStorage.snapshotKey: jsonEncode(<String, Object>{
          'schemaVersion': 1,
          'customTopics': <Object>[
            <String, Object?>{
              'id': 'old',
              'title': 'old',
              'categoryId': 'other',
              'description': '',
              'isCustom': true,
              'isFavorite': false,
              'createdAt': null,
            },
          ],
          'favoriteTopicIds': <String>['old', builtin.id],
        }),
      });
      final store = await ready();
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(
          prefs.getString(LocalAppStorage.snapshotKey)!,
        )['schemaVersion'],
        3,
      );
      expect(store.isFavorite('old'), isTrue);
      expect(store.isFavorite(builtin.id), isTrue);
    });

    test('legacy maps every old static ID and leaves legacy keys', () async {
      final oldIds = legacyStaticTopicIdToBuiltinId.keys.toList();
      SharedPreferences.setMockInitialValues(<String, Object>{
        LocalAppStorage.customTopicsKey: jsonEncode(<Object>[
          <String, Object?>{
            'id': 'legacy',
            'title': 'legacy',
            'categoryId': 'other',
            'description': '',
            'isCustom': true,
            'isFavorite': false,
            'createdAt': null,
          },
        ]),
        LocalAppStorage.favoriteIdsKey: <String>[...oldIds, 'unknown-favorite'],
      });
      final store = await ready();
      final prefs = await SharedPreferences.getInstance();
      expect(legacyStaticTopicIdToBuiltinId, hasLength(36));
      expect(
        store.favoriteTopics.map((topic) => topic.id),
        containsAll(legacyStaticTopicIdToBuiltinId.values),
      );
      expect(store.favoriteTopicIds, contains('unknown-favorite'));
      expect(prefs.getString(LocalAppStorage.customTopicsKey), isNotNull);
      expect(
        prefs.getStringList(LocalAppStorage.favoriteIdsKey),
        containsAll(oldIds),
      );
    });

    test('v2 restores persons, assignments and unknown IDs', () async {
      final builtin = createStaticTopics().first;
      final person = Person(
        id: 'p',
        displayName: 'p',
        note: 'n',
        createdAt: DateTime.utc(2026),
      );
      final item = PersonTopic(
        personId: 'p',
        topicId: builtin.id,
        note: 'n',
        createdAt: DateTime.utc(2026),
      );
      final store = await ready(
        storage: MemoryStorage(
          appData(
            customTopics: <Topic>[custom('c')],
            favoriteIds: <String>{'unknown-favorite'},
            archivedIds: <String>{'c', 'unknown-archive'},
            persons: <Person>[person],
            personTopics: <PersonTopic>[item],
          ),
        ),
      );
      expect(store.topicById('c'), isNull);
      expect(store.personById('p')!.note, 'n');
      expect(store.personTopic('p', builtin.id)!.note, 'n');
      expect(store.favoriteTopicIds, contains('unknown-favorite'));
      expect(store.archivedTopicIds, contains('unknown-archive'));
    });

    test(
      'v2 person-topic data migrates planned status into one v3 snapshot',
      () async {
        final builtin = createStaticTopics().first;
        final raw = jsonEncode(<String, Object>{
          'schemaVersion': 2,
          'customTopics': <Object>[],
          'favoriteTopicIds': <String>['unknown-favorite'],
          'archivedTopicIds': <String>['unknown-archive'],
          'persons': <Object>[
            Person(
              id: 'p',
              displayName: 'P',
              note: 'person note',
              createdAt: DateTime.utc(2026),
            ).toJson(),
          ],
          'personTopics': <Object>[
            <String, Object>{
              'personId': 'p',
              'topicId': builtin.id,
              'note': 'relation note',
              'createdAt': DateTime.utc(2026).toIso8601String(),
            },
          ],
        });
        SharedPreferences.setMockInitialValues(<String, Object>{
          LocalAppStorage.snapshotKey: raw,
        });

        final store = await ready();
        final prefs = await SharedPreferences.getInstance();
        final snapshot =
            jsonDecode(prefs.getString(LocalAppStorage.snapshotKey)!)
                as Map<String, dynamic>;
        expect(snapshot['schemaVersion'], 3);
        expect(
          (snapshot['personTopics'] as List<dynamic>).single['status'],
          'planned',
        );
        expect(
          store.personTopic('p', builtin.id)!.status,
          PersonTopicStatus.planned,
        );
        expect(store.favoriteTopicIds, contains('unknown-favorite'));
        expect(store.archivedTopicIds, contains('unknown-archive'));
      },
    );

    test(
      'v3 rejects missing or unknown person-topic status without overwrite',
      () async {
        final builtin = createStaticTopics().first;
        for (final status in <Object?>[null, 'unknown']) {
          final personTopic = <String, Object?>{
            'personId': 'p',
            'topicId': builtin.id,
            'note': '',
            'createdAt': DateTime.utc(2026).toIso8601String(),
          };
          if (status is String) {
            personTopic['status'] = status;
          }
          final snapshot = <String, Object?>{
            'schemaVersion': 3,
            'customTopics': <Object>[],
            'favoriteTopicIds': <String>[],
            'archivedTopicIds': <String>[],
            'persons': <Object>[
              Person(
                id: 'p',
                displayName: 'P',
                note: '',
                createdAt: DateTime.utc(2026),
              ).toJson(),
            ],
            'personTopics': <Object>[personTopic],
          };
          final raw = jsonEncode(snapshot);
          SharedPreferences.setMockInitialValues(<String, Object>{
            LocalAppStorage.snapshotKey: raw,
          });
          final store = WadeeController();
          await store.load();
          final prefs = await SharedPreferences.getInstance();
          expect(store.loadState, AppLoadState.error);
          expect(prefs.getString(LocalAppStorage.snapshotKey), raw);
        }
      },
    );

    test('bad, unsupported and invalid snapshots stay raw', () async {
      final rawValues = <String>[
        '{bad',
        jsonEncode(<String, Object>{'schemaVersion': 99}),
        jsonEncode(<String, Object>{
          'schemaVersion': 2,
          'customTopics': <Object>[
            custom('dup').toJson(),
            custom('dup').toJson(),
          ],
          'favoriteTopicIds': <String>[],
          'archivedTopicIds': <String>[],
          'persons': <Object>[],
          'personTopics': <Object>[],
        }),
      ];
      for (final raw in rawValues) {
        SharedPreferences.setMockInitialValues(<String, Object>{
          LocalAppStorage.snapshotKey: raw,
        });
        final store = WadeeController();
        await store.load();
        final prefs = await SharedPreferences.getInstance();
        expect(store.loadState, AppLoadState.error);
        expect(prefs.getString(LocalAppStorage.snapshotKey), raw);
      }
    });
  });

  group('state behavior', () {
    test(
      'load gate, migration failure and write failure do not commit state',
      () async {
        final beforeLoad = WadeeController(storage: MemoryStorage(appData()));
        expect(
          await beforeLoad.toggleFavorite(createStaticTopics().first.id),
          isFalse,
        );
        final storage = MemoryStorage(
          appData(customTopics: <Topic>[custom('m')], needsMigration: true),
          failSaves: true,
        );
        final store = WadeeController(storage: storage);
        await store.load();
        expect(store.loadState, AppLoadState.error);
        expect(store.topicById('m'), isNull);
        storage.failSaves = false;
        await store.load();
        expect(store.topicById('m'), isNotNull);
        storage.failSaves = true;
        final builtin = store.topics.first;
        expect(await store.toggleFavorite(builtin.id), isFalse);
        expect(store.isFavorite(builtin.id), isFalse);
      },
    );

    test(
      'queue, archive/restore and unknown IDs preserve complete state',
      () async {
        final storage = MemoryStorage(
          appData(
            favoriteIds: <String>{'unknown-favorite'},
            archivedIds: <String>{'unknown-archive'},
          ),
          delay: true,
        );
        final store = await ready(storage: storage);
        await Future.wait(<Future<bool>>[
          store.addTopic(title: 'one', categoryId: 'other', description: ''),
          store.addTopic(title: 'two', categoryId: 'other', description: ''),
        ]);
        final builtin = store.topics.first;
        await store.toggleFavorite(builtin.id);
        await store.archiveTopic(builtin.id);
        expect(store.topicById(builtin.id), isNull);
        expect(store.isFavorite(builtin.id), isTrue);
        expect(await store.restoreTopic(builtin.id), isTrue);
        expect(storage.data.favoriteIds, contains('unknown-favorite'));
        expect(storage.data.archivedIds, contains('unknown-archive'));
      },
    );

    test('person CRUD cascades assignments and enforces a pair', () async {
      final store = await ready(storage: MemoryStorage(appData()));
      expect(await store.addPerson(displayName: ' '), isNull);
      final id = await store.addPerson(displayName: ' P ', note: 'n');
      final topic = store.topics.first;
      expect(
        await store.assignTopicToPerson(
          personId: id!,
          topicId: topic.id,
          note: 'a',
        ),
        isTrue,
      );
      expect(
        await store.assignTopicToPerson(personId: id, topicId: topic.id),
        isFalse,
      );
      expect(
        await store.updatePersonTopicNote(
          personId: id,
          topicId: topic.id,
          note: 'b',
        ),
        isTrue,
      );
      await store.archiveTopic(topic.id);
      expect(
        await store.assignTopicToPerson(personId: id, topicId: topic.id),
        isFalse,
      );
      expect(
        await store.updatePersonTopicNote(
          personId: id,
          topicId: topic.id,
          note: 'c',
        ),
        isTrue,
      );
      await store.deletePerson(id);
      expect(store.persons, isEmpty);
      expect(store.personTopics, isEmpty);
      expect(store.topicByIdIncludingArchived(topic.id), isNotNull);
    });
  });

  group('additional Phase 4 regression coverage', () {
    test(
      'person-topic status round trips and archive does not block updates',
      () async {
        final person = Person(
          id: 'p',
          displayName: 'P',
          note: '',
          createdAt: DateTime.utc(2026),
        );
        final topic = custom('status-topic');
        final storage = MemoryStorage(
          appData(
            customTopics: <Topic>[topic],
            archivedIds: <String>{topic.id},
            persons: <Person>[person],
            personTopics: <PersonTopic>[
              PersonTopic(
                personId: person.id,
                topicId: topic.id,
                note: '',
                createdAt: DateTime.utc(2026),
              ),
            ],
          ),
        );
        final store = await ready(storage: storage);
        for (final status in PersonTopicStatus.values) {
          expect(
            await store.updatePersonTopicStatus(
              personId: person.id,
              topicId: topic.id,
              status: status,
            ),
            isTrue,
          );
        }
        expect(
          store.personTopic(person.id, topic.id)!.status,
          PersonTopicStatus.revisit,
        );
        final reloaded = await ready(storage: storage);
        expect(
          reloaded.personTopic(person.id, topic.id)!.status,
          PersonTopicStatus.revisit,
        );
      },
    );

    test('Topic JSON is immutable and excludes favorite state', () {
      final topic = custom('json', description: 'd');
      final restored = Topic.fromJson(topic.toJson());
      expect(restored.source, TopicSource.userCreated);
      expect(restored.description, 'd');
      expect(topic.toJson().containsKey('isFavorite'), isFalse);
    });

    test(
      'built-in update is rejected but archive and restore are allowed',
      () async {
        final store = await ready(storage: MemoryStorage(appData()));
        final builtin = store.topics.first;
        expect(
          await store.updateTopic(
            id: builtin.id,
            title: 'x',
            categoryId: 'other',
            description: '',
          ),
          isFalse,
        );
        expect(await store.archiveTopic(builtin.id), isTrue);
        expect(await store.restoreTopic(builtin.id), isTrue);
      },
    );

    test('custom archive retains favorite and assigned memo', () async {
      final person = Person(
        id: 'p',
        displayName: 'p',
        note: '',
        createdAt: DateTime.utc(2026),
      );
      final store = await ready(
        storage: MemoryStorage(
          appData(
            customTopics: <Topic>[custom('c')],
            favoriteIds: <String>{'c'},
            persons: <Person>[person],
            personTopics: <PersonTopic>[
              PersonTopic(
                personId: 'p',
                topicId: 'c',
                note: 'memo',
                createdAt: DateTime.utc(2026),
              ),
            ],
          ),
        ),
      );
      await store.archiveTopic('c');
      expect(store.isFavorite('c'), isTrue);
      expect(store.personTopic('p', 'c')!.note, 'memo');
    });

    test('person update and assignment removal save correctly', () async {
      final person = Person(
        id: 'p',
        displayName: 'p',
        note: '',
        createdAt: DateTime.utc(2026),
      );
      final store = await ready(
        storage: MemoryStorage(appData(persons: <Person>[person])),
      );
      final topic = store.topics.first;
      expect(
        await store.updatePerson(
          id: 'p',
          displayName: ' updated ',
          note: 'note',
        ),
        isTrue,
      );
      expect(store.personById('p')!.displayName, 'updated');
      await store.assignTopicToPerson(personId: 'p', topicId: topic.id);
      expect(
        await store.removeTopicFromPerson(personId: 'p', topicId: topic.id),
        isTrue,
      );
      expect(store.personTopics, isEmpty);
    });

    test(
      'invalid person topic references and duplicate people are rejected',
      () async {
        final raw = jsonEncode(<String, Object>{
          'schemaVersion': 2,
          'customTopics': <Object>[],
          'favoriteTopicIds': <String>[],
          'archivedTopicIds': <String>[],
          'persons': <Object>[
            Person(
              id: 'p',
              displayName: 'p',
              note: '',
              createdAt: DateTime.utc(2026),
            ).toJson(),
            Person(
              id: 'p',
              displayName: 'p',
              note: '',
              createdAt: DateTime.utc(2026),
            ).toJson(),
          ],
          'personTopics': <Object>[],
        });
        SharedPreferences.setMockInitialValues(<String, Object>{
          LocalAppStorage.snapshotKey: raw,
        });
        final store = WadeeController();
        await store.load();
        expect(store.loadState, AppLoadState.error);
      },
    );

    test(
      'generated custom ID does not collide with held unknown IDs',
      () async {
        final storage = MemoryStorage(
          appData(favoriteIds: <String>{'custom-1'}),
        );
        final store = await ready(storage: storage);
        await store.addTopic(
          title: 'new',
          categoryId: 'other',
          description: '',
        );
        expect(store.customTopics.single.id, isNot('custom-1'));
      },
    );
  });

  group('additional persisted-state edge cases', () {
    test('static catalog keeps 36 explicit built-in IDs', () {
      final topics = createStaticTopics();
      expect(topics, hasLength(36));
      expect(topics.map((topic) => topic.id).toSet(), hasLength(36));
      expect(
        topics.every((topic) => topic.source == TopicSource.builtIn),
        isTrue,
      );
    });

    test('archive and restore reject repeated invalid transitions', () async {
      final store = await ready(storage: MemoryStorage(appData()));
      final id = store.topics.first.id;
      expect(await store.restoreTopic(id), isFalse);
      expect(await store.archiveTopic(id), isTrue);
      expect(await store.archiveTopic(id), isFalse);
      expect(await store.restoreTopic(id), isTrue);
    });

    test('favorite toggles survive an actual snapshot reload', () async {
      final store = await ready();
      final id = store.topics.first.id;
      await store.toggleFavorite(id);
      expect((await ready()).isFavorite(id), isTrue);
      await store.toggleFavorite(id);
      expect((await ready()).isFavorite(id), isFalse);
    });

    test('person update rejects a blank display name', () async {
      final person = Person(
        id: 'p',
        displayName: 'p',
        note: '',
        createdAt: DateTime.utc(2026),
      );
      final store = await ready(
        storage: MemoryStorage(appData(persons: <Person>[person])),
      );
      expect(
        await store.updatePerson(id: 'p', displayName: ' ', note: 'changed'),
        isFalse,
      );
      expect(store.personById('p')!.note, isEmpty);
    });

    test('PersonTopic JSON preserves its composite identity and note', () {
      final item = PersonTopic(
        personId: 'p',
        topicId: 't',
        note: 'n',
        createdAt: DateTime.utc(2026),
      );
      final restored = PersonTopic.fromJson(item.toJson());
      expect(restored.pairKey, item.pairKey);
      expect(restored.note, 'n');
    });

    test(
      'archived topics are hidden from active favorite and custom lists',
      () async {
        final store = await ready(
          storage: MemoryStorage(
            appData(
              customTopics: <Topic>[custom('c')],
              favoriteIds: <String>{'c'},
              archivedIds: <String>{'c'},
            ),
          ),
        );
        expect(store.topics.where((topic) => topic.id == 'c'), isEmpty);
        expect(store.favoriteTopics.where((topic) => topic.id == 'c'), isEmpty);
        expect(store.customTopics.where((topic) => topic.id == 'c'), isEmpty);
      },
    );
  });

  group('existing UI and routes', () {
    testWidgets(
      'app starts on People and has only People and Topics navigation',
      (tester) async {
        final store = await ready(storage: MemoryStorage(appData()));
        await tester.pumpWidget(MaterialApp(home: AppShell(store: store)));
        expect(find.byType(NavigationDestination), findsNWidgets(2));
        expect(find.byType(PeopleScreen), findsOneWidget);
        await tester.tap(find.byType(NavigationDestination).at(1));
        await tester.pumpAndSettle();
        expect(find.byType(TopicsScreen), findsOneWidget);
      },
    );

    testWidgets(
      'People form creates and Person detail assigns an active topic',
      (tester) async {
        final store = await ready(storage: MemoryStorage(appData()));
        await tester.pumpWidget(MaterialApp(home: PeopleScreen(store: store)));
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).at(0), 'person');
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'general note',
        );
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        final person = store.persons.single;
        expect(person.note, 'general note');
        await tester.tap(find.byType(ListTile));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(createStaticTopics().first.title).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('1件を追加'));
        await tester.pumpAndSettle();
        expect(store.personTopicsFor(person.id), hasLength(1));
      },
    );

    testWidgets(
      'Topics screen exposes four filters and archived topics require including-archive lookup',
      (tester) async {
        final store = await ready(
          storage: MemoryStorage(
            appData(customTopics: <Topic>[custom('archived')]),
          ),
        );
        await store.archiveTopic('archived');
        await tester.pumpWidget(MaterialApp(home: TopicsScreen(store: store)));
        expect(find.byTooltip('絞り込みと並び替え'), findsOneWidget);
        await tester.tap(find.byTooltip('絞り込みと並び替え'));
        await tester.pumpAndSettle();
        expect(find.text('すべて'), findsAtLeastNWidgets(1));
        expect(find.text('お気に入り'), findsOneWidget);
        expect(find.text('自作'), findsOneWidget);
        expect(find.text('アーカイブ'), findsOneWidget);
        await tester.tap(find.byTooltip('閉じる'));
        await tester.pumpAndSettle();
        expect(store.topicById('archived'), isNull);
        expect(store.topicByIdIncludingArchived('archived'), isNotNull);
      },
    );
    testWidgets('Topics destination opens a topic detail', (tester) async {
      final store = await ready(storage: MemoryStorage(appData()));
      await tester.pumpWidget(MaterialApp(home: AppShell(store: store)));
      expect(find.byType(NavigationDestination), findsNWidgets(2));
      await tester.tap(find.byType(NavigationDestination).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TopicTile).first);
      await tester.pumpAndSettle();
      expect(find.byType(TopicDetailScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('form creates, v3 saves, edit keeps the topic and reloads', (
      tester,
    ) async {
      final store = await ready();
      await tester.pumpWidget(MaterialApp(home: AppShell(store: store)));
      await tester.tap(find.byType(NavigationDestination).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'created');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(categories.first.name).last);
      await tester.enterText(fields.at(1), 'memo');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      final id = store.customTopics.single.id;
      expect(store.topicById(id)!.description, 'memo');
      final restored = await ready();
      expect(restored.topicById(id)!.title, 'created');
      await store.updateTopic(
        id: id,
        title: 'edited',
        categoryId: 'other',
        description: 'memo',
      );
      expect(store.customTopics, hasLength(1));
      expect(store.topicById(id)!.title, 'edited');
      await tester.tap(find.byType(TopicTile).first);
      await tester.pumpAndSettle();
      expect(find.byType(TopicDetailScreen), findsOneWidget);
    });

    testWidgets('detail prompt/memo structure and favorite screen update', (
      tester,
    ) async {
      final builtinStore = await ready(storage: MemoryStorage(appData()));
      final builtin = builtinStore.topics.first;
      await tester.pumpWidget(
        MaterialApp(
          home: TopicDetailScreen(store: builtinStore, topicId: builtin.id),
        ),
      );
      expect(find.byType(Chip), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(find.text(builtin.description), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(
        builtinStore.favoriteTopics,
        contains(predicate<Topic>((topic) => topic.id == builtin.id)),
      );
      await builtinStore.toggleFavorite(builtin.id);
      expect(builtinStore.favoriteTopics, isEmpty);

      final memoStore = await ready(
        storage: MemoryStorage(
          appData(
            customTopics: <Topic>[
              custom('memo', title: 'memo title', description: 'memo body'),
            ],
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TopicDetailScreen(store: memoStore, topicId: 'memo'),
        ),
      );
      expect(find.text('memo body'), findsOneWidget);
      expect(find.text('memo title'), findsAtLeastNWidgets(1));
    });

    testWidgets(
      'Topics shell reflects direct topic update and archive state changes',
      (tester) async {
        final store = await ready(
          storage: MemoryStorage(
            appData(customTopics: <Topic>[custom('mine')]),
          ),
        );
        await tester.pumpWidget(MaterialApp(home: AppShell(store: store)));
        await tester.tap(find.byType(NavigationDestination).at(1));
        await tester.pumpAndSettle();
        await store.updateTopic(
          id: 'mine',
          title: 'edited mine',
          categoryId: 'other',
          description: '',
        );
        expect(store.customTopics.single.title, 'edited mine');
        expect(store.topicById('mine'), isNotNull);
        await store.archiveTopic('mine');
        expect(store.topicById('mine'), isNull);
        expect(store.topicByIdIncludingArchived('mine'), isNotNull);
      },
    );

    testWidgets('WadaiApp presents loading, error and ready gates', (
      tester,
    ) async {
      final slow = WadeeController(
        storage: MemoryStorage(appData(), delay: true),
      );
      await tester.pumpWidget(
        WadaiApp(key: const ValueKey('slow'), store: slow),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(slow.loadState, AppLoadState.ready);
      final broken = WadeeController(
        storage: MemoryStorage(appData(), failLoads: true),
      );
      await tester.pumpWidget(
        WadaiApp(key: const ValueKey('broken'), store: broken),
      );
      await tester.pumpAndSettle();
      expect(broken.loadState, AppLoadState.error);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets(
      'WadaiApp restores both v1 and v2 SharedPreferences snapshots',
      (tester) async {
        final v1 = jsonEncode(<String, Object>{
          'schemaVersion': 1,
          'customTopics': <Object>[
            <String, Object?>{
              'id': 'from-v1',
              'title': 'v1',
              'categoryId': 'other',
              'description': '',
              'isCustom': true,
              'isFavorite': false,
              'createdAt': null,
            },
          ],
          'favoriteTopicIds': <String>[],
        });
        SharedPreferences.setMockInitialValues(<String, Object>{
          LocalAppStorage.snapshotKey: v1,
        });
        await tester.pumpWidget(const WadaiApp(key: ValueKey('v1-app')));
        await tester.pumpAndSettle();
        expect(find.byType(AppShell), findsOneWidget);

        final v2 = jsonEncode(<String, Object>{
          'schemaVersion': 2,
          'customTopics': <Object>[custom('from-v2').toJson()],
          'favoriteTopicIds': <String>[],
          'archivedTopicIds': <String>[],
          'persons': <Object>[],
          'personTopics': <Object>[],
        });
        SharedPreferences.setMockInitialValues(<String, Object>{
          LocalAppStorage.snapshotKey: v2,
        });
        await tester.pumpWidget(const WadaiApp(key: ValueKey('v2-app')));
        await tester.pumpAndSettle();
        expect(find.byType(AppShell), findsOneWidget);
      },
    );

    testWidgets(
      'People detail edit and delete dialogs preserve then cascade state',
      (tester) async {
        final topic = createStaticTopics().first;
        final person = Person(
          id: 'p',
          displayName: 'before',
          note: 'before note',
          createdAt: DateTime.utc(2026),
        );
        final store = await ready(
          storage: MemoryStorage(
            appData(
              persons: <Person>[person],
              personTopics: <PersonTopic>[
                PersonTopic(
                  personId: 'p',
                  topicId: topic.id,
                  note: 'pair',
                  createdAt: DateTime.utc(2026),
                ),
              ],
            ),
          ),
        );
        await tester.pumpWidget(MaterialApp(home: PeopleScreen(store: store)));
        await tester.tap(find.byType(ListTile).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.edit));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).at(0), 'after');
        await tester.enterText(find.byType(TextFormField).at(1), 'after note');
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(store.personById('p')!.displayName, 'after');
        expect(store.personById('p')!.note, 'after note');
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextButton),
          ),
        );
        await tester.pumpAndSettle();
        expect(store.personById('p'), isNotNull);
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(store.personById('p'), isNull);
        expect(store.personTopics, isEmpty);
        expect(store.topicById(topic.id), isNotNull);
      },
    );

    testWidgets(
      'PersonTopic note and remove dialogs honor cancel and confirmation',
      (tester) async {
        final topic = createStaticTopics().first;
        final person = Person(
          id: 'p',
          displayName: 'p',
          note: '',
          createdAt: DateTime.utc(2026),
        );
        final store = await ready(
          storage: MemoryStorage(
            appData(
              persons: <Person>[person],
              personTopics: <PersonTopic>[
                PersonTopic(
                  personId: 'p',
                  topicId: topic.id,
                  note: 'old',
                  createdAt: DateTime.utc(2026),
                ),
              ],
            ),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: PersonDetailScreen(store: store, personId: 'p'),
          ),
        );
        await tester.tap(find.text(topic.title));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('メモを編集'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('メモを編集'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'cancelled');
        await tester.tap(find.byType(TextButton));
        await tester.pumpAndSettle();
        expect(store.personTopic('p', topic.id)!.note, 'old');
        await tester.ensureVisible(find.text('メモを編集'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('メモを編集'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'saved');
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('保存'),
          ),
        );
        await tester.pumpAndSettle();
        expect(store.personTopic('p', topic.id)!.note, 'saved');
        await tester.ensureVisible(find.text('この話題から外す'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('この話題から外す'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextButton),
          ),
        );
        await tester.pumpAndSettle();
        expect(store.personTopic('p', topic.id), isNotNull);
        await tester.ensureVisible(find.text('この話題から外す'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('この話題から外す'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(FilledButton),
          ),
        );
        await tester.pumpAndSettle();
        expect(store.personTopic('p', topic.id), isNull);
      },
    );

    testWidgets(
      'TopicPicker shows assigned and archived topics as unavailable',
      (tester) async {
        final person = Person(
          id: 'p',
          displayName: 'p',
          note: '',
          createdAt: DateTime.utc(2026),
        );
        final assigned = custom('assigned', title: 'assigned');
        final archived = custom('archived', title: 'archived');
        final available = custom('available', title: 'available');
        final store = await ready(
          storage: MemoryStorage(
            appData(
              customTopics: <Topic>[assigned, archived, available],
              archivedIds: <String>{archived.id},
              persons: <Person>[person],
              personTopics: <PersonTopic>[
                PersonTopic(
                  personId: 'p',
                  topicId: assigned.id,
                  note: '',
                  createdAt: DateTime.utc(2026),
                ),
              ],
            ),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: TopicPickerScreen(store: store, personId: 'p'),
          ),
        );
        await tester.scrollUntilVisible(
          find.text('available'),
          250,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('assigned'), findsOneWidget);
        expect(find.text('追加済み'), findsOneWidget);
        expect(find.text('archived'), findsOneWidget);
        expect(find.text('アーカイブ済み'), findsOneWidget);
        expect(find.text('available'), findsOneWidget);
        expect(find.text('0件を追加'), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('assigned、.*追加済み、選択不可')),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp('archived、.*アーカイブ済み、選択不可')),
          findsOneWidget,
        );
        await tester.tap(find.text('assigned'), warnIfMissed: false);
        await tester.tap(find.text('archived'), warnIfMissed: false);
        await tester.pump();
        expect(find.text('0件を追加'), findsOneWidget);
        expect(store.personTopicsFor(person.id), hasLength(1));
      },
    );

    testWidgets(
      'Topics filters, favorite, custom edit, archive and restore use visible actions',
      (tester) async {
        final customTopic = custom('custom-id', title: 'custom title');
        final store = await ready(
          storage: MemoryStorage(appData(customTopics: <Topic>[customTopic])),
        );
        await tester.pumpWidget(MaterialApp(home: TopicsScreen(store: store)));
        await tester.tap(find.byIcon(Icons.favorite_border).first);
        await tester.pumpAndSettle();
        await applyTopicFilters(tester, display: 'お気に入り');
        expect(find.byType(TopicTile), findsOneWidget);
        await tester.tap(find.byIcon(Icons.favorite));
        await tester.pumpAndSettle();
        expect(find.byType(TopicTile), findsNothing);
        await applyTopicFilters(tester, display: '自作');
        expect(find.text('custom title'), findsOneWidget);
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PopupMenuItem<String>).first);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'edited custom',
        );
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(store.customTopics, hasLength(1));
        expect(find.text('edited custom'), findsOneWidget);
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PopupMenuItem<String>).last);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextButton),
          ),
        );
        await tester.pumpAndSettle();
        expect(store.topicById('custom-id'), isNotNull);
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PopupMenuItem<String>).last);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(FilledButton),
          ),
        );
        await tester.pumpAndSettle();
        expect(store.topicById('custom-id'), isNull);
        await applyTopicFilters(tester, display: 'アーカイブ');
        expect(find.text('edited custom'), findsOneWidget);
        await tester.tap(find.byType(TopicTile));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PopupMenuItem<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(FilledButton),
          ),
        );
        await tester.pumpAndSettle();
        expect(store.topicById('custom-id'), isNotNull);
      },
    );

    testWidgets(
      'built-in archive dialog cancels then confirms and restores from archive detail',
      (tester) async {
        final store = await ready(storage: MemoryStorage(appData()));
        final builtin = store.topics.first;
        await tester.pumpWidget(MaterialApp(home: TopicsScreen(store: store)));
        await tester.tap(find.byType(PopupMenuButton<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PopupMenuItem<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextButton),
          ),
        );
        await tester.pumpAndSettle();
        expect(store.topicById(builtin.id), isNotNull);
        await tester.tap(find.byType(PopupMenuButton<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PopupMenuItem<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(FilledButton),
          ),
        );
        await tester.pumpAndSettle();
        expect(store.topicById(builtin.id), isNull);
        await applyTopicFilters(tester, display: 'アーカイブ');
        await tester.tap(find.byType(TopicTile).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PopupMenuItem<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(FilledButton),
          ),
        );
        await tester.pumpAndSettle();
        expect(store.topicById(builtin.id), isNotNull);
      },
    );
  });

  group('Phase 6 UX', () {
    testWidgets(
      'People searches display names and notes, shows no result, clears, and sorts by name',
      (tester) async {
        final store = await ready(
          storage: MemoryStorage(
            appData(
              persons: <Person>[
                Person(
                  id: 'z',
                  displayName: 'Zoe',
                  note: 'first note',
                  createdAt: DateTime.utc(2026),
                ),
                Person(
                  id: 'a',
                  displayName: 'Alice',
                  note: 'needle memo',
                  createdAt: DateTime.utc(2026),
                ),
              ],
            ),
          ),
        );
        await tester.pumpWidget(MaterialApp(home: PeopleScreen(store: store)));
        await tester.enterText(find.byType(TextField), 'Zoe');
        await tester.pump();
        expect(find.text('Zoe').last, findsOneWidget);
        expect(find.text('Alice'), findsNothing);
        expect(find.byTooltip('検索をクリア'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'needle');
        await tester.pump();
        expect(find.text('Alice'), findsOneWidget);
        expect(find.text('Zoe'), findsNothing);
        await tester.enterText(find.byType(TextField), 'does-not-exist');
        await tester.pump();
        expect(find.text('条件に一致する相手がいません'), findsOneWidget);
        await tester.tap(find.text('検索をクリア'));
        await tester.pump();
        expect(find.text('Zoe'), findsOneWidget);
        expect(find.text('Alice'), findsOneWidget);
        final initialZoeY = tester.getTopLeft(find.text('Zoe')).dy;
        final initialAliceY = tester.getTopLeft(find.text('Alice')).dy;
        expect(initialZoeY, lessThan(initialAliceY));
        await tester.tap(find.text('作成順'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('名前順'));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.text('Alice')).dy,
          lessThan(tester.getTopLeft(find.text('Zoe')).dy),
        );
      },
    );

    testWidgets(
      'Topics searches title description and category, combines filters, sorts, and clears all conditions',
      (tester) async {
        final alpha = Topic(
          id: 'alpha',
          title: 'Alpha unique',
          categoryId: 'work',
          description: 'first description',
          source: TopicSource.userCreated,
          createdAt: DateTime.utc(2026),
        );
        final zebra = Topic(
          id: 'zebra',
          title: 'Zebra unique',
          categoryId: 'work',
          description: 'description token',
          source: TopicSource.userCreated,
          createdAt: DateTime.utc(2026),
        );
        final store = await ready(
          storage: MemoryStorage(
            appData(
              customTopics: <Topic>[alpha, zebra],
              favoriteIds: <String>{alpha.id},
            ),
          ),
        );
        await tester.pumpWidget(MaterialApp(home: TopicsScreen(store: store)));
        final search = find.byType(TextField);
        await tester.enterText(search, 'Alpha unique');
        await tester.pump();
        expect(find.text('Alpha unique').last, findsOneWidget);
        await tester.enterText(search, 'description token');
        await tester.pump();
        expect(find.text('Zebra unique'), findsOneWidget);
        await tester.enterText(search, '仕事');
        await tester.pump();
        expect(find.text('今どんな仕事をしているか'), findsOneWidget);

        await tester.tap(find.byTooltip('検索をクリア'));
        await tester.pump();
        await applyTopicFilters(tester, display: 'お気に入り', category: '仕事');
        expect(find.text('Alpha unique'), findsOneWidget);
        expect(find.text('Zebra unique'), findsNothing);

        await applyTopicFilters(tester, display: 'すべて');
        await tester.enterText(search, 'unique');
        await tester.pump();
        expect(find.text('Alpha unique'), findsOneWidget);

        await tester.enterText(search, 'no matching topic');
        await tester.pump();
        expect(find.text('条件に一致する話題がありません'), findsOneWidget);
        await tester.tap(find.text('フィルターをクリア'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(search).controller!.text,
          'no matching topic',
        );
        await tester.tap(find.byTooltip('検索をクリア'));
        await tester.pumpAndSettle();

        await applyTopicFilters(tester, display: 'アーカイブ');
        expect(find.text('アーカイブした話題がありません'), findsOneWidget);
      },
    );

    testWidgets('Topic picker filters by query and has distinct empty states', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final topic = custom(
        'pick',
        title: 'picker zebra',
        description: 'picker description',
      );
      final alpha = custom('pick-alpha', title: 'picker alpha');
      final person = Person(
        id: 'p',
        displayName: 'P',
        note: '',
        createdAt: DateTime.utc(2026),
      );
      final store = await ready(
        storage: MemoryStorage(
          appData(
            customTopics: <Topic>[topic, alpha],
            persons: <Person>[person],
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TopicPickerScreen(store: store, personId: person.id),
        ),
      );
      await tester.enterText(find.byType(TextField), 'description');
      await tester.pump();
      expect(find.text('picker zebra'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'picker');
      await tester.pump();
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      final otherOption = find.text('その他').last;
      await tester.ensureVisible(otherOption);
      expect(otherOption, findsOneWidget);
      await tester.tap(otherOption);
      await tester.pumpAndSettle();
      expect(find.text('picker alpha'), findsOneWidget);
      expect(find.text('picker zebra'), findsOneWidget);
      await tester.tap(find.text('標準順'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('名前順'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('picker alpha')).dy,
        lessThan(tester.getTopLeft(find.text('picker zebra')).dy),
      );
      await tester.enterText(find.byType(TextField), 'no such topic');
      await tester.pump();
      expect(find.text('条件に一致する話題がありません'), findsOneWidget);
      await tester.tap(find.text('条件をクリア'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('picker zebra'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('picker zebra'), findsOneWidget);

      for (final id in <String>[
        ...createStaticTopics().map((item) => item.id),
        topic.id,
        alpha.id,
      ]) {
        await store.assignTopicToPerson(personId: person.id, topicId: id);
      }
      await tester.pump();
      expect(find.text('追加済み'), findsAtLeastNWidgets(1));
      final emptyStore = await ready(
        storage: MemoryStorage(
          appData(
            persons: <Person>[person],
            archivedIds: createStaticTopics().map((item) => item.id).toSet(),
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TopicPickerScreen(store: emptyStore, personId: person.id),
        ),
      );
      expect(find.text('アーカイブ済み'), findsAtLeastNWidgets(1));
    });

    testWidgets('search and topic actions expose labels and tooltips', (
      tester,
    ) async {
      final topic = custom('accessible', title: 'アクセシブルな話題');
      final store = await ready(
        storage: MemoryStorage(appData(customTopics: <Topic>[topic])),
      );
      await tester.pumpWidget(MaterialApp(home: TopicsScreen(store: store)));
      await tester.enterText(find.byType(TextField), topic.title);
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp('話題を検索。タイトル、説明、カテゴリーを対象にします')),
        findsAtLeastNWidgets(1),
      );
      expect(find.byTooltip('検索をクリア'), findsOneWidget);
      expect(find.byTooltip('話題の操作'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('アクセシブルな話題.*お気に入り')),
        findsAtLeastNWidgets(1),
      );

      final peopleStore = await ready(
        storage: MemoryStorage(
          appData(
            persons: <Person>[
              Person(
                id: 'p',
                displayName: 'アクセシブルな相手',
                note: '',
                createdAt: DateTime.utc(2026),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: PeopleScreen(store: peopleStore)),
      );
      expect(
        find.bySemanticsLabel(RegExp('相手を検索。名前とメモを対象にします')),
        findsAtLeastNWidgets(1),
      );
      expect(find.bySemanticsLabel('アクセシブルな相手、話題0件'), findsOneWidget);
    });

    testWidgets('load retry and save error are announced in the UI', (
      tester,
    ) async {
      final storage = MemoryStorage(appData(), failLoads: true);
      final store = WadeeController(storage: storage);
      await tester.pumpWidget(WadaiApp(store: store));
      await tester.pumpAndSettle();
      expect(find.text('再試行'), findsOneWidget);
      storage.failLoads = false;
      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);

      storage.failSaves = true;
      await tester.tap(find.text('話題'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.favorite_border).first);
      await tester.pumpAndSettle();
      expect(find.text('保存に失敗しました。もう一度試してください。'), findsOneWidget);
    });

    testWidgets(
      'narrow People, Topics and picker surfaces have no layout exception',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final person = Person(
          id: 'p',
          displayName: 'P',
          note: '',
          createdAt: DateTime.utc(2026),
        );
        final store = await ready(
          storage: MemoryStorage(appData(persons: <Person>[person])),
        );
        for (final screen in <Widget>[
          PeopleScreen(store: store),
          TopicsScreen(store: store),
          TopicPickerScreen(store: store, personId: person.id),
        ]) {
          await tester.pumpWidget(MaterialApp(home: screen));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'archived PersonTopic retains its title, note, archive reason and restore action',
      (tester) async {
        final topic = custom('archived-person-topic', title: '残したい話題');
        final person = Person(
          id: 'p',
          displayName: '相手',
          note: '',
          createdAt: DateTime.utc(2026),
        );
        final store = await ready(
          storage: MemoryStorage(
            appData(
              customTopics: <Topic>[topic],
              archivedIds: <String>{topic.id},
              persons: <Person>[person],
              personTopics: <PersonTopic>[
                PersonTopic(
                  personId: person.id,
                  topicId: topic.id,
                  note: '個別のメモ',
                  createdAt: DateTime.utc(2026),
                ),
              ],
            ),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: PersonDetailScreen(store: store, personId: person.id),
          ),
        );
        expect(find.text('残したい話題'), findsOneWidget);
        expect(find.textContaining('個別のメモ'), findsNothing);
        expect(find.text('アーカイブ済み'), findsOneWidget);
        await tester.tap(find.text('残したい話題'));
        await tester.pumpAndSettle();
        expect(find.textContaining('個別のメモ'), findsOneWidget);
        await tester.tap(find.text('話題ライブラリを開く'));
        await tester.pumpAndSettle();
        expect(find.text('この話題は通常の一覧から非表示です。お気に入りの変更はできません。'), findsOneWidget);
        expect(find.text('復元する'), findsOneWidget);
        await tester.tap(find.text('復元する'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(FilledButton),
          ),
        );
        await tester.pumpAndSettle();
        expect(store.topicById(topic.id), isNotNull);
      },
    );
  });

  group('Phase 7 bulk person-topic assignment', () {
    test('bulk assignment is atomic and rejects unavailable IDs', () async {
      final person = Person(
        id: 'p',
        displayName: 'P',
        note: '',
        createdAt: DateTime.utc(2026),
      );
      final first = custom('first', title: 'first');
      final second = custom('second', title: 'second');
      final storage = MemoryStorage(
        appData(
          customTopics: <Topic>[first, second],
          persons: <Person>[person],
        ),
      );
      final store = await ready(storage: storage);

      expect(
        await store.assignTopicsToPerson(
          personId: person.id,
          topicIds: <String>[first.id, second.id],
        ),
        isTrue,
      );
      expect(storage.saveCalls, 1);
      expect(store.personTopicsFor(person.id), hasLength(2));

      final unavailableStorage = MemoryStorage(
        appData(
          customTopics: <Topic>[first, second],
          archivedIds: <String>{second.id},
          persons: <Person>[person],
        ),
      );
      final unavailableStore = await ready(storage: unavailableStorage);
      expect(
        await unavailableStore.assignTopicsToPerson(
          personId: person.id,
          topicIds: <String>[first.id, second.id],
        ),
        isFalse,
      );
      expect(unavailableStorage.saveCalls, 0);
      expect(unavailableStore.personTopicsFor(person.id), isEmpty);

      final assignedStorage = MemoryStorage(
        appData(
          customTopics: <Topic>[first, second],
          persons: <Person>[person],
          personTopics: <PersonTopic>[
            PersonTopic(
              personId: person.id,
              topicId: first.id,
              note: '',
              createdAt: DateTime.utc(2026),
            ),
          ],
        ),
      );
      final assignedStore = await ready(storage: assignedStorage);
      for (final request in <Iterable<String>>[
        <String>[first.id, second.id],
        <String>[second.id, 'unknown'],
        <String>[],
      ]) {
        expect(
          await assignedStore.assignTopicsToPerson(
            personId: person.id,
            topicIds: request,
          ),
          isFalse,
        );
      }
      expect(
        await assignedStore.assignTopicsToPerson(
          personId: 'missing',
          topicIds: <String>[second.id],
        ),
        isFalse,
      );
      expect(assignedStorage.saveCalls, 0);
      expect(assignedStore.personTopicsFor(person.id), hasLength(1));

      expect(
        await store.assignTopicsToPerson(
          personId: person.id,
          topicIds: <String>[first.id, 'unknown'],
        ),
        isFalse,
      );
      expect(storage.saveCalls, 1);
      expect(store.personTopicsFor(person.id), hasLength(2));

      final failedStorage = MemoryStorage(
        appData(
          customTopics: <Topic>[first, second],
          persons: <Person>[person],
        ),
        failSaves: true,
      );
      final failedStore = await ready(storage: failedStorage);
      expect(
        await failedStore.assignTopicsToPerson(
          personId: person.id,
          topicIds: <String>[first.id, second.id],
        ),
        isFalse,
      );
      expect(failedStore.personTopicsFor(person.id), isEmpty);
    });

    testWidgets(
      'picker keeps selections across condition changes and shows count',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final person = Person(
          id: 'p',
          displayName: 'P',
          note: '',
          createdAt: DateTime.utc(2026),
        );
        final alpha = custom('alpha', title: 'alpha');
        final zebra = custom('zebra', title: 'zebra');
        final store = await ready(
          storage: MemoryStorage(
            appData(
              customTopics: <Topic>[alpha, zebra],
              persons: <Person>[person],
            ),
          ),
        );
        await store.toggleFavorite(alpha.id);
        await tester.pumpWidget(
          MaterialApp(
            home: TopicPickerScreen(store: store, personId: person.id),
          ),
        );

        final addButton = find.widgetWithText(FilledButton, '0件を追加');
        expect(tester.widget<FilledButton>(addButton).onPressed, isNull);
        await tester.scrollUntilVisible(
          find.text('alpha'),
          250,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('alpha'));
        await tester.pump();
        expect(find.text('1件を追加'), findsOneWidget);
        expect(find.bySemanticsLabel('Pに1件の話題を追加'), findsOneWidget);

        await tester.tap(find.text('お気に入り'));
        await tester.pump();
        expect(find.text('1件を追加'), findsOneWidget);
        await tester.tap(find.text('自作'));
        await tester.pump();
        expect(find.text('1件を追加'), findsOneWidget);
        await tester.tap(find.byType(DropdownButtonFormField<String?>));
        await tester.pumpAndSettle();
        final otherOption = find.text('その他').last;
        await tester.ensureVisible(otherOption);
        expect(otherOption, findsOneWidget);
        await tester.tap(otherOption);
        await tester.pumpAndSettle();
        await tester.tap(find.text('標準順'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('名前順'));
        await tester.pumpAndSettle();
        expect(find.text('1件を追加'), findsOneWidget);
        await tester.tap(find.text('すべて').first);
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'zebra');
        await tester.pump();
        expect(find.text('alpha'), findsNothing);
        await tester.tap(find.text('zebra').last);
        await tester.pump();
        expect(find.text('2件を追加'), findsOneWidget);
        await tester.tap(find.byTooltip('検索をクリア'));
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text('alpha'),
          250,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('alpha'), findsOneWidget);
        expect(find.text('2件を追加'), findsOneWidget);
      },
    );

    testWidgets('picker bulk add saves once, pops, and updates Person detail', (
      tester,
    ) async {
      final person = Person(
        id: 'p',
        displayName: 'P',
        note: '',
        createdAt: DateTime.utc(2026),
      );
      final first = custom('bulk-first', title: 'Bulk first');
      final second = custom('bulk-second', title: 'Bulk second');
      final storage = MemoryStorage(
        appData(
          customTopics: <Topic>[first, second],
          persons: <Person>[person],
        ),
      );
      final store = await ready(storage: storage);
      await tester.pumpWidget(
        MaterialApp(
          home: PersonDetailScreen(store: store, personId: person.id),
        ),
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), first.title);
      await tester.pump();
      await tester.tap(find.text(first.title).last);
      await tester.pump();
      await tester.enterText(find.byType(TextField), second.title);
      await tester.pump();
      await tester.tap(find.text(second.title).last);
      await tester.pump();
      expect(find.bySemanticsLabel('Pに2件の話題を追加'), findsOneWidget);

      await tester.tap(find.text('2件を追加'));
      await tester.pumpAndSettle();
      expect(find.byType(TopicPickerScreen), findsNothing);
      expect(find.text('相手全般のメモ'), findsOneWidget);
      expect(find.text(first.title), findsOneWidget);
      expect(find.text(second.title), findsOneWidget);
      expect(storage.saveCalls, 1);
      expect(store.personTopicsFor(person.id), hasLength(2));
    });

    testWidgets(
      'narrow picker keeps its fixed action usable without overflow',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final person = Person(
          id: 'p',
          displayName: 'P',
          note: '',
          createdAt: DateTime.utc(2026),
        );
        final topic = custom('narrow-picker', title: 'narrow picker');
        final store = await ready(
          storage: MemoryStorage(
            appData(customTopics: <Topic>[topic], persons: <Person>[person]),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: TopicPickerScreen(store: store, personId: person.id),
          ),
        );
        await tester.enterText(find.byType(TextField), topic.title);
        await tester.pump();
        await tester.tap(find.text(topic.title).last);
        await tester.pump();
        expect(find.text('1件を追加'), findsOneWidget);
        await tester.tap(find.text('お気に入り'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'picker save failure keeps every selection and reports the error',
      (tester) async {
        final person = Person(
          id: 'p',
          displayName: 'P',
          note: '',
          createdAt: DateTime.utc(2026),
        );
        final first = custom('failed-first', title: 'Failed first');
        final second = custom('failed-second', title: 'Failed second');
        final storage = MemoryStorage(
          appData(
            customTopics: <Topic>[first, second],
            persons: <Person>[person],
          ),
          failSaves: true,
        );
        final store = await ready(storage: storage);
        await tester.pumpWidget(
          MaterialApp(
            home: TopicPickerScreen(store: store, personId: person.id),
          ),
        );

        await tester.enterText(find.byType(TextField), first.title);
        await tester.pump();
        await tester.tap(find.text(first.title).last);
        await tester.enterText(find.byType(TextField), second.title);
        await tester.pump();
        await tester.tap(find.text(second.title).last);
        await tester.pump();
        await tester.tap(find.text('2件を追加'));
        await tester.pumpAndSettle();

        expect(find.byType(TopicPickerScreen), findsOneWidget);
        expect(find.text('2件を追加'), findsOneWidget);
        expect(find.bySemanticsLabel('Pに2件の話題を追加'), findsOneWidget);
        expect(store.personTopicsFor(person.id), isEmpty);
        expect(storage.saveCalls, 1);
        expect(find.text('保存に失敗しました。もう一度試してください。'), findsOneWidget);
      },
    );

    test('bulk assignment validates against the latest queued state', () async {
      final person = Person(
        id: 'p',
        displayName: 'P',
        note: '',
        createdAt: DateTime.utc(2026),
      );
      final first = custom('queue-first');
      final second = custom('queue-second');
      final storage = MemoryStorage(
        appData(
          customTopics: <Topic>[first, second],
          persons: <Person>[person],
        ),
        delay: true,
      );
      final store = await ready(storage: storage);

      final archive = store.archiveTopic(second.id);
      final bulk = store.assignTopicsToPerson(
        personId: person.id,
        topicIds: <String>[first.id, second.id],
      );

      expect(await archive, isTrue);
      expect(await bulk, isFalse);
      expect(storage.saveCalls, 1);
      expect(store.personTopicsFor(person.id), isEmpty);
      expect(store.isArchived(second.id), isTrue);
    });
  });

  group('Phase 8 person-topic detail and topic filters', () {
    Future<
      ({
        MemoryStorage storage,
        WadeeController store,
        Person person,
        Topic topic,
      })
    >
    detailFixture({bool failSaves = false}) async {
      final person = Person(
        id: 'detail-person',
        displayName: 'Detail person',
        note: '',
        createdAt: DateTime.utc(2026),
      );
      final topic = custom(
        'detail-topic',
        title: 'Detail topic',
        description: 'Shared description',
      );
      final storage = MemoryStorage(
        appData(
          customTopics: <Topic>[topic],
          persons: <Person>[person],
          personTopics: <PersonTopic>[
            PersonTopic(
              personId: person.id,
              topicId: topic.id,
              note: 'Initial relation note',
              createdAt: DateTime.utc(2026),
            ),
          ],
        ),
        failSaves: failSaves,
      );
      return (
        storage: storage,
        store: await ready(storage: storage),
        person: person,
        topic: topic,
      );
    }

    testWidgets('detail shows all statuses and persists an actual selection', (
      tester,
    ) async {
      final fixture = await detailFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: PersonTopicDetailScreen(
            store: fixture.store,
            personId: fixture.person.id,
            topicId: fixture.topic.id,
          ),
        ),
      );
      for (final status in PersonTopicStatus.values) {
        expect(find.text(status.label), findsOneWidget);
      }
      await tester.tap(find.text(PersonTopicStatus.discussed.label));
      await tester.pumpAndSettle();
      expect(
        fixture.store.personTopic(fixture.person.id, fixture.topic.id)!.status,
        PersonTopicStatus.discussed,
      );
      expect(
        tester
            .widget<RadioGroup<PersonTopicStatus>>(
              find.byType(RadioGroup<PersonTopicStatus>),
            )
            .groupValue,
        PersonTopicStatus.discussed,
      );
      final reloaded = await ready(storage: fixture.storage);
      expect(
        reloaded.personTopic(fixture.person.id, fixture.topic.id)!.status,
        PersonTopicStatus.discussed,
      );
    });

    testWidgets('detail keeps status and note unchanged when saving fails', (
      tester,
    ) async {
      final fixture = await detailFixture(failSaves: true);
      await tester.pumpWidget(
        MaterialApp(
          home: PersonTopicDetailScreen(
            store: fixture.store,
            personId: fixture.person.id,
            topicId: fixture.topic.id,
          ),
        ),
      );
      await tester.tap(find.text(PersonTopicStatus.revisit.label));
      await tester.pumpAndSettle();
      expect(
        fixture.store.personTopic(fixture.person.id, fixture.topic.id)!.status,
        PersonTopicStatus.planned,
      );
      expect(find.byType(SnackBar), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('メモを編集'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Failed update');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        fixture.store.personTopic(fixture.person.id, fixture.topic.id)!.note,
        'Initial relation note',
      );
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets(
      'person-topic card is compact, hides its note, and opens detail',
      (tester) async {
        final fixture = await detailFixture();
        await tester.pumpWidget(
          MaterialApp(
            home: PersonDetailScreen(
              store: fixture.store,
              personId: fixture.person.id,
            ),
          ),
        );
        expect(find.text('Initial relation note'), findsNothing);
        expect(find.byType(Chip), findsNothing);
        await tester.tap(find.text(fixture.topic.title));
        await tester.pumpAndSettle();
        expect(find.byType(PersonTopicDetailScreen), findsOneWidget);
        expect(find.text('Initial relation note'), findsOneWidget);
      },
    );

    testWidgets(
      'filter draft dismisses, applies chips, clears one, and keeps search',
      (tester) async {
        final alpha = Topic(
          id: 'filter-alpha',
          title: 'Alpha filter',
          categoryId: 'work',
          description: '',
          source: TopicSource.userCreated,
          createdAt: DateTime.utc(2026),
        );
        final store = await ready(
          storage: MemoryStorage(
            appData(
              customTopics: <Topic>[alpha],
              favoriteIds: <String>{alpha.id},
            ),
          ),
        );
        await tester.pumpWidget(MaterialApp(home: TopicsScreen(store: store)));
        expect(find.byType(SegmentedButton<TopicFilter>), findsNothing);
        expect(find.byType(DropdownButtonFormField<String?>), findsNothing);
        expect(find.byTooltip('絞り込みと並び替え'), findsOneWidget);
        expect(find.bySemanticsLabel('絞り込みと並び替え'), findsOneWidget);

        await tester.tap(find.byTooltip('絞り込みと並び替え'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('お気に入り'));
        await tester.pump();
        await tester.tap(find.byTooltip('閉じる'));
        await tester.pumpAndSettle();
        expect(find.byType(InputChip), findsNothing);

        await tester.enterText(find.byType(TextField), 'Alpha');
        await applyTopicFilters(tester, display: 'お気に入り', category: '仕事');
        expect(find.byType(Badge), findsOneWidget);
        expect(find.byType(InputChip), findsNWidgets(2));
        expect(find.text('お気に入り'), findsOneWidget);
        expect(find.widgetWithText(InputChip, '仕事'), findsOneWidget);
        expect(find.text('すべて解除'), findsOneWidget);

        final categoryChip = find.widgetWithText(InputChip, '仕事');
        final chipRect = tester.getRect(categoryChip);
        await tester.tapAt(Offset(chipRect.right - 12, chipRect.center.dy));
        await tester.pump();
        expect(categoryChip, findsNothing);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Alpha',
        );
        await applyTopicFilters(tester, category: '仕事');
        await tester.tap(find.text('すべて解除'));
        await tester.pump();
        expect(find.byType(InputChip), findsNothing);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Alpha',
        );
      },
    );

    testWidgets('filter sheet stays usable at 320px and 1.5 text scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final topic = custom('narrow-filter', title: 'Narrow filter');
      final store = await ready(
        storage: MemoryStorage(
          appData(
            customTopics: <Topic>[topic],
            favoriteIds: <String>{topic.id},
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: TopicsScreen(store: store),
          ),
        ),
      );
      await tester.tap(find.byTooltip('絞り込みと並び替え'));
      await tester.pumpAndSettle();
      expect(find.text('絞り込みと並び替え'), findsOneWidget);
      await tester.tap(find.text('お気に入り'));
      await tester.pump();
      await tester.drag(
        find.byKey(const Key('topic-filter-sheet-list')),
        const Offset(0, -800),
      );
      await tester.pumpAndSettle();
      final apply = find.descendant(
        of: find.byType(FilledButton),
        matching: find.textContaining('件を表示'),
      );
      expect(apply, findsOneWidget);
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
      expect(find.widgetWithText(InputChip, 'お気に入り'), findsOneWidget);
      await tester.tap(find.byTooltip('絞り込みと並び替え'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('閉じる'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('美容カテゴリー', () {
    testWidgets('話題フォームで美容を選択して保存し、再読み込み後も保持される', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final storage = MemoryStorage(appData());
      final store = await ready(storage: storage);
      await tester.pumpWidget(MaterialApp(home: TopicsScreen(store: store)));

      await tester.tap(find.text('話題を作成'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '美容の話題');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('美容').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('話題を保存する'));
      await tester.pumpAndSettle();

      expect(store.customTopics.single.categoryId, 'beauty');
      final reloaded = await ready(storage: storage);
      expect(reloaded.customTopics.single.categoryId, 'beauty');
    });

    testWidgets('話題検索と検索条件シートで美容カテゴリーに絞り込める', (tester) async {
      final beauty = Topic(
        id: 'beauty-topic',
        title: '美容の話題',
        categoryId: 'beauty',
        description: '',
        source: TopicSource.userCreated,
        createdAt: DateTime.utc(2026),
      );
      final work = Topic(
        id: 'work-topic',
        title: '仕事の話題',
        categoryId: 'work',
        description: '',
        source: TopicSource.userCreated,
        createdAt: DateTime.utc(2026),
      );
      final store = await ready(
        storage: MemoryStorage(appData(customTopics: <Topic>[beauty, work])),
      );
      await tester.pumpWidget(MaterialApp(home: TopicsScreen(store: store)));

      final search = find.byType(TextField);
      await tester.enterText(search, '美容');
      await tester.pump();
      expect(find.text(beauty.title), findsOneWidget);
      expect(find.text(work.title), findsNothing);
      await tester.tap(find.byTooltip('検索をクリア'));
      await tester.pump();

      await tester.tap(find.byTooltip('絞り込みと並び替え'));
      await tester.pumpAndSettle();
      final beautyOption = find.widgetWithText(RadioListTile<String?>, '美容');
      await tester.ensureVisible(beautyOption);
      await tester.pumpAndSettle();
      expect(beautyOption, findsOneWidget);
      await tester.tap(beautyOption);
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.textContaining('件を表示'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(beauty.title), findsOneWidget);
      expect(find.text(work.title), findsNothing);
    });

    testWidgets('TopicPickerで美容カテゴリーを表示して絞り込める', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final person = Person(
        id: 'beauty-picker-person',
        displayName: 'P',
        note: '',
        createdAt: DateTime.utc(2026),
      );
      final beauty = Topic(
        id: 'beauty-picker-topic',
        title: '美容の話題',
        categoryId: 'beauty',
        description: '',
        source: TopicSource.userCreated,
        createdAt: DateTime.utc(2026),
      );
      final other = Topic(
        id: 'other-picker-topic',
        title: 'その他の話題',
        categoryId: 'other',
        description: '',
        source: TopicSource.userCreated,
        createdAt: DateTime.utc(2026),
      );
      final store = await ready(
        storage: MemoryStorage(
          appData(
            customTopics: <Topic>[beauty, other],
            persons: <Person>[person],
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TopicPickerScreen(store: store, personId: person.id),
        ),
      );
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('美容').last);
      await tester.pumpAndSettle();

      expect(find.text(beauty.title), findsOneWidget);
      expect(find.text(other.title), findsNothing);
    });

    test('美容カテゴリーは専用アイコンを返す', () {
      expect(categoryIcon('beauty'), Icons.face_retouching_natural_outlined);
    });
  });
}
