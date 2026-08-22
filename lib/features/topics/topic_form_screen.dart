import 'package:flutter/material.dart';

import '../../data/topic_catalog.dart';
import '../../models/topic.dart';
import '../../state/wadee_controller.dart';
import 'topic_actions.dart';

class TopicFormScreen extends StatefulWidget {
  const TopicFormScreen({required this.store, this.topic, super.key});

  final WadeeController store;
  final Topic? topic;

  @override
  State<TopicFormScreen> createState() => _TopicFormScreenState();
}

class _TopicFormScreenState extends State<TopicFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(
    text: widget.topic?.title ?? '',
  );
  late final _openingQuestionController = TextEditingController(
    text: widget.topic == null
        ? ''
        : (widget.topic!.openingQuestion.trim().isEmpty
              ? Topic.fallbackOpeningQuestion(widget.topic!.title)
              : widget.topic!.openingQuestion),
  );
  late final _noteController = TextEditingController(
    text: widget.topic?.note ?? '',
  );
  late final List<TextEditingController> _talkingPointControllers =
      (widget.topic?.talkingPoints ?? const <String>[])
          .map((value) => TextEditingController(text: value))
          .toList(growable: true);
  String? _categoryId;
  bool _saving = false;

  bool get _isEditing => widget.topic != null;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.topic?.categoryId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _openingQuestionController.dispose();
    _noteController.dispose();
    for (final controller in _talkingPointControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_isEditing ? '話題を編集' : '話題を追加'),
      actions: [
        TextButton(onPressed: _saving ? null : _save, child: const Text('保存')),
      ],
    ),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          key: const Key('topic-form-list'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Text(
              _isEditing ? '会話のきっかけを整える' : '自分だけの話題を登録',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text('最初のひとこととヒントを残すと、会話を始めやすくなります。'),
            const SizedBox(height: 28),
            TextFormField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'タイトル（必須）',
                hintText: '例：北海道旅行',
              ),
              validator: _required('タイトルを入力してください'),
            ),
            const SizedBox(height: 22),
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'カテゴリ（必須）',
                hintText: 'カテゴリを選択',
              ),
              items: categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _categoryId = value),
              validator: (value) =>
                  value == null || value.isEmpty ? 'カテゴリを選択してください' : null,
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _openingQuestionController,
              minLines: 2,
              maxLines: 5,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '最初のひとこと（必須）',
                hintText: '例：北海道旅行で印象に残ったことはありますか？',
              ),
              validator: _required('最初のひとことを入力してください'),
            ),
            const SizedBox(height: 22),
            Text(
              '話を広げるヒント（任意）',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._talkingPointControllers.indexed.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: entry.$2,
                        minLines: 2,
                        maxLines: 4,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'ヒント ${entry.$1 + 1}',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _removeTalkingPoint(entry.$1),
                      tooltip: 'ヒントを削除',
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ],
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _addTalkingPoint,
              icon: const Icon(Icons.add),
              label: const Text('ヒントを追加'),
            ),
            const SizedBox(height: 22),
            const _FieldLabel(text: 'メモ'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteController,
              minLines: 3,
              maxLines: 8,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: '会話を思い出すためのメモ',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 30),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? '変更を保存する' : '話題を保存する'),
            ),
          ],
        ),
      ),
    ),
  );

  String? Function(String?) _required(String message) =>
      (value) => value == null || value.trim().isEmpty ? message : null;

  void _addTalkingPoint() =>
      setState(() => _talkingPointControllers.add(TextEditingController()));

  void _removeTalkingPoint(int index) {
    final controller = _talkingPointControllers.removeAt(index);
    controller.dispose();
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final values = _talkingPointControllers.map(
      (controller) => controller.text,
    );
    final saved = _isEditing
        ? await widget.store.updateTopic(
            id: widget.topic!.id,
            title: _titleController.text,
            categoryId: _categoryId!,
            openingQuestion: _openingQuestionController.text,
            talkingPoints: values,
            note: _noteController.text,
          )
        : await widget.store.addTopic(
            title: _titleController.text,
            categoryId: _categoryId!,
            openingQuestion: _openingQuestionController.text,
            talkingPoints: values,
            note: _noteController.text,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      Navigator.of(context).pop();
    } else {
      showStoreError(context, widget.store);
    }
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [Text(text, style: const TextStyle(fontWeight: FontWeight.w800))],
  );
}
