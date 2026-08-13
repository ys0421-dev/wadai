import 'package:flutter/material.dart';

import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/initial_avatar.dart';
import '../../state/wadee_controller.dart';
import 'person_detail_screen.dart';
import 'person_form_screen.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({required this.store, super.key});

  final WadeeController store;

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final _search = TextEditingController();
  bool _nameSort = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final query = _search.text.trim().toLowerCase();
      final people = widget.store.persons.where((person) {
        return query.isEmpty ||
            '${person.displayName} ${person.note}'.toLowerCase().contains(
              query,
            );
      }).toList();
      if (_nameSort) {
        people.sort((a, b) => a.displayName.compareTo(b.displayName));
      }
      final hasPeople = widget.store.persons.isNotEmpty;
      return Scaffold(
        appBar: AppBar(title: const Text('相手')),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'people-add',
          onPressed: _openForm,
          icon: const Icon(Icons.add),
          label: const Text('相手を追加'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Semantics(
                textField: true,
                label: '相手を検索。名前とメモを対象にします',
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: '相手を検索',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: '検索をクリア',
                            onPressed: _clearSearch,
                          ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: Semantics(
                  label: '相手の並び順',
                  child: DropdownButton<bool>(
                    value: _nameSort,
                    items: const [
                      DropdownMenuItem(value: false, child: Text('作成順')),
                      DropdownMenuItem(value: true, child: Text('名前順')),
                    ],
                    onChanged: (value) => setState(() => _nameSort = value!),
                  ),
                ),
              ),
            ),
            Expanded(
              child: people.isEmpty
                  ? EmptyState(
                      icon: Icons.people_outline,
                      title: hasPeople ? '条件に一致する相手がいません' : '相手がいません',
                      message: hasPeople
                          ? '検索条件を変更してください。'
                          : '＋ボタンから相手を追加できます。',
                      action: hasPeople
                          ? TextButton(
                              onPressed: _clearSearch,
                              child: const Text('検索をクリア'),
                            )
                          : null,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: people.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final person = people[index];
                        final count = widget.store
                            .personTopicsFor(person.id)
                            .length;
                        final note = person.note.trim().split('\n').first;
                        return Semantics(
                          button: true,
                          label: '${person.displayName}、話題$count件',
                          child: Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              leading: InitialAvatar(
                                displayName: person.displayName,
                              ),
                              title: Text(person.displayName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (note.isNotEmpty)
                                    Text(
                                      note,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  if (note.isNotEmpty)
                                    const SizedBox(height: 2),
                                  Text('話題$count件'),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) => PersonDetailScreen(
                                    store: widget.store,
                                    personId: person.id,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );

  void _clearSearch() {
    _search.clear();
    setState(() {});
  }

  Future<void> _openForm() => Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => PersonFormScreen(store: widget.store)),
  );
}
