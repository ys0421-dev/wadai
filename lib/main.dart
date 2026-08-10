import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _brandColor = Color(0xFFB85C38);

void main() {
  runApp(const WadaiApp());
}

class Category {
  const Category({required this.id, required this.name});

  final String id;
  final String name;
}

class Topic {
  Topic({
    required this.id,
    required this.title,
    required this.categoryId,
    this.description = '',
    this.isCustom = false,
    this.isFavorite = false,
    this.createdAt,
  });

  final String id;
  final String title;
  final String categoryId;
  final String description;
  final bool isCustom;
  bool isFavorite;
  final DateTime? createdAt;

  Topic copyWith({
    String? title,
    String? categoryId,
    String? description,
    bool? isFavorite,
  }) {
    return Topic(
      id: id,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      description: description ?? this.description,
      isCustom: isCustom,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'categoryId': categoryId,
      'description': description,
      'isCustom': isCustom,
      'isFavorite': isFavorite,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] as String,
      title: json['title'] as String,
      categoryId: json['categoryId'] as String,
      description: (json['description'] as String?) ?? '',
      isCustom: json['isCustom'] as bool? ?? true,
      isFavorite: json['isFavorite'] as bool? ?? false,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
    );
  }
}

const categories = <Category>[
  Category(id: 'hobby', name: '趣味'),
  Category(id: 'travel', name: '旅行'),
  Category(id: 'food', name: '食べ物'),
  Category(id: 'entertainment', name: 'エンタメ'),
  Category(id: 'work', name: '仕事'),
  Category(id: 'daily', name: '日常'),
  Category(id: 'sports', name: 'スポーツ'),
  Category(id: 'learning', name: '学習'),
  Category(id: 'other', name: 'その他'),
];

List<Topic> _createStaticTopics() {
  final seed = <String, List<String>>{
    'hobby': ['最近ハマっていること', '最近始めた趣味', '休日の過ごし方', '最近買ってよかったもの'],
    'travel': ['最近行った場所', '行ってみたい場所', '印象に残っている旅行', '旅行で食べたもの'],
    'food': ['好きな食べ物', '最近食べて美味しかったもの', '好きな料理', '行ってみたい飲食店'],
    'entertainment': ['最近見た映画', '最近見たドラマ', '好きな音楽', '最近ハマっている作品'],
    'work': ['今どんな仕事をしているか', '最近仕事で面白かったこと', '仕事で大変なこと', '今後やってみたい仕事'],
    'daily': ['休日の過ごし方', '朝型か夜型か', '最近あった出来事', '最近買ったもの'],
    'sports': ['好きなスポーツ', '最近やっている運動', '観戦するスポーツ', '学生時代にやっていたスポーツ'],
    'learning': ['最近勉強していること', '身につけたいスキル', '学生時代に好きだった科目', '最近興味を持ったこと'],
    'other': ['地元について', '子供の頃好きだったもの', '行ってみたい場所', '将来やってみたいこと'],
  };

  return [
    for (final entry in seed.entries)
      for (var index = 0; index < entry.value.length; index++)
        Topic(
          id: 'static-${entry.key}-$index',
          title: entry.value[index],
          categoryId: entry.key,
          description: '「${entry.value[index]}」について聞いてみる',
        ),
  ];
}

class TopicStore extends ChangeNotifier {
  static const _customTopicsKey = 'custom_topics';
  static const _favoriteIdsKey = 'favorite_topic_ids';

  final List<Topic> _topics = _createStaticTopics();
  String? lastError;

  List<Topic> get topics => List.unmodifiable(_topics);

  List<Topic> get customTopics =>
      List.unmodifiable(_topics.where((topic) => topic.isCustom));

  List<Topic> get favoriteTopics =>
      List.unmodifiable(_topics.where((topic) => topic.isFavorite));

  Topic? topicById(String id) {
    for (final topic in _topics) {
      if (topic.id == id) return topic;
    }
    return null;
  }

  String categoryName(String categoryId) {
    return categories
        .firstWhere(
          (category) => category.id == categoryId,
          orElse: () => const Category(id: 'unknown', name: 'その他'),
        )
        .name;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTopics = prefs.getString(_customTopicsKey);
      final savedFavoriteIds = prefs.getStringList(_favoriteIdsKey);
      final customTopics = savedTopics == null
          ? <Topic>[]
          : (jsonDecode(savedTopics) as List<dynamic>)
                .map((item) => Topic.fromJson(item as Map<String, dynamic>))
                .toList();
      final favoriteIds = savedFavoriteIds == null
          ? customTopics
                .where((topic) => topic.isFavorite)
                .map((topic) => topic.id)
                .toSet()
          : savedFavoriteIds.toSet();

      _topics
        ..removeWhere((topic) => topic.isCustom)
        ..addAll(customTopics);
      for (final topic in _topics) {
        topic.isFavorite = favoriteIds.contains(topic.id);
      }
      lastError = null;
    } catch (_) {
      lastError = '保存データを読み込めませんでした。初期状態で起動します。';
    }
    notifyListeners();
  }

  Future<bool> toggleFavorite(String id) async {
    final topic = topicById(id);
    if (topic == null) return false;
    topic.isFavorite = !topic.isFavorite;
    notifyListeners();
    return _persist();
  }

  Future<bool> addTopic({
    required String title,
    required String categoryId,
    required String description,
  }) async {
    final topic = Topic(
      id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      categoryId: categoryId,
      description: description,
      isCustom: true,
      createdAt: DateTime.now(),
    );
    _topics.add(topic);
    notifyListeners();
    final saved = await _persist();
    if (!saved) {
      _topics.remove(topic);
      notifyListeners();
    }
    return saved;
  }

  Future<bool> updateTopic({
    required String id,
    required String title,
    required String categoryId,
    required String description,
  }) async {
    final index = _topics.indexWhere((topic) => topic.id == id);
    if (index == -1 || !_topics[index].isCustom) return false;
    final original = _topics[index];
    _topics[index] = original.copyWith(
      title: title,
      categoryId: categoryId,
      description: description,
    );
    notifyListeners();
    final saved = await _persist();
    if (!saved) {
      _topics[index] = original;
      notifyListeners();
    }
    return saved;
  }

  Future<bool> deleteTopic(String id) async {
    final index = _topics.indexWhere((topic) => topic.id == id);
    if (index == -1 || !_topics[index].isCustom) return false;
    final deleted = _topics.removeAt(index);
    notifyListeners();
    final saved = await _persist();
    if (!saved) {
      _topics.insert(index, deleted);
      notifyListeners();
    }
    return saved;
  }

  Future<bool> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customJson = jsonEncode(
        _topics
            .where((topic) => topic.isCustom)
            .map((topic) => topic.toJson())
            .toList(),
      );
      final favoriteIds = _topics
          .where((topic) => topic.isFavorite)
          .map((topic) => topic.id)
          .toList();
      final savedTopics = await prefs.setString(_customTopicsKey, customJson);
      final savedFavorites = await prefs.setStringList(
        _favoriteIdsKey,
        favoriteIds,
      );
      if (!savedTopics || !savedFavorites) {
        throw Exception('SharedPreferences write failed');
      }
      lastError = null;
      return true;
    } catch (_) {
      lastError = '保存に失敗しました。もう一度お試しください。';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    lastError = null;
  }
}

class WadaiApp extends StatefulWidget {
  const WadaiApp({super.key});

  @override
  State<WadaiApp> createState() => _WadaiAppState();
}

class _WadaiAppState extends State<WadaiApp> {
  late final TopicStore _store;

  @override
  void initState() {
    super.initState();
    _store = TopicStore()..load();
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _brandColor,
      brightness: Brightness.light,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WADEE',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFFFF9F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFF9F5),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE9DED7)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _brandColor, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
        ),
      ),
      home: AppShell(store: _store),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({required this.store, super.key});

  final TopicStore store;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  String? _selectedCategoryId;

  void _openTopics({String? categoryId}) {
    setState(() {
      _selectedIndex = 1;
      _selectedCategoryId = categoryId;
    });
  }

  Future<void> _openCategories() async {
    final categoryId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => CategoryScreen(store: widget.store)),
    );
    if (!mounted || categoryId == null) return;
    _openTopics(categoryId: categoryId);
  }

  Future<void> _openTopic(String topicId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            TopicDetailScreen(store: widget.store, topicId: topicId),
      ),
    );
  }

  Future<void> _openForm({Topic? topic}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TopicFormScreen(store: widget.store, topic: topic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        store: widget.store,
        onOpenTopics: () => _openTopics(),
        onOpenCategory: (id) => _openTopics(categoryId: id),
        onOpenMine: () => setState(() => _selectedIndex = 3),
        onOpenFavorites: () => setState(() => _selectedIndex = 2),
        onOpenCategories: _openCategories,
        onOpenForm: () => _openForm(),
      ),
      BrowseScreen(
        key: ValueKey(_selectedCategoryId),
        store: widget.store,
        initialCategoryId: _selectedCategoryId,
        onOpenTopic: _openTopic,
      ),
      FavoritesScreen(store: widget.store, onOpenTopic: _openTopic),
      MyTopicsScreen(
        store: widget.store,
        onOpenTopic: _openTopic,
        onOpenForm: _openForm,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
            if (index != 1) _selectedCategoryId = null;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'ホーム',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: '話題を探す',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'お気に入り',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note),
            label: 'マイ話題',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.store,
    required this.onOpenTopics,
    required this.onOpenCategory,
    required this.onOpenMine,
    required this.onOpenFavorites,
    required this.onOpenCategories,
    required this.onOpenForm,
    super.key,
  });

  final TopicStore store;
  final VoidCallback onOpenTopics;
  final ValueChanged<String> onOpenCategory;
  final VoidCallback onOpenMine;
  final VoidCallback onOpenFavorites;
  final VoidCallback onOpenCategories;
  final VoidCallback onOpenForm;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'WADEE',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '今日は、何を話そう？',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF34231D),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '会話のきっかけを見つけて、\n自然な会話を楽しもう。',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF765F55),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _HomeEntryCard(
                    icon: Icons.forum_outlined,
                    color: const Color(0xFFF2D6C7),
                    title: '定番話題',
                    description: '仕事・友人・初対面など、\nさまざまな場面で使える定番の話題',
                    onTap: onOpenTopics,
                  ),
                  const SizedBox(height: 12),
                  _HomeEntryCard(
                    icon: Icons.edit_note,
                    color: const Color(0xFFDCE6D5),
                    title: 'マイ話題',
                    description: '自分で登録した話題を管理',
                    badge: '${store.customTopics.length}件',
                    onTap: onOpenMine,
                  ),
                  const SizedBox(height: 12),
                  _HomeEntryCard(
                    icon: Icons.favorite_outline,
                    color: const Color(0xFFF5D9DD),
                    title: 'お気に入り',
                    description: '気になった話題をすぐ確認',
                    badge: '${store.favoriteTopics.length}件',
                    onTap: onOpenFavorites,
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'カテゴリから探す',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextButton(
                        onPressed: onOpenCategories,
                        child: const Text('すべて見る'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((category) {
                      return ActionChip(
                        label: Text(category.name),
                        avatar: Icon(_categoryIcon(category.id), size: 17),
                        onPressed: () => onOpenCategory(category.id),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                  OutlinedButton.icon(
                    onPressed: onOpenForm,
                    icon: const Icon(Icons.add),
                    label: const Text('自分の話題を追加する'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomeEntryCard extends StatelessWidget {
  const _HomeEntryCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFF0E5DF)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: color,
                child: Icon(icon, color: const Color(0xFF5C3E32)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            badge!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _brandColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF765F55),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFB39B90)),
            ],
          ),
        ),
      ),
    );
  }
}

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({
    required this.store,
    required this.onOpenTopic,
    this.initialCategoryId,
    super.key,
  });

  final TopicStore store;
  final String? initialCategoryId;
  final ValueChanged<String> onOpenTopic;

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  late String? _selectedCategoryId = widget.initialCategoryId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final visibleTopics = widget.store.topics.where((topic) {
          return _selectedCategoryId == null ||
              topic.categoryId == _selectedCategoryId;
        }).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('話題を探す')),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Text(
                  '気になる話題を選んで、\n会話のきっかけにしてみましょう。',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF765F55),
                    height: 1.45,
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('すべて'),
                      selected: _selectedCategoryId == null,
                      onSelected: (_) =>
                          setState(() => _selectedCategoryId = null),
                    ),
                    const SizedBox(width: 8),
                    ...categories.map(
                      (category) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category.name),
                          avatar: Icon(_categoryIcon(category.id), size: 17),
                          selected: _selectedCategoryId == category.id,
                          onSelected: (_) =>
                              setState(() => _selectedCategoryId = category.id),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                child: Text(
                  _selectedCategoryId == null
                      ? 'すべての話題  ${visibleTopics.length}件'
                      : '${widget.store.categoryName(_selectedCategoryId!)}の話題  ${visibleTopics.length}件',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF5C3E32),
                  ),
                ),
              ),
              Expanded(
                child: visibleTopics.isEmpty
                    ? const _EmptyState(
                        icon: Icons.forum_outlined,
                        title: 'このカテゴリにはまだ話題がありません',
                        message: 'マイ話題から自分だけの話題を追加できます。',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: visibleTopics.length,
                        itemBuilder: (context, index) {
                          final topic = visibleTopics[index];
                          return TopicTile(
                            topic: topic,
                            categoryName: widget.store.categoryName(
                              topic.categoryId,
                            ),
                            onTap: () => widget.onOpenTopic(topic.id),
                            onToggleFavorite: () => _toggleFavorite(topic.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleFavorite(String topicId) async {
    final saved = await widget.store.toggleFavorite(topicId);
    if (!saved && mounted) _showStoreError(context, widget.store);
  }
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({
    required this.store,
    required this.onOpenTopic,
    super.key,
  });

  final TopicStore store;
  final ValueChanged<String> onOpenTopic;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final favoriteTopics = store.favoriteTopics;
        return Scaffold(
          appBar: AppBar(title: const Text('お気に入り')),
          body: favoriteTopics.isEmpty
              ? const _EmptyState(
                  icon: Icons.favorite_border,
                  title: 'お気に入りの話題はありません',
                  message: '気になる話題の♡を押して\nお気に入りに追加してください。',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: favoriteTopics.length,
                  itemBuilder: (context, index) {
                    final topic = favoriteTopics[index];
                    return TopicTile(
                      topic: topic,
                      categoryName: store.categoryName(topic.categoryId),
                      onTap: () => onOpenTopic(topic.id),
                      onToggleFavorite: () =>
                          _toggleFavorite(context, topic.id),
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> _toggleFavorite(BuildContext context, String topicId) async {
    final saved = await store.toggleFavorite(topicId);
    if (!saved && context.mounted) _showStoreError(context, store);
  }
}

class MyTopicsScreen extends StatelessWidget {
  const MyTopicsScreen({
    required this.store,
    required this.onOpenTopic,
    required this.onOpenForm,
    super.key,
  });

  final TopicStore store;
  final ValueChanged<String> onOpenTopic;
  final Future<void> Function({Topic? topic}) onOpenForm;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final customTopics = store.customTopics;
        return Scaffold(
          appBar: AppBar(
            title: const Text('マイ話題'),
            actions: [
              IconButton(
                onPressed: () => onOpenForm(topic: null),
                tooltip: '話題を追加',
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          floatingActionButton: customTopics.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => onOpenForm(topic: null),
                  icon: const Icon(Icons.add),
                  label: const Text('話題を追加'),
                ),
          body: customTopics.isEmpty
              ? _EmptyState(
                  icon: Icons.edit_note,
                  title: 'まだ自分の話題がありません',
                  message: '「＋」ボタンから話題を追加できます。',
                  action: FilledButton.icon(
                    onPressed: () => onOpenForm(topic: null),
                    icon: const Icon(Icons.add),
                    label: const Text('話題を追加する'),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: customTopics.length,
                  itemBuilder: (context, index) {
                    final topic = customTopics[index];
                    return TopicTile(
                      topic: topic,
                      categoryName: store.categoryName(topic.categoryId),
                      onTap: () => onOpenTopic(topic.id),
                      onToggleFavorite: () =>
                          _toggleFavorite(context, topic.id),
                      onEdit: () => onOpenForm(topic: topic),
                      onDelete: () => _deleteTopic(context, topic),
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> _toggleFavorite(BuildContext context, String topicId) async {
    final saved = await store.toggleFavorite(topicId);
    if (!saved && context.mounted) _showStoreError(context, store);
  }

  Future<void> _deleteTopic(BuildContext context, Topic topic) async {
    await showDeleteTopicDialog(context: context, store: store, topic: topic);
  }
}

class TopicTile extends StatelessWidget {
  const TopicTile({
    required this.topic,
    required this.categoryName,
    required this.onTap,
    required this.onToggleFavorite,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  final Topic topic;
  final String categoryName;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFF0E5DF)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 14, 8, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          _categoryIcon(topic.categoryId),
                          size: 15,
                          color: _brandColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          categoryName,
                          style: const TextStyle(
                            color: Color(0xFF856E64),
                            fontSize: 13,
                          ),
                        ),
                        if (topic.isCustom) ...[
                          const SizedBox(width: 8),
                          const _SmallLabel(text: '自作'),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onToggleFavorite,
                tooltip: topic.isFavorite ? 'お気に入りを解除' : 'お気に入りに追加',
                icon: Icon(
                  topic.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: topic.isFavorite
                      ? _brandColor
                      : const Color(0xFFB39B90),
                ),
              ),
              if (onEdit != null)
                PopupMenuButton<String>(
                  tooltip: 'メニュー',
                  onSelected: (value) {
                    if (value == 'edit') onEdit!();
                    if (value == 'delete') onDelete!();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('編集')),
                    PopupMenuItem(value: 'delete', child: Text('削除')),
                  ],
                ),
              const Icon(Icons.chevron_right, color: Color(0xFFB39B90)),
            ],
          ),
        ),
      ),
    );
  }
}

class TopicDetailScreen extends StatelessWidget {
  const TopicDetailScreen({
    required this.store,
    required this.topicId,
    super.key,
  });

  final TopicStore store;
  final String topicId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final topic = store.topicById(topicId);
        if (topic == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const _EmptyState(
              icon: Icons.error_outline,
              title: '話題が見つかりません',
              message: 'この話題は削除された可能性があります。',
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('話題の詳細'),
            actions: [
              if (topic.isCustom)
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              TopicFormScreen(store: store, topic: topic),
                        ),
                      );
                    } else if (value == 'delete') {
                      await showDeleteTopicDialog(
                        context: context,
                        store: store,
                        topic: topic,
                        popOnSuccess: true,
                      );
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('編集')),
                    PopupMenuItem(value: 'delete', child: Text('削除')),
                  ],
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF34231D),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'カテゴリ',
                  style: TextStyle(
                    color: Color(0xFF856E64),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Chip(
                  avatar: Icon(_categoryIcon(topic.categoryId), size: 17),
                  label: Text(store.categoryName(topic.categoryId)),
                ),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6E9E1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 19),
                          SizedBox(width: 8),
                          Text(
                            '会話のきっかけ',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        topic.isCustom && topic.description.trim().isNotEmpty
                            ? '「${topic.title}」について話してみる'
                            : topic.description,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.55,
                          color: const Color(0xFF4E2F23),
                        ),
                      ),
                    ],
                  ),
                ),
                if (topic.isCustom && topic.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'メモ',
                    style: TextStyle(
                      color: Color(0xFF856E64),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    topic.description,
                    style: const TextStyle(height: 1.65, fontSize: 16),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _toggleFavorite(context, topic.id),
                    icon: Icon(
                      topic.isFavorite ? Icons.favorite : Icons.favorite_border,
                    ),
                    label: Text(topic.isFavorite ? 'お気に入りから解除' : 'お気に入りに追加'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleFavorite(BuildContext context, String id) async {
    final saved = await store.toggleFavorite(id);
    if (!saved && context.mounted) _showStoreError(context, store);
  }
}

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({required this.store, super.key});

  final TopicStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('カテゴリ')),
          body: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final category = categories[index];
              final count = store.topics
                  .where((topic) => topic.categoryId == category.id)
                  .length;
              return Card(
                margin: EdgeInsets.zero,
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFF0E5DF)),
                ),
                child: ListTile(
                  onTap: () => Navigator.of(context).pop(category.id),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 5,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFF2D6C7),
                    child: Icon(_categoryIcon(category.id), color: _brandColor),
                  ),
                  title: Text(
                    category.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text('$count件の話題'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class TopicFormScreen extends StatefulWidget {
  const TopicFormScreen({required this.store, this.topic, super.key});

  final TopicStore store;
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '話題を編集' : '話題を追加'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('保存'),
          ),
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
                color: const Color(0xFF765F55),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            const _FieldLabel(text: 'タイトル', required: true),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: '例：北海道旅行',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'タイトルを入力してください';
                }
                return null;
              },
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
              validator: (value) {
                if (value == null || value.isEmpty) return 'カテゴリを選択してください';
                return null;
              },
            ),
            const SizedBox(height: 22),
            const _FieldLabel(text: 'メモ'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              minLines: 5,
              maxLines: 8,
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
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final saved = _isEditing
        ? await widget.store.updateTopic(
            id: widget.topic!.id,
            title: title,
            categoryId: _categoryId!,
            description: description,
          )
        : await widget.store.addTopic(
            title: title,
            categoryId: _categoryId!,
            description: description,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      Navigator.of(context).pop();
    } else {
      _showStoreError(context, widget.store);
    }
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text, this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
        if (required)
          const Text('  *', style: TextStyle(color: Colors.redAccent)),
      ],
    );
  }
}

class _SmallLabel extends StatelessWidget {
  const _SmallLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF4E8E2),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF856E64),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: const Color(0xFFF6E9E1),
              child: Icon(icon, size: 30, color: _brandColor),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 9),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF765F55), height: 1.55),
            ),
            if (action != null) ...[const SizedBox(height: 22), action!],
          ],
        ),
      ),
    );
  }
}

Future<void> showDeleteTopicDialog({
  required BuildContext context,
  required TopicStore store,
  required Topic topic,
  bool popOnSuccess = false,
}) async {
  final shouldDelete = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('話題を削除しますか？'),
        content: Text('「${topic.title}」を削除します。\nこの操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('削除する'),
          ),
        ],
      );
    },
  );
  if (shouldDelete != true || !context.mounted) return;
  final deleted = await store.deleteTopic(topic.id);
  if (!context.mounted) return;
  if (deleted) {
    if (popOnSuccess) Navigator.of(context).pop();
    return;
  }
  _showStoreError(context, store);
}

void _showStoreError(BuildContext context, TopicStore store) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(store.lastError ?? '保存に失敗しました。')));
  store.clearError();
}

IconData _categoryIcon(String categoryId) {
  switch (categoryId) {
    case 'hobby':
      return Icons.palette_outlined;
    case 'travel':
      return Icons.flight_takeoff;
    case 'food':
      return Icons.restaurant_outlined;
    case 'entertainment':
      return Icons.movie_outlined;
    case 'work':
      return Icons.work_outline;
    case 'daily':
      return Icons.wb_sunny_outlined;
    case 'sports':
      return Icons.sports_tennis_outlined;
    case 'learning':
      return Icons.menu_book_outlined;
    default:
      return Icons.more_horiz;
  }
}
