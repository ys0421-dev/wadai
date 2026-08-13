import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
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
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  String? _categoryId;
  bool _saving = false;
  bool get _isEditing => widget.topic != null;
  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.topic?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.topic?.description ?? '',
    );
    _categoryId = widget.topic?.categoryId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            _isEditing ? '話題を整える' : '自分だけの話題を登録',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'あとで会話に使いやすいように、思い出せるメモも残しておきましょう。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: appSecondaryTextColor,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          const _FieldLabel(text: 'タイトル', required: true),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleController,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
            decoration: const InputDecoration(
              hintText: '例：北海道旅行',
              prefixIcon: Icon(Icons.title),
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'タイトルを入力してください' : null,
          ),
          const SizedBox(height: 22),
          const _FieldLabel(text: 'カテゴリ', required: true),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            decoration: const InputDecoration(
              hintText: 'カテゴリを選択',
              prefixIcon: Icon(Icons.category_outlined),
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
          const _FieldLabel(text: 'メモ'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            minLines: 5,
            maxLines: 8,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText: '例：去年北海道に行った。小樽が特に良かった。',
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 76),
                child: Icon(Icons.notes_outlined),
              ),
            ),
          ),
          const SizedBox(height: 30),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
              ),
            ),
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
  );
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final saved = _isEditing
        ? await widget.store.updateTopic(
            id: widget.topic!.id,
            title: _titleController.text.trim(),
            categoryId: _categoryId!,
            description: _descriptionController.text.trim(),
          )
        : await widget.store.addTopic(
            title: _titleController.text.trim(),
            categoryId: _categoryId!,
            description: _descriptionController.text.trim(),
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
  const _FieldLabel({required this.text, this.required = false});
  final String text;
  final bool required;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
      if (required)
        const Text('  *', style: TextStyle(color: Colors.redAccent)),
    ],
  );
}
