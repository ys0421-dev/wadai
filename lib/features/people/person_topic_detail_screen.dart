import 'package:flutter/material.dart';

import '../../models/person_topic.dart';
import '../../state/wadee_controller.dart';
import '../topics/topic_actions.dart';
import '../topics/topic_detail_screen.dart';

class PersonTopicDetailScreen extends StatefulWidget {
  const PersonTopicDetailScreen({
    required this.store,
    required this.personId,
    required this.topicId,
    super.key,
  });
  final WadeeController store;
  final String personId;
  final String topicId;
  @override
  State<PersonTopicDetailScreen> createState() =>
      _PersonTopicDetailScreenState();
}

class _PersonTopicDetailScreenState extends State<PersonTopicDetailScreen> {
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final item = widget.store.personTopic(widget.personId, widget.topicId);
      final topic = widget.store.topicByIdIncludingArchived(widget.topicId);
      if (item == null || topic == null) {
        return const Scaffold(body: Center(child: Text('話題が見つかりません')));
      }
      final archived = widget.store.isArchived(topic.id);
      return Scaffold(
        appBar: AppBar(title: const Text('この相手との話題')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('共有する話題', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.store.categoryName(topic.categoryId),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (archived)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Chip(label: Text('アーカイブ済み')),
                      ),
                    if (topic.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(topic.description),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TopicDetailScreen(
                            store: widget.store,
                            topicId: topic.id,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('話題ライブラリを開く'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('ステータス', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: RadioGroup<PersonTopicStatus>(
                  groupValue: item.status,
                  onChanged: (value) {
                    if (value != null) {
                      _updateStatus(value);
                    }
                  },
                  child: Column(
                    children: PersonTopicStatus.values
                        .map(
                          (status) => RadioListTile<PersonTopicStatus>(
                            value: status,
                            title: Text(status.label),
                            secondary: Icon(_icon(status)),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('この相手とのメモ', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.note.trim().isEmpty ? 'メモはありません。' : item.note),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _editNote,
                      icon: const Icon(Icons.edit),
                      label: Text(item.note.trim().isEmpty ? 'メモを追加' : 'メモを編集'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _remove,
              icon: const Icon(Icons.remove_circle_outline),
              label: const Text('この話題から外す'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
      );
    },
  );

  IconData _icon(PersonTopicStatus status) => switch (status) {
    PersonTopicStatus.planned => Icons.schedule_outlined,
    PersonTopicStatus.discussed => Icons.check_circle_outline,
    PersonTopicStatus.revisit => Icons.refresh_outlined,
  };
  Future<void> _updateStatus(PersonTopicStatus status) async {
    if (!await widget.store.updatePersonTopicStatus(
          personId: widget.personId,
          topicId: widget.topicId,
          status: status,
        ) &&
        mounted) {
      showStoreError(context, widget.store);
    }
  }

  Future<void> _editNote() async {
    final item = widget.store.personTopic(widget.personId, widget.topicId)!;
    var note = item.note;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('この相手とのメモ'),
        content: TextFormField(
          initialValue: note,
          minLines: 3,
          maxLines: 6,
          onChanged: (value) => note = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved == true &&
        !await widget.store.updatePersonTopicNote(
          personId: widget.personId,
          topicId: widget.topicId,
          note: note,
        ) &&
        mounted) {
      showStoreError(context, widget.store);
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('この話題から外しますか？'),
        content: const Text('この相手とのメモも削除されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('外す'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final removed = await widget.store.removeTopicFromPerson(
      personId: widget.personId,
      topicId: widget.topicId,
    );
    if (!mounted) {
      return;
    }
    if (removed) {
      Navigator.pop(context);
    } else {
      showStoreError(context, widget.store);
    }
  }
}
