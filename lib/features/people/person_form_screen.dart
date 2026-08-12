import 'package:flutter/material.dart';

import '../../models/person.dart';
import '../../state/wadee_controller.dart';
import '../topics/topic_actions.dart';

class PersonFormScreen extends StatefulWidget {
  const PersonFormScreen({required this.store, this.person, super.key});

  final WadeeController store;
  final Person? person;

  @override
  State<PersonFormScreen> createState() => _PersonFormScreenState();
}

class _PersonFormScreenState extends State<PersonFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.person?.displayName ?? '',
  );
  late final _note = TextEditingController(text: widget.person?.note ?? '');
  bool _saving = false;

  bool get _editing => widget.person != null;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_editing ? '相手を編集' : '相手を追加')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            controller: _name,
            autofocus: true,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
            decoration: const InputDecoration(labelText: '表示名'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? '表示名を入力してください。' : null,
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _note,
            minLines: 4,
            maxLines: 8,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(labelText: '全般メモ'),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_editing ? '変更を保存' : '相手を追加'),
          ),
        ],
      ),
    ),
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final success = _editing
        ? await widget.store.updatePerson(
            id: widget.person!.id,
            displayName: _name.text,
            note: _note.text,
          )
        : (await widget.store.addPerson(
                displayName: _name.text,
                note: _note.text,
              )) !=
              null;
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) {
      Navigator.of(context).pop();
    } else {
      showStoreError(context, widget.store);
    }
  }
}
