import 'package:flutter/material.dart';

import '../../models/topic.dart';
import '../../state/wadee_controller.dart';

Future<void> showTopicArchiveDialog({
  required BuildContext context,
  required WadeeController store,
  required Topic topic,
  bool popOnSuccess = false,
}) async {
  final archived = store.isArchived(topic.id);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(archived ? '話題を復元しますか？' : '話題をアーカイブしますか？'),
      content: Text(
        archived ? '通常の話題一覧に戻します。' : '通常の一覧から非表示になります。既存の相手ごとの割り当てとメモは保持されます。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(archived ? '復元する' : 'アーカイブする'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final saved = archived
      ? await store.restoreTopic(topic.id)
      : await store.archiveTopic(topic.id);
  if (!context.mounted) return;
  if (saved) {
    if (popOnSuccess) Navigator.of(context).pop();
  } else {
    showStoreError(context, store);
  }
}

void showStoreError(BuildContext context, WadeeController store) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Semantics(
        liveRegion: true,
        container: true,
        label: store.lastError ?? '保存に失敗しました。',
        child: Text(store.lastError ?? '保存に失敗しました。'),
      ),
    ),
  );
  store.clearError();
}
