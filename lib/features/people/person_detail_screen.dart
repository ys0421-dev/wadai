import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../models/person.dart';
import '../../models/person_topic.dart';
import '../../models/topic.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/initial_avatar.dart';
import '../../state/wadee_controller.dart';
import '../ai/ai_suggestion_screen.dart';
import '../ai/local_ai_service.dart';
import '../ai/local_model_manager.dart';
import '../topics/topic_actions.dart';
import 'person_form_screen.dart';
import 'person_topic_detail_screen.dart';
import 'topic_picker_screen.dart';

class PersonDetailScreen extends StatelessWidget {
  const PersonDetailScreen({
    required this.store,
    required this.personId,
    this.modelManager,
    this.aiServiceFactory,
    super.key,
  });

  final WadeeController store;
  final String personId;
  final LocalModelManager? modelManager;
  final LocalAIService Function(String modelPath)? aiServiceFactory;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final person = store.personById(personId);
      if (person == null) {
        return const Scaffold(
          body: EmptyState(
            icon: Icons.person_off_outlined,
            title: '相手が見つかりません',
            message: '削除された可能性があります。',
          ),
        );
      }
      final assigned = store.personTopicsFor(person.id);
      return Scaffold(
        appBar: AppBar(
          title: Text(person.displayName),
          actions: [
            IconButton(
              onPressed: () => _edit(context, person),
              icon: const Icon(Icons.edit),
              tooltip: '相手を編集',
            ),
            IconButton(
              onPressed: () => _delete(context, person),
              icon: const Icon(Icons.delete_outline),
              tooltip: '相手を削除',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _pickTopic(context, person.id),
          icon: const Icon(Icons.add),
          label: const Text('話題を追加'),
        ),
        body: assigned.isEmpty
            ? _EmptyPersonTopicsBody(
                store: store,
                person: person,
                onAddTopic: () => _pickTopic(context, person.id),
                onSuggestTopics: () => _openAiSuggestions(context, person),
              )
            : _PersonTopicsBody(
                store: store,
                person: person,
                assigned: assigned,
                onAddTopic: () => _pickTopic(context, person.id),
                onSuggestTopics: () => _openAiSuggestions(context, person),
              ),
      );
    },
  );

  Future<void> _edit(BuildContext context, Person person) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => PersonFormScreen(store: store, person: person),
        ),
      );

  Future<void> _pickTopic(BuildContext context, String id) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => TopicPickerScreen(store: store, personId: id),
        ),
      );

  Future<void> _openAiSuggestions(BuildContext context, Person person) {
    final suppliedManager = modelManager;
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AiSuggestionScreen(
          store: store,
          person: person,
          modelManager: suppliedManager ?? LocalModelManager(),
          disposeModelManager: suppliedManager == null,
          serviceFactory:
              aiServiceFactory ??
              (modelPath) => LlamaLocalAIService(modelPath: modelPath),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, Person person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('相手を削除しますか？'),
        content: Text(
          '「${person.displayName}」と関連する話題の割り当て・相手ごとのメモを削除します。話題そのものは残ります。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (await store.deletePerson(person.id)) {
      if (context.mounted) Navigator.of(context).pop();
    } else if (context.mounted) {
      showStoreError(context, store);
    }
  }
}

class _EmptyPersonTopicsBody extends StatelessWidget {
  const _EmptyPersonTopicsBody({
    required this.store,
    required this.person,
    required this.onAddTopic,
    required this.onSuggestTopics,
  });

  final WadeeController store;
  final Person person;
  final VoidCallback onAddTopic;
  final VoidCallback onSuggestTopics;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
    children: [
      _PersonProfileCard(store: store, person: person),
      const SizedBox(height: 12),
      _AiSuggestionButton(onPressed: onSuggestTopics),
      const SizedBox(height: 24),
      _TopicsHeading(count: 0),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('この相手との話題はまだありません。'),
              const SizedBox(height: 8),
              const Text('話題を追加すると、この相手だけのメモを残せます。'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onAddTopic,
                icon: const Icon(Icons.add),
                label: const Text('話題を追加'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _PersonTopicsBody extends StatelessWidget {
  const _PersonTopicsBody({
    required this.store,
    required this.person,
    required this.assigned,
    required this.onAddTopic,
    required this.onSuggestTopics,
  });

  final WadeeController store;
  final Person person;
  final List<PersonTopic> assigned;
  final VoidCallback onAddTopic;
  final VoidCallback onSuggestTopics;

  @override
  Widget build(BuildContext context) {
    final scaledTabHeight =
        kMinInteractiveDimension * MediaQuery.textScalerOf(context).scale(1);
    final tabHeight = scaledTabHeight < kMinInteractiveDimension
        ? kMinInteractiveDimension
        : scaledTabHeight;
    final toTalk = assigned
        .where((item) => item.status != PersonTopicStatus.discussed)
        .toList(growable: false);
    final discussed = assigned
        .where((item) => item.status == PersonTopicStatus.discussed)
        .toList(growable: false);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _PersonProfileCard(store: store, person: person),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _AiSuggestionButton(onPressed: onSuggestTopics),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: _TopicsHeading(count: assigned.length),
                  ),
                ],
              ),
            ),
          ),
          TabBar(
            labelColor: brandColor,
            unselectedLabelColor: appSecondaryTextColor,
            indicatorColor: brandColor,
            indicatorWeight: 3,
            tabs: [
              Tab(height: tabHeight, text: '話す（${toTalk.length}）'),
              Tab(height: tabHeight, text: '話した（${discussed.length}）'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _TopicList(
                  store: store,
                  items: toTalk,
                  emptyState: _ToTalkEmptyState(onAddTopic: onAddTopic),
                  statuses: const [
                    PersonTopicStatus.planned,
                    PersonTopicStatus.revisit,
                  ],
                ),
                _TopicList(
                  store: store,
                  items: discussed,
                  emptyState: const _DiscussedEmptyState(),
                  statuses: const [PersonTopicStatus.discussed],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonProfileCard extends StatelessWidget {
  const _PersonProfileCard({required this.store, required this.person});

  final WadeeController store;
  final Person person;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InitialAvatar(displayName: person.displayName, radius: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  person.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (person.profile.isEmpty) ...[
            const Text('プロフィールを追加すると、AIの提案がより相手に合いやすくなります。'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => PersonFormScreen(
                    store: store,
                    person: person,
                    initiallyExpandProfile: true,
                  ),
                ),
              ),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('プロフィールを追加'),
            ),
          ] else ...[
            Text('プロフィール', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            ...person.profile.orderedEntries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ProfileEntry(label: entry.key, value: entry.value),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text('全般メモ', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            person.note.trim().isEmpty ? '全般メモはありません。' : person.note,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
}

class _ProfileEntry extends StatelessWidget {
  const _ProfileEntry({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 2),
      Text(value, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}

class _AiSuggestionButton extends StatelessWidget {
  const _AiSuggestionButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.auto_awesome),
      label: const Text('AIで話題を提案'),
    ),
  );
}

class _TopicsHeading extends StatelessWidget {
  const _TopicsHeading({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text('この相手との話題', style: Theme.of(context).textTheme.titleLarge),
      Text('$count件', style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}

class _TopicList extends StatelessWidget {
  const _TopicList({
    required this.store,
    required this.items,
    required this.emptyState,
    required this.statuses,
  });

  final WadeeController store;
  final List<PersonTopic> items;
  final Widget emptyState;
  final List<PersonTopicStatus> statuses;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [emptyState],
      );
    }
    final groups = <Widget>[];
    for (final status in statuses) {
      final statusItems = items
          .where((item) => item.status == status)
          .toList(growable: false);
      if (statusItems.isEmpty) {
        continue;
      }
      if (groups.isNotEmpty) {
        groups.add(const SizedBox(height: 16));
      }
      groups.add(
        _StatusGroup(store: store, status: status, items: statusItems),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: groups,
    );
  }
}

class _StatusGroup extends StatelessWidget {
  const _StatusGroup({
    required this.store,
    required this.status,
    required this.items,
  });

  final WadeeController store;
  final PersonTopicStatus status;
  final List<PersonTopic> items;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        status.label,
        key: ValueKey('status-group-${status.name}'),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 8),
      ...items.map(
        (item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _PersonTopicCard(store: store, item: item),
        ),
      ),
    ],
  );
}

class _ToTalkEmptyState extends StatelessWidget {
  const _ToTalkEmptyState({required this.onAddTopic});

  final VoidCallback onAddTopic;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('これから話す話題はありません'),
          const SizedBox(height: 8),
          const Text('話した話題は「話した」タブで確認できます。'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAddTopic,
            icon: const Icon(Icons.add),
            label: const Text('話題を追加'),
          ),
        ],
      ),
    ),
  );
}

class _DiscussedEmptyState extends StatelessWidget {
  const _DiscussedEmptyState();

  @override
  Widget build(BuildContext context) => Card(
    child: const Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('話した話題はまだありません'),
          SizedBox(height: 8),
          Text('話題のステータスを「話した」にすると、ここに表示されます。'),
        ],
      ),
    ),
  );
}

class _PersonTopicCard extends StatelessWidget {
  const _PersonTopicCard({required this.store, required this.item});

  final WadeeController store;
  final PersonTopic item;

  @override
  Widget build(BuildContext context) {
    final topic = store.topicByIdIncludingArchived(item.topicId);
    if (topic == null) return const SizedBox.shrink();
    final archived = store.isArchived(topic.id);
    return Semantics(
      button: true,
      label:
          '${topic.title}、${item.status.label}、${store.categoryName(topic.categoryId)}${archived ? '、アーカイブ済み' : ''}',
      child: Card(
        color: _containerColor(item.status),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _outlineColor(item.status)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => PersonTopicDetailScreen(
                store: store,
                personId: item.personId,
                topicId: item.topicId,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        topic.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                if (topic.openingQuestion.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(topic.openingQuestion),
                ],
                if (topic.talkingPoints.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ...topic.talkingPoints
                      .take(2)
                      .map(
                        (point) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text('・$point'),
                        ),
                      ),
                  if (topic.talkingPoints.length > 2)
                    Text(
                      'ほか ${topic.talkingPoints.length - 2}件',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      store.categoryName(topic.categoryId),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon(item.status), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          item.status.label,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    if (topic.scope == TopicScope.person)
                      Text(
                        'この相手専用',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (topic.source == TopicSource.aiGenerated)
                      Text(
                        'AI提案',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (archived)
                      Text(
                        'アーカイブ済み',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _statusIcon(PersonTopicStatus status) => switch (status) {
    PersonTopicStatus.planned => Icons.schedule_outlined,
    PersonTopicStatus.discussed => Icons.check_circle_outline,
    PersonTopicStatus.revisit => Icons.refresh_outlined,
  };

  Color _containerColor(PersonTopicStatus status) => switch (status) {
    PersonTopicStatus.planned => plannedTopicContainerColor,
    PersonTopicStatus.revisit => revisitTopicContainerColor,
    PersonTopicStatus.discussed => discussedTopicContainerColor,
  };

  Color _outlineColor(PersonTopicStatus status) => switch (status) {
    PersonTopicStatus.planned => plannedTopicOutlineColor,
    PersonTopicStatus.revisit => revisitTopicOutlineColor,
    PersonTopicStatus.discussed => discussedTopicOutlineColor,
  };
}
