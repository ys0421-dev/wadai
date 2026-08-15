import 'package:flutter/material.dart';

import '../../models/person.dart';
import '../../state/wadee_controller.dart';
import '../topics/topic_actions.dart';

class PersonFormScreen extends StatefulWidget {
  const PersonFormScreen({
    required this.store,
    this.person,
    this.initiallyExpandProfile = false,
    super.key,
  });

  final WadeeController store;
  final Person? person;
  final bool initiallyExpandProfile;

  @override
  State<PersonFormScreen> createState() => _PersonFormScreenState();
}

class _PersonFormScreenState extends State<PersonFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.person?.displayName ?? '',
  );
  late final _note = TextEditingController(text: widget.person?.note ?? '');
  late final _interests = TextEditingController(
    text: widget.person?.profile.interests ?? '',
  );
  late final _workOrSchool = TextEditingController(
    text: widget.person?.profile.workOrSchool ?? '',
  );
  late final _recentEvents = TextEditingController(
    text: widget.person?.profile.recentEvents ?? '',
  );
  late final _likelyInterests = TextEditingController(
    text: widget.person?.profile.likelyInterests ?? '',
  );
  late final _commonTopics = TextEditingController(
    text: widget.person?.profile.commonTopics ?? '',
  );
  late final _topicsToAvoid = TextEditingController(
    text: widget.person?.profile.topicsToAvoid ?? '',
  );
  late final _nextQuestions = TextEditingController(
    text: widget.person?.profile.nextQuestions ?? '',
  );
  late PersonRelationship? _relationship = widget.person?.profile.relationship;
  late PersonCloseness? _closeness = widget.person?.profile.closeness;
  late PersonAgeGroup? _ageGroup = widget.person?.profile.ageGroup;
  late bool _profileExpanded =
      widget.initiallyExpandProfile || widget.person?.profile.isEmpty == false;
  bool _saving = false;

  bool get _editing => widget.person != null;

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _name,
      _note,
      _interests,
      _workOrSchool,
      _recentEvents,
      _likelyInterests,
      _commonTopics,
      _topicsToAvoid,
      _nextQuestions,
    ]) {
      controller.dispose();
    }
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
          const Text(
            '名前だけで登録できます。プロフィールを追加すると、AIの提案がより相手に合いやすくなります。',
            style: TextStyle(height: 1.5),
          ),
          const SizedBox(height: 20),
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
            minLines: 3,
            maxLines: 8,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(labelText: '全般メモ（任意）'),
          ),
          const SizedBox(height: 12),
          _ProfileExpansion(
            expanded: _profileExpanded,
            onExpansionChanged: (expanded) =>
                setState(() => _profileExpanded = expanded),
            children: _profileFields(context),
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

  List<Widget> _profileFields(BuildContext context) => [
    Text('基本', style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 12),
    _ProfileDropdown<PersonRelationship>(
      label: '関係性',
      value: _relationship,
      values: PersonRelationship.values,
      labelOf: (value) => value.label,
      onChanged: (value) => setState(() => _relationship = value),
    ),
    const SizedBox(height: 12),
    _ProfileDropdown<PersonCloseness>(
      label: '親密度',
      value: _closeness,
      values: PersonCloseness.values,
      labelOf: (value) => value.label,
      onChanged: (value) => setState(() => _closeness = value),
    ),
    const SizedBox(height: 12),
    _ProfileDropdown<PersonAgeGroup>(
      label: '年代',
      value: _ageGroup,
      values: PersonAgeGroup.values,
      labelOf: (value) => value.label,
      onChanged: (value) => setState(() => _ageGroup = value),
    ),
    const SizedBox(height: 24),
    Text('相手について', style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 12),
    _profileTextField(_interests, '趣味・好きなもの'),
    const SizedBox(height: 12),
    _profileTextField(_workOrSchool, '仕事・学校'),
    const SizedBox(height: 12),
    _profileTextField(_recentEvents, '最近の出来事'),
    const SizedBox(height: 12),
    _profileTextField(_likelyInterests, '興味がありそうなこと'),
    const SizedBox(height: 24),
    Text('会話のヒント', style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 12),
    _profileTextField(_commonTopics, 'よく話すこと'),
    const SizedBox(height: 12),
    _profileTextField(_nextQuestions, '次に聞きたいこと'),
    const SizedBox(height: 12),
    _profileTextField(_topicsToAvoid, '避けたい話題'),
  ];

  Widget _profileTextField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        minLines: 2,
        maxLines: 6,
        textInputAction: TextInputAction.newline,
        decoration: InputDecoration(labelText: label),
      );

  PersonProfile _profile() => PersonProfile(
    relationship: _relationship,
    closeness: _closeness,
    ageGroup: _ageGroup,
    interests: _interests.text,
    workOrSchool: _workOrSchool.text,
    recentEvents: _recentEvents.text,
    likelyInterests: _likelyInterests.text,
    commonTopics: _commonTopics.text,
    topicsToAvoid: _topicsToAvoid.text,
    nextQuestions: _nextQuestions.text,
  ).normalized();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final success = _editing
        ? await widget.store.updatePerson(
            id: widget.person!.id,
            displayName: _name.text,
            note: _note.text,
            profile: _profile(),
          )
        : (await widget.store.addPerson(
                displayName: _name.text,
                note: _note.text,
                profile: _profile(),
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

class _ProfileExpansion extends StatelessWidget {
  const _ProfileExpansion({
    required this.expanded,
    required this.onExpansionChanged,
    required this.children,
  });

  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      key: const Key('person-profile-expansion'),
      initiallyExpanded: expanded,
      onExpansionChanged: onExpansionChanged,
      title: const Text('プロフィールを追加（任意）'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: children,
    ),
  );
}

class _ProfileDropdown<T> extends StatelessWidget {
  const _ProfileDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<T> values;
  final String Function(T value) labelOf;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      DropdownMenuItem<T>(value: null, child: const Text('選択しない')),
      ...values.map(
        (item) => DropdownMenuItem<T>(value: item, child: Text(labelOf(item))),
      ),
    ],
    onChanged: onChanged,
  );
}
