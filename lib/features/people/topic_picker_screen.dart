import 'package:flutter/material.dart';

import '../../data/topic_catalog.dart';
import '../../models/topic.dart';
import '../../shared/widgets/empty_state.dart';
import '../../state/wadee_controller.dart';
import '../topics/topic_actions.dart';

enum _PickerSort { standard, name }

class TopicPickerScreen extends StatefulWidget {
  const TopicPickerScreen({
    required this.store,
    required this.personId,
    super.key,
  });

  final WadeeController store;
  final String personId;

  @override
  State<TopicPickerScreen> createState() => _TopicPickerScreenState();
}

class _TopicPickerScreenState extends State<TopicPickerScreen> {
  final _search = TextEditingController();
  String? _categoryId;
  _PickerSort _sort = _PickerSort.standard;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final assigned = widget.store
          .personTopicsFor(widget.personId)
          .map((item) => item.topicId)
          .toSet();
      final candidates = widget.store.topics
          .where((topic) => !assigned.contains(topic.id))
          .toList();
      final visible = _filter(candidates);
      final hasConditions =
          _search.text.trim().isNotEmpty ||
          _categoryId != null ||
          _sort != _PickerSort.standard;
      return Scaffold(
        appBar: AppBar(title: const Text('話題を追加')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Semantics(
                textField: true,
                label: '追加する話題を検索。タイトル、説明、カテゴリーを対象にします',
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: '話題を検索',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: '検索をクリア',
                            onPressed: _clear,
                          ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final category = _categoryControl();
                  final sort = _sortControl();
                  if (constraints.maxWidth < 420) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        category,
                        const SizedBox(height: 8),
                        Align(alignment: Alignment.centerRight, child: sort),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: category),
                      const SizedBox(width: 8),
                      sort,
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: widget.store.topics.isEmpty
                  ? const EmptyState(
                      icon: Icons.forum_outlined,
                      title: '利用できる話題がありません',
                      message: '話題画面で話題を作成すると、ここから割り当てられます。',
                    )
                  : candidates.isEmpty
                  ? const EmptyState(
                      icon: Icons.check_circle_outline,
                      title: '追加できる話題はありません',
                      message: '利用中の話題はすべて割り当て済みです。話題画面で新しい話題を作成できます。',
                    )
                  : visible.isEmpty
                  ? EmptyState(
                      icon: Icons.search_off,
                      title: '条件に一致する話題がありません',
                      message: '検索やカテゴリー条件を変更してください。',
                      action: hasConditions
                          ? TextButton(
                              onPressed: _clear,
                              child: const Text('条件をクリア'),
                            )
                          : null,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final topic = visible[index];
                        return Card(
                          child: ListTile(
                            title: Text(topic.title),
                            subtitle: Text(
                              widget.store.categoryName(topic.categoryId),
                            ),
                            onTap: () => _assign(topic),
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

  Widget _categoryControl() => Semantics(
    label: 'カテゴリーで絞り込む',
    child: DropdownButtonFormField<String?>(
      initialValue: _categoryId,
      decoration: const InputDecoration(labelText: 'カテゴリー'),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('すべて')),
        ...categories.map(
          (category) => DropdownMenuItem<String?>(
            value: category.id,
            child: Text(category.name),
          ),
        ),
      ],
      onChanged: (value) => setState(() => _categoryId = value),
    ),
  );

  Widget _sortControl() => Semantics(
    label: '話題の並び順',
    child: Tooltip(
      message: '話題の並び順',
      child: DropdownButton<_PickerSort>(
        value: _sort,
        items: const [
          DropdownMenuItem(value: _PickerSort.standard, child: Text('標準順')),
          DropdownMenuItem(value: _PickerSort.name, child: Text('名前順')),
        ],
        onChanged: (value) => setState(() => _sort = value!),
      ),
    ),
  );

  List<Topic> _filter(List<Topic> source) {
    final query = _search.text.trim().toLowerCase();
    final topics = source.where((topic) {
      final haystack =
          '${topic.title} ${topic.description} ${widget.store.categoryName(topic.categoryId)}'
              .toLowerCase();
      return (_categoryId == null || topic.categoryId == _categoryId) &&
          (query.isEmpty || haystack.contains(query));
    }).toList();
    if (_sort == _PickerSort.name) {
      topics.sort((a, b) => a.title.compareTo(b.title));
    }
    return topics;
  }

  void _clear() {
    _search.clear();
    setState(() {
      _categoryId = null;
      _sort = _PickerSort.standard;
    });
  }

  Future<void> _assign(Topic topic) async {
    if (await widget.store.assignTopicToPerson(
      personId: widget.personId,
      topicId: topic.id,
    )) {
      if (mounted) Navigator.of(context).pop();
    } else if (mounted) {
      showStoreError(context, widget.store);
    }
  }
}
