import 'package:flutter/material.dart';

import '../../data/topic_catalog.dart';
import '../../models/topic.dart';
import '../../shared/widgets/empty_state.dart';
import '../../state/wadee_controller.dart';
import 'topic_actions.dart';
import 'topic_detail_screen.dart';
import 'topic_form_screen.dart';
import 'topic_tile.dart';

enum TopicFilter { all, favorite, mine, archived }

enum _Sort { standard, name }

class TopicsScreen extends StatefulWidget {
  const TopicsScreen({required this.store, super.key});
  final WadeeController store;
  @override
  State<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends State<TopicsScreen> {
  final _search = TextEditingController();
  TopicFilter _filter = TopicFilter.all;
  String? _categoryId;
  _Sort _sort = _Sort.standard;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final base = _baseTopics();
      final visible = _visible(base);
      final hasConditions =
          _search.text.trim().isNotEmpty ||
          _filter != TopicFilter.all ||
          _categoryId != null ||
          _sort != _Sort.standard;
      return Scaffold(
        appBar: AppBar(title: const Text('話題')),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'topics-add',
          onPressed: _openForm,
          icon: const Icon(Icons.add),
          label: const Text('話題を作成'),
        ),
        body: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SegmentedButton<TopicFilter>(
                segments: const [
                  ButtonSegment(value: TopicFilter.all, label: Text('すべて')),
                  ButtonSegment(
                    value: TopicFilter.favorite,
                    label: Text('お気に入り'),
                  ),
                  ButtonSegment(value: TopicFilter.mine, label: Text('自作')),
                  ButtonSegment(
                    value: TopicFilter.archived,
                    label: Text('アーカイブ'),
                  ),
                ],
                selected: {_filter},
                onSelectionChanged: (value) =>
                    setState(() => _filter = value.single),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Semantics(
                textField: true,
                label: '話題を検索。タイトル、説明、カテゴリーを対象にします',
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
                            onPressed: _clearSearch,
                          ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${visible.length}件'),
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? EmptyState(
                      icon: Icons.forum_outlined,
                      title: _emptyTitle(base),
                      message: base.isEmpty
                          ? _emptyMessage()
                          : '検索やフィルター条件を変更してください。',
                      action: hasConditions
                          ? TextButton(
                              onPressed: _clearConditions,
                              child: const Text('条件をクリア'),
                            )
                          : null,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: visible.length,
                      itemBuilder: (context, i) {
                        final topic = visible[i];
                        final archived = widget.store.isArchived(topic.id);
                        return TopicTile(
                          topic: topic,
                          categoryName: widget.store.categoryName(
                            topic.categoryId,
                          ),
                          isFavorite: widget.store.isFavorite(topic.id),
                          archived: archived,
                          onTap: () => _openDetail(topic.id),
                          onToggleFavorite: archived
                              ? null
                              : () => _toggleFavorite(topic.id),
                          onEdit: !archived && topic.isCustom
                              ? () => _openForm(topic: topic)
                              : null,
                          onArchive: () => showTopicArchiveDialog(
                            context: context,
                            store: widget.store,
                            topic: topic,
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
  List<Topic> _baseTopics() => switch (_filter) {
    TopicFilter.all => widget.store.topics,
    TopicFilter.favorite => widget.store.favoriteTopics,
    TopicFilter.mine => widget.store.customTopics,
    TopicFilter.archived =>
      widget.store.archivedTopicIds
          .map(widget.store.topicByIdIncludingArchived)
          .whereType<Topic>()
          .toList(),
  };
  List<Topic> _visible(List<Topic> base) {
    final query = _search.text.trim().toLowerCase();
    final result = base
        .where(
          (topic) =>
              (_categoryId == null || topic.categoryId == _categoryId) &&
              (query.isEmpty ||
                  '${topic.title} ${topic.description} ${widget.store.categoryName(topic.categoryId)}'
                      .toLowerCase()
                      .contains(query)),
        )
        .toList();
    if (_sort == _Sort.name) result.sort((a, b) => a.title.compareTo(b.title));
    return result;
  }

  void _clearSearch() {
    _search.clear();
    setState(() {});
  }

  void _clearConditions() {
    _search.clear();
    setState(() {
      _filter = TopicFilter.all;
      _categoryId = null;
      _sort = _Sort.standard;
    });
  }

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

  String _emptyTitle(List<Topic> base) {
    if (base.isNotEmpty) return '条件に一致する話題がありません';
    return switch (_filter) {
      TopicFilter.all => '話題がありません',
      TopicFilter.favorite => 'お気に入りの話題はありません',
      TopicFilter.mine => '自作の話題はありません',
      TopicFilter.archived => 'アーカイブした話題はありません',
    };
  }

  String _emptyMessage() => switch (_filter) {
    TopicFilter.all => '＋ボタンから話題を作成できます。',
    TopicFilter.favorite => '話題一覧からお気に入りを追加できます。',
    TopicFilter.mine => '＋ボタンから自分の話題を作成できます。',
    TopicFilter.archived => 'アーカイブした話題はここに表示されます。',
  };

  Widget _sortControl() => Semantics(
    label: '話題の並び順',
    child: Tooltip(
      message: '話題の並び順',
      child: DropdownButton<_Sort>(
        value: _sort,
        items: const [
          DropdownMenuItem(value: _Sort.standard, child: Text('標準順')),
          DropdownMenuItem(value: _Sort.name, child: Text('名前順')),
        ],
        onChanged: (value) => setState(() => _sort = value!),
      ),
    ),
  );

  Future<void> _toggleFavorite(String id) async {
    if (!await widget.store.toggleFavorite(id) && mounted) {
      showStoreError(context, widget.store);
    }
  }

  Future<void> _openForm({Topic? topic}) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => TopicFormScreen(store: widget.store, topic: topic),
    ),
  );
  Future<void> _openDetail(String id) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => TopicDetailScreen(store: widget.store, topicId: id),
    ),
  );
}
