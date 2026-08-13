import 'package:flutter/material.dart';

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
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Card(
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
                          Text(
                            '相手全般のメモ',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            person.note.trim().isEmpty
                                ? '全般メモはありません。'
                                : person.note,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('この相手との話題', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(width: 8),
                Text(
                  '${assigned.length}件',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (assigned.isEmpty)
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
                        onPressed: () => _pickTopic(context, person.id),
                        icon: const Icon(Icons.add),
                        label: const Text('話題を追加'),
                      ),
                    ],
                  ),
                ),
              ),
            ...assigned.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PersonTopicCard(store: store, item: item),
              ),
            ),
          ],
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
      label: '${topic.title}、${item.status.label}${archived ? '、アーカイブ済み' : ''}',
      child: Card(
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
}
