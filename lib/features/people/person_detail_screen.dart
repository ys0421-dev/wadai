import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../models/person.dart';
import '../../models/person_topic.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/initial_avatar.dart';
import '../../state/wadee_controller.dart';
import '../topics/topic_actions.dart';
import 'person_form_screen.dart';
import 'person_topic_detail_screen.dart';
import 'topic_picker_screen.dart';

class PersonDetailScreen extends StatelessWidget {
  const PersonDetailScreen({
    required this.store,
    required this.personId,
    super.key,
  });

  final WadeeController store;
  final String personId;

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
                person: person,
                onAddTopic: () => _pickTopic(context, person.id),
              )
            : _PersonTopicsBody(
                store: store,
                person: person,
                assigned: assigned,
                onAddTopic: () => _pickTopic(context, person.id),
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
    required this.person,
    required this.onAddTopic,
  });

  final Person person;
  final VoidCallback onAddTopic;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
    children: [
      _PersonProfileCard(person: person),
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
  });

  final WadeeController store;
  final Person person;
  final List<PersonTopic> assigned;
  final VoidCallback onAddTopic;

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
                    child: _PersonProfileCard(person: person),
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
                  grouped: true,
                ),
                _TopicList(
                  store: store,
                  items: discussed,
                  emptyState: const _DiscussedEmptyState(),
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
  const _PersonProfileCard({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialAvatar(displayName: person.displayName, radius: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('相手全般のメモ', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(
                  person.note.trim().isEmpty ? '全般メモはありません。' : person.note,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
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
    this.grouped = false,
  });

  final WadeeController store;
  final List<PersonTopic> items;
  final Widget emptyState;
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [emptyState],
      );
    }
    final planned = items
        .where((item) => item.status == PersonTopicStatus.planned)
        .toList(growable: false);
    final revisit = items
        .where((item) => item.status == PersonTopicStatus.revisit)
        .toList(growable: false);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (grouped) ...[
          if (planned.isNotEmpty) ...[
            _StatusGroup(
              store: store,
              status: PersonTopicStatus.planned,
              items: planned,
            ),
            if (revisit.isNotEmpty) const SizedBox(height: 16),
          ],
          if (revisit.isNotEmpty)
            _StatusGroup(
              store: store,
              status: PersonTopicStatus.revisit,
              items: revisit,
            ),
        ] else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PersonTopicCard(store: store, item: item),
            ),
          ),
      ],
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
      Text(status.label, style: Theme.of(context).textTheme.titleSmall),
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
                if (topic.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    topic.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
