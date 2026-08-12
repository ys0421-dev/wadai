import 'package:flutter/material.dart';

import '../../models/person.dart';
import '../../models/person_topic.dart';
import '../../state/wadee_controller.dart';
import '../../shared/widgets/empty_state.dart';
import '../topics/topic_actions.dart';
import '../topics/topic_detail_screen.dart';
import 'person_form_screen.dart';
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
            Text('全般メモ', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(person.note.trim().isEmpty ? 'メモはありません。' : person.note),
            const SizedBox(height: 28),
            Text('割り当てた話題', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (assigned.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('まだ話題は割り当てられていません。'),
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
              (item) => _PersonTopicCard(store: store, item: item),
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

class _PersonTopicCard extends StatefulWidget {
  const _PersonTopicCard({required this.store, required this.item});

  final WadeeController store;
  final PersonTopic item;

  @override
  State<_PersonTopicCard> createState() => _PersonTopicCardState();
}

class _PersonTopicCardState extends State<_PersonTopicCard> {
  @override
  Widget build(BuildContext context) {
    final topic = widget.store.topicByIdIncludingArchived(widget.item.topicId);
    if (topic == null) return const SizedBox.shrink();
    final archived = widget.store.isArchived(topic.id);
    final note = widget.item.note.trim();
    return Semantics(
      button: true,
      label:
          '${topic.title}${archived ? '、アーカイブ済み' : ''}${note.isEmpty ? '、相手ごとのメモなし' : '、相手ごとのメモあり'}',
      child: Card(
        child: ListTile(
          title: Row(
            children: [
              Expanded(child: Text(topic.title)),
              if (archived) const Chip(label: Text('アーカイブ済み')),
            ],
          ),
          subtitle: Text(note.isEmpty ? 'この相手とのメモはありません。' : 'この相手とのメモ: $note'),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) =>
                  TopicDetailScreen(store: widget.store, topicId: topic.id),
            ),
          ),
          trailing: PopupMenuButton<String>(
            tooltip: 'この話題の操作',
            onSelected: (value) {
              if (value == 'note') {
                _editNote();
              } else {
                _remove();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'note', child: Text('この相手とのメモを編集')),
              PopupMenuItem(value: 'remove', child: Text('割り当てを解除')),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editNote() async {
    var value = widget.item.note;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('この相手とのメモ'),
        content: TextFormField(
          initialValue: value,
          minLines: 3,
          maxLines: 6,
          textInputAction: TextInputAction.newline,
          autofocus: true,
          onChanged: (newValue) => value = newValue,
          decoration: const InputDecoration(labelText: 'メモ'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    final success = await widget.store.updatePersonTopicNote(
      personId: widget.item.personId,
      topicId: widget.item.topicId,
      note: value.trim(),
    );
    if (!success && mounted) showStoreError(context, widget.store);
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('割り当てを解除しますか？'),
        content: const Text('この相手とのメモも削除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('解除する'),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        !await widget.store.removeTopicFromPerson(
          personId: widget.item.personId,
          topicId: widget.item.topicId,
        ) &&
        mounted) {
      showStoreError(context, widget.store);
    }
  }
}
