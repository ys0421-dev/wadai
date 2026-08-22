import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../data/topic_catalog.dart';
import '../../models/topic.dart';
import '../../shared/widgets/empty_state.dart';
import '../../state/wadee_controller.dart';
import '../topics/topic_actions.dart';

enum _PickerFilter { all, favorite, mine }

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
  final Set<String> _selectedIds = <String>{};
  String? _categoryId;
  _PickerFilter _filter = _PickerFilter.all;
  _PickerSort _sort = _PickerSort.standard;
  bool _saving = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final person = widget.store.personById(widget.personId);
      if (person == null) {
        return const Scaffold(
          body: EmptyState(
            icon: Icons.person_off_outlined,
            title: '相手が見つかりません',
            message: '相手が削除された可能性があります。',
          ),
        );
      }
      final assignedIds = widget.store
          .personTopicsFor(widget.personId)
          .map((item) => item.topicId)
          .toSet();
      final allTopics = widget.store.allTopicsIncludingArchived;
      final visible = _filterTopics(allTopics);
      final hasConditions =
          _search.text.trim().isNotEmpty ||
          _filter != _PickerFilter.all ||
          _categoryId != null ||
          _sort != _PickerSort.standard;
      return Scaffold(
        appBar: AppBar(title: const Text('話題を追加')),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: appNavigationColor,
              border: Border(top: BorderSide(color: appOutlineColor)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Semantics(
              button: true,
              enabled: _selectedIds.isNotEmpty && !_saving,
              label: '${person.displayName}に${_selectedIds.length}件の話題を追加',
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selectedIds.isEmpty || _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('${_selectedIds.length}件を追加'),
                ),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('相手: ${person.displayName}'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                            onPressed: _clearConditions,
                          ),
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SegmentedButton<_PickerFilter>(
                segments: const [
                  ButtonSegment(value: _PickerFilter.all, label: Text('すべて')),
                  ButtonSegment(
                    value: _PickerFilter.favorite,
                    label: Text('お気に入り'),
                  ),
                  ButtonSegment(value: _PickerFilter.mine, label: Text('自作')),
                ],
                selected: {_filter},
                onSelectionChanged: (value) =>
                    setState(() => _filter = value.single),
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
                        const SizedBox(height: 4),
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
              child: allTopics.isEmpty
                  ? const EmptyState(
                      icon: Icons.forum_outlined,
                      title: '利用できる話題がありません',
                      message: '話題画面で話題を作成すると、ここから割り当てられます。',
                    )
                  : visible.isEmpty
                  ? EmptyState(
                      icon: Icons.search_off,
                      title: '条件に一致する話題がありません',
                      message: '検索やフィルター条件を変更してください。',
                      action: hasConditions
                          ? TextButton(
                              onPressed: _clearConditions,
                              child: const Text('条件をクリア'),
                            )
                          : null,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final topic = visible[index];
                        final alreadyAssigned = assignedIds.contains(topic.id);
                        final archived = widget.store.isArchived(topic.id);
                        final enabled =
                            !alreadyAssigned && !archived && !_saving;
                        return _TopicSelectionTile(
                          topic: topic,
                          categoryName: widget.store.categoryName(
                            topic.categoryId,
                          ),
                          selected: _selectedIds.contains(topic.id),
                          enabled: enabled,
                          disabledLabels: [
                            if (alreadyAssigned) '追加済み',
                            if (archived) 'アーカイブ済み',
                          ],
                          onChanged: enabled
                              ? () => setState(() {
                                  if (!_selectedIds.add(topic.id)) {
                                    _selectedIds.remove(topic.id);
                                  }
                                })
                              : null,
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

  List<Topic> _filterTopics(List<Topic> source) {
    final query = _search.text.trim().toLowerCase();
    final topics = source.where((topic) {
      final haystack =
          '${topic.title} ${topic.openingQuestion} ${topic.talkingPoints.join(' ')} ${topic.note} ${widget.store.categoryName(topic.categoryId)}'
              .toLowerCase();
      final matchesFilter = switch (_filter) {
        _PickerFilter.all => true,
        _PickerFilter.favorite => widget.store.isFavorite(topic.id),
        _PickerFilter.mine => topic.isCustom,
      };
      return matchesFilter &&
          (_categoryId == null || topic.categoryId == _categoryId) &&
          (query.isEmpty || haystack.contains(query));
    }).toList();
    if (_sort == _PickerSort.name) {
      topics.sort((a, b) => a.title.compareTo(b.title));
    }
    return topics;
  }

  void _clearConditions() {
    _search.clear();
    setState(() {
      _filter = _PickerFilter.all;
      _categoryId = null;
      _sort = _PickerSort.standard;
    });
  }

  Future<void> _save() async {
    if (_saving || _selectedIds.isEmpty) return;
    setState(() => _saving = true);
    final success = await widget.store.assignTopicsToPerson(
      personId: widget.personId,
      topicIds: _selectedIds,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) {
      Navigator.of(context).pop();
    } else {
      showStoreError(context, widget.store);
    }
  }
}

class _TopicSelectionTile extends StatelessWidget {
  const _TopicSelectionTile({
    required this.topic,
    required this.categoryName,
    required this.selected,
    required this.enabled,
    required this.onChanged,
    this.disabledLabels = const <String>[],
  });

  final Topic topic;
  final String categoryName;
  final bool selected;
  final bool enabled;
  final List<String> disabledLabels;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? appCardColor : appSubtleColor;
    final borderColor = selected ? brandColor : appOutlineColor;
    return Semantics(
      button: true,
      checked: selected,
      enabled: enabled,
      label:
          '${topic.title}、$categoryName${disabledLabels.isEmpty ? '' : '、${disabledLabels.join('、')}、選択不可'}',
      child: Card(
        color: selected ? appSelectedColor : color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onChanged,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: enabled ? null : appSecondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            categoryName,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          ...disabledLabels.map(
                            (label) => Chip(
                              label: Text(label),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                      if (topic.openingQuestion.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          topic.openingQuestion,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: appSecondaryTextColor),
                        ),
                      ],
                    ],
                  ),
                ),
                ExcludeSemantics(
                  child: Checkbox(
                    value: selected,
                    onChanged: enabled ? (_) => onChanged?.call() : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
