import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../models/topic.dart';
import 'category_icon.dart';

class TopicTile extends StatelessWidget {
  const TopicTile({
    required this.topic,
    required this.categoryName,
    required this.isFavorite,
    required this.onTap,
    this.onToggleFavorite,
    this.onEdit,
    this.onArchive,
    this.archived = false,
    super.key,
  });

  final Topic topic;
  final String categoryName;
  final bool isFavorite;
  final bool archived;
  final VoidCallback onTap;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${topic.title}、$categoryName、${isFavorite ? 'お気に入り' : 'お気に入りではありません'}${archived ? '、アーカイブ済み' : ''}',
    child: Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                topic.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Row(
                children: [
                  const Spacer(),
                  if (onToggleFavorite != null)
                    IconButton(
                      onPressed: onToggleFavorite,
                      tooltip: isFavorite ? 'お気に入りを解除' : 'お気に入りに追加',
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? brandColor : appSecondaryTextColor,
                      ),
                    ),
                  if (onEdit != null || onArchive != null)
                    PopupMenuButton<String>(
                      tooltip: '話題の操作',
                      onSelected: (value) {
                        if (value == 'edit') onEdit?.call();
                        if (value == 'archive') onArchive?.call();
                      },
                      itemBuilder: (_) => [
                        if (onEdit != null)
                          const PopupMenuItem(value: 'edit', child: Text('編集')),
                        if (onArchive != null)
                          PopupMenuItem(
                            value: 'archive',
                            child: Text(archived ? '復元' : 'アーカイブ'),
                          ),
                      ],
                    ),
                  const Icon(Icons.chevron_right, color: appSecondaryTextColor),
                ],
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(
                    categoryIcon(topic.categoryId),
                    size: 15,
                    color: brandColor,
                  ),
                  Text(
                    categoryName,
                    style: const TextStyle(
                      color: appSecondaryTextColor,
                      fontSize: 13,
                    ),
                  ),
                  if (topic.source == TopicSource.userCreated)
                    const _SmallLabel(text: '自作'),
                  if (topic.source == TopicSource.aiGenerated)
                    const _SmallLabel(text: 'AI提案'),
                  if (archived) const _SmallLabel(text: 'アーカイブ済み'),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                '最初のひとこと',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                topic.openingQuestion.trim().isEmpty
                    ? '最初のひとことは未設定です。'
                    : topic.openingQuestion,
              ),
              if (topic.talkingPoints.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...topic.talkingPoints
                    .take(2)
                    .map(
                      (point) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text('・$point'),
                      ),
                    ),
                if (topic.talkingPoints.length > 2)
                  Text(
                    'ほか ${topic.talkingPoints.length - 2}件',
                    style: const TextStyle(color: appSecondaryTextColor),
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _SmallLabel extends StatelessWidget {
  const _SmallLabel({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: appSubtleColor,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: appSecondaryTextColor,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
