import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../shared/widgets/empty_state.dart';
import '../../state/wadee_controller.dart';
import 'category_icon.dart';
import 'topic_actions.dart';
import 'topic_form_screen.dart';

class TopicDetailScreen extends StatelessWidget {
  const TopicDetailScreen({
    required this.store,
    required this.topicId,
    super.key,
  });

  final WadeeController store;
  final String topicId;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final topic = store.topicByIdIncludingArchived(topicId);
      if (topic == null) {
        return Scaffold(
          appBar: AppBar(),
          body: const EmptyState(
            icon: Icons.error_outline,
            title: '話題が見つかりません',
            message: 'この話題はアーカイブされたか、利用できなくなりました。',
          ),
        );
      }
      final favorite = store.isFavorite(topic.id);
      final archived = store.isArchived(topic.id);
      return Scaffold(
        appBar: AppBar(
          title: const Text('話題の詳細'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) =>
                          TopicFormScreen(store: store, topic: topic),
                    ),
                  );
                } else if (value == 'archive') {
                  await showTopicArchiveDialog(
                    context: context,
                    store: store,
                    topic: topic,
                    popOnSuccess: true,
                  );
                }
              },
              itemBuilder: (_) => [
                if (topic.isCustom && !archived)
                  const PopupMenuItem(value: 'edit', child: Text('編集')),
                PopupMenuItem(
                  value: 'archive',
                  child: Text(archived ? '復元' : 'アーカイブ'),
                ),
              ],
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                topic.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: appTextColor,
                ),
              ),
              if (archived) ...[
                const SizedBox(height: 10),
                const Chip(label: Text('アーカイブ済み')),
                const SizedBox(height: 6),
                const Text('この話題は通常の一覧から非表示です。お気に入りの変更はできません。'),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => showTopicArchiveDialog(
                    context: context,
                    store: store,
                    topic: topic,
                  ),
                  icon: const Icon(Icons.unarchive_outlined),
                  label: const Text('復元する'),
                ),
              ],
              const SizedBox(height: 18),
              const Text(
                'カテゴリー',
                style: TextStyle(
                  color: appSecondaryTextColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Chip(
                avatar: Icon(categoryIcon(topic.categoryId), size: 17),
                label: Text(store.categoryName(topic.categoryId)),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: appSubtleColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 19),
                        SizedBox(width: 8),
                        Text(
                          '最初のひとこと',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      topic.openingQuestion.trim().isEmpty
                          ? '最初のひとことは未設定です。'
                          : topic.openingQuestion,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.55,
                        color: appTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (topic.talkingPoints.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  '話を広げるヒント',
                  style: TextStyle(
                    color: appSecondaryTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ...topic.talkingPoints.map(
                  (point) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '・$point',
                      style: const TextStyle(height: 1.65, fontSize: 16),
                    ),
                  ),
                ),
              ],
              if (topic.note.trim().isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'メモ',
                  style: TextStyle(
                    color: appSecondaryTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  topic.note,
                  style: const TextStyle(height: 1.65, fontSize: 16),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: archived ? null : () => _toggle(context, topic.id),
                  icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
                  label: Text(favorite ? 'お気に入りから解除' : 'お気に入りに追加'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Future<void> _toggle(BuildContext context, String id) async {
    final saved = await store.toggleFavorite(id);
    if (!saved && context.mounted) showStoreError(context, store);
  }
}
