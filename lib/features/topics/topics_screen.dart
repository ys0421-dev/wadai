import 'package:flutter/material.dart';

import '../../data/topic_catalog.dart';
import '../../models/topic.dart';
import '../../shared/widgets/empty_state.dart';
import '../../state/wadee_controller.dart';
import 'topic_actions.dart';
import 'category_icon.dart';
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

class _TopicListEntry {
  const _TopicListEntry.header({
    required this.categoryName,
    required this.categoryId,
    required this.count,
  }) : topic = null;

  const _TopicListEntry.topic(this.topic)
    : categoryName = null,
      categoryId = null,
      count = null;

  final Topic? topic;
  final String? categoryName;
  final String? categoryId;
  final int? count;

  bool get isHeader => topic == null;
}

enum _EmptyReason { noTopics, search, category, filter }

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.categoryName,
    required this.categoryId,
    required this.count,
  });
  final String categoryName;
  final String categoryId;
  final int count;
  @override
  Widget build(BuildContext context) => Padding(
    key: Key('topic-category-header-$categoryId'),
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
    child: Row(
      children: [
        Icon(categoryIcon(categoryId), size: 20),
        const SizedBox(width: 8),
        Text(categoryName, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(width: 8),
        Text('$count件'),
      ],
    ),
  );
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
      final base = _baseTopicsFor(_filter);
      final visible = _visibleFor(
        filter: _filter,
        categoryId: _categoryId,
        sort: _sort,
      );
      final hasFilterConditions =
          _filter != TopicFilter.all || _sort != _Sort.standard;
      final hasSearch = _search.text.trim().isNotEmpty;
      final hasCategory = _categoryId != null;
      final emptyReason = _emptyReason(
        base: base,
        hasSearch: hasSearch,
        hasCategory: hasCategory,
        hasDisplayFilter: _filter != TopicFilter.all,
      );
      final listEntries = _listEntries(visible);
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(
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
                  const SizedBox(width: 4),
                  _filterButton(hasFilterConditions),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    ChoiceChip(
                      key: const Key('topic-category-chip-all'),
                      label: const Text('すべて'),
                      selected: _categoryId == null,
                      onSelected: (_) => setState(() => _categoryId = null),
                    ),
                    const SizedBox(width: 8),
                    ...categories.expand(
                      (category) => <Widget>[
                        ChoiceChip(
                          key: Key('topic-category-chip-${category.id}'),
                          avatar: Icon(categoryIcon(category.id), size: 18),
                          label: Text(category.name),
                          selected: _categoryId == category.id,
                          onSelected: (_) =>
                              setState(() => _categoryId = category.id),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (hasFilterConditions)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: _activeConditions(),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${visible.length}件'),
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? EmptyState(
                      icon: Icons.forum_outlined,
                      title: _emptyTitle(emptyReason),
                      message: _emptyMessage(emptyReason),
                      action: _emptyAction(emptyReason),
                    )
                  : ListView.builder(
                      key: ValueKey(
                        'topic-list-${_filter.name}-${_categoryId ?? 'all'}-${_sort.name}-${_search.text}',
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: listEntries.length,
                      itemBuilder: (context, i) {
                        final entry = listEntries[i];
                        if (entry.isHeader) {
                          return _CategoryHeader(
                            categoryName: entry.categoryName!,
                            categoryId: entry.categoryId!,
                            count: entry.count!,
                          );
                        }
                        return _topicTile(entry.topic!);
                      },
                    ),
            ),
          ],
        ),
      );
    },
  );

  Widget _filterButton(bool hasFilterConditions) => Semantics(
    button: true,
    label: hasFilterConditions ? '絞り込みと並び替え、条件あり' : '絞り込みと並び替え',
    child: Tooltip(
      message: '絞り込みと並び替え',
      child: Badge(
        isLabelVisible: hasFilterConditions,
        label: Text(_activeConditionCount.toString()),
        child: IconButton(
          icon: const Icon(Icons.tune),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: _openFilters,
        ),
      ),
    ),
  );

  int get _activeConditionCount =>
      (_filter == TopicFilter.all ? 0 : 1) + (_sort == _Sort.standard ? 0 : 1);

  Widget _activeConditions() => Wrap(
    spacing: 8,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (_filter != TopicFilter.all)
        InputChip(
          label: Text(_filterLabel(_filter)),
          onDeleted: () => setState(() => _filter = TopicFilter.all),
        ),
      if (_sort != _Sort.standard)
        InputChip(
          label: Text(_sortLabel(_sort)),
          onDeleted: () => setState(() => _sort = _Sort.standard),
        ),
      if (_activeConditionCount > 1)
        TextButton(onPressed: _clearFilters, child: const Text('すべて解除')),
    ],
  );

  Future<void> _openFilters() async {
    var draftFilter = _filter;
    var draftSort = _sort;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final count = _visibleFor(
            filter: draftFilter,
            categoryId: _categoryId,
            sort: draftSort,
          ).length;
          return SafeArea(
            child: FractionallySizedBox(
              heightFactor: 0.9,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '絞り込みと並び替え',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: '閉じる',
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      key: const Key('topic-filter-sheet-list'),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        Text(
                          '表示する話題',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        RadioGroup<TopicFilter>(
                          groupValue: draftFilter,
                          onChanged: (value) {
                            if (value != null) {
                              setSheetState(() => draftFilter = value);
                            }
                          },
                          child: Column(
                            children: TopicFilter.values
                                .map(
                                  (value) => RadioListTile<TopicFilter>(
                                    value: value,
                                    title: Text(_filterLabel(value)),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const Divider(),
                        Text(
                          '並び順',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        RadioGroup<_Sort>(
                          groupValue: draftSort,
                          onChanged: (value) {
                            if (value != null) {
                              setSheetState(() => draftSort = value);
                            }
                          },
                          child: Column(
                            children: _Sort.values
                                .map(
                                  (value) => RadioListTile<_Sort>(
                                    value: value,
                                    title: Text(_sortLabel(value)),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final clearButton = TextButton(
                          onPressed: () => setSheetState(() {
                            draftFilter = TopicFilter.all;
                            draftSort = _Sort.standard;
                          }),
                          child: const Text('条件をクリア'),
                        );
                        final applyButton = FilledButton(
                          onPressed: () {
                            setState(() {
                              _filter = draftFilter;
                              _sort = draftSort;
                            });
                            Navigator.pop(sheetContext);
                          },
                          child: Text('$count件を表示'),
                        );
                        if (constraints.maxWidth < 360) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [clearButton, applyButton],
                          );
                        }
                        return Row(
                          children: [clearButton, const Spacer(), applyButton],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Topic> _baseTopicsFor(TopicFilter filter) => switch (filter) {
    TopicFilter.all => widget.store.topics,
    TopicFilter.favorite => widget.store.favoriteTopics,
    TopicFilter.mine => widget.store.customTopics,
    TopicFilter.archived =>
      widget.store.archivedTopicIds
          .map(widget.store.topicByIdIncludingArchived)
          .whereType<Topic>()
          .toList(),
  };

  Widget _topicTile(Topic topic) {
    final archived = widget.store.isArchived(topic.id);
    return TopicTile(
      topic: topic,
      categoryName: widget.store.categoryName(topic.categoryId),
      isFavorite: widget.store.isFavorite(topic.id),
      archived: archived,
      onTap: () => _openDetail(topic.id),
      onToggleFavorite: archived ? null : () => _toggleFavorite(topic.id),
      onEdit: !archived && topic.isCustom
          ? () => _openForm(topic: topic)
          : null,
      onArchive: () => showTopicArchiveDialog(
        context: context,
        store: widget.store,
        topic: topic,
      ),
    );
  }

  List<_TopicListEntry> _listEntries(List<Topic> visible) {
    if (_categoryId != null) {
      return <_TopicListEntry>[
        _TopicListEntry.header(
          categoryName: widget.store.categoryName(_categoryId!),
          categoryId: _categoryId!,
          count: visible.length,
        ),
        ...visible.map(_TopicListEntry.topic),
      ];
    }
    if (_sort == _Sort.name) {
      return visible.map(_TopicListEntry.topic).toList(growable: false);
    }

    final entries = <_TopicListEntry>[];
    for (final category in categories) {
      final topics = visible
          .where((topic) => topic.categoryId == category.id)
          .toList(growable: false);
      if (topics.isEmpty) continue;
      entries.add(
        _TopicListEntry.header(
          categoryName: category.name,
          categoryId: category.id,
          count: topics.length,
        ),
      );
      entries.addAll(topics.map(_TopicListEntry.topic));
    }
    return entries;
  }

  List<Topic> _visibleFor({
    required TopicFilter filter,
    required String? categoryId,
    required _Sort sort,
  }) {
    final query = _search.text.trim().toLowerCase();
    final result = _baseTopicsFor(filter)
        .where(
          (topic) =>
              (categoryId == null || topic.categoryId == categoryId) &&
              (query.isEmpty ||
                  '${topic.title} ${topic.openingQuestion} ${topic.talkingPoints.join(' ')} ${topic.note} ${widget.store.categoryName(topic.categoryId)}'
                      .toLowerCase()
                      .contains(query)),
        )
        .toList();
    if (sort == _Sort.name) {
      result.sort((a, b) => a.title.compareTo(b.title));
    }
    return result;
  }

  String _filterLabel(TopicFilter filter) => switch (filter) {
    TopicFilter.all => 'すべて',
    TopicFilter.favorite => 'お気に入り',
    TopicFilter.mine => '自作',
    TopicFilter.archived => 'アーカイブ',
  };

  String _sortLabel(_Sort sort) => switch (sort) {
    _Sort.standard => '標準',
    _Sort.name => '名前順',
  };

  void _clearSearch() {
    _search.clear();
    setState(() {});
  }

  void _clearFilters() => setState(() {
    _filter = TopicFilter.all;
    _sort = _Sort.standard;
  });

  _EmptyReason _emptyReason({
    required List<Topic> base,
    required bool hasSearch,
    required bool hasCategory,
    required bool hasDisplayFilter,
  }) {
    if (hasSearch) return _EmptyReason.search;
    if (hasCategory && base.isNotEmpty) return _EmptyReason.category;
    if (hasDisplayFilter) return _EmptyReason.filter;
    return _EmptyReason.noTopics;
  }

  String _emptyTitle(_EmptyReason reason) {
    if (reason == _EmptyReason.search) return '条件に一致する話題がありません';
    if (reason == _EmptyReason.category) {
      return '${widget.store.categoryName(_categoryId!)}の話題がありません';
    }
    if (reason == _EmptyReason.filter && _filter == TopicFilter.all) {
      return '条件に一致する話題がありません';
    }
    return _noTopicsTitle();
  }

  String _emptyMessage(_EmptyReason reason) => switch (reason) {
    _EmptyReason.search => '検索語を変えるか、検索をクリアしてください。',
    _EmptyReason.category => '別のカテゴリを選ぶことができます。',
    _EmptyReason.filter => '表示対象や並び順を変更してください。',
    _EmptyReason.noTopics => _legacyEmptyMessage(),
  };

  Widget? _emptyAction(_EmptyReason reason) {
    switch (reason) {
      case _EmptyReason.search:
        return TextButton(onPressed: _clearSearch, child: const Text('検索をクリア'));
      case _EmptyReason.category:
        return TextButton(
          onPressed: () => setState(() => _categoryId = null),
          child: const Text('すべて'),
        );
      case _EmptyReason.filter:
        return TextButton(
          onPressed: _clearFilters,
          child: const Text('フィルターをクリア'),
        );
      case _EmptyReason.noTopics:
        return null;
    }
  }

  String _noTopicsTitle() => _legacyEmptyTitle(const <Topic>[]);

  String _legacyEmptyTitle(List<Topic> base) {
    if (_categoryId != null && base.isNotEmpty) {
      return '${widget.store.categoryName(_categoryId!)}の話題がありません';
    }
    if (base.isNotEmpty) return '条件に一致する話題がありません';
    return switch (_filter) {
      TopicFilter.all => '話題がありません',
      TopicFilter.favorite => 'お気に入りの話題がありません',
      TopicFilter.mine => '自作の話題がありません',
      TopicFilter.archived => 'アーカイブした話題がありません',
    };
  }

  String _legacyEmptyMessage() => switch (_filter) {
    TopicFilter.all => '右下のボタンから話題を追加できます。',
    TopicFilter.favorite => '話題一覧からお気に入りを追加できます。',
    TopicFilter.mine => '右下のボタンから自分用の話題を追加できます。',
    TopicFilter.archived => 'アーカイブした話題はここに表示されます。',
  };

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
