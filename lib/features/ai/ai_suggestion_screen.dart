import 'package:flutter/material.dart';

import '../../models/person.dart';
import '../../models/topic.dart';
import '../../models/topic_draft.dart';
import '../../state/wadee_controller.dart';
import '../people/person_form_screen.dart';
import 'local_ai_service.dart';
import 'local_model_manager.dart';

/// Selects locally generated conversation topics before storing them for one
/// person. The supplied manager is not disposed unless ownership is explicit;
/// this keeps injectable managers usable by the caller and by widget tests.
class AiSuggestionScreen extends StatefulWidget {
  const AiSuggestionScreen({
    required this.store,
    required this.person,
    required this.modelManager,
    required this.serviceFactory,
    this.disposeModelManager = false,
    super.key,
  });

  final WadeeController store;
  final Person person;
  final LocalModelManager modelManager;
  final LocalAIService Function(String modelPath) serviceFactory;
  final bool disposeModelManager;

  @override
  State<AiSuggestionScreen> createState() => _AiSuggestionScreenState();
}

class _AiSuggestionScreenState extends State<AiSuggestionScreen> {
  List<TopicDraft>? _drafts;
  final _selected = <int>{};
  LocalAIProgress? _progress;
  LocalAIDiagnostics? _diagnostics;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    await widget.modelManager.initialize();
    // The manager reports initialization errors in its status. This check only
    // prevents a completed future from trying to rebuild a closed route.
    if (!mounted) return;
  }

  @override
  void dispose() {
    if (widget.disposeModelManager) widget.modelManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge(<Listenable>[
      widget.store,
      widget.modelManager,
    ]),
    builder: (context, _) {
      final status = widget.modelManager.status;
      final person = widget.store.personById(widget.person.id) ?? widget.person;
      return Scaffold(
        appBar: AppBar(title: const Text('AIで話題を提案')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _ModelCard(status: status, onDownload: _downloadModel),
            const SizedBox(height: 16),
            if (person.profile.isEmpty)
              _ProfileHint(store: widget.store, person: person),
            if (_progress != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(_progressLabel(_progress!)),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              TextButton.icon(
                onPressed:
                    status.state == LocalModelState.ready && _progress == null
                    ? _generate
                    : null,
                icon: const Icon(Icons.refresh),
                label: const Text('生成をやり直す'),
              ),
            ],
            if (status.state == LocalModelState.ready && _drafts == null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: FilledButton.icon(
                  onPressed: _progress == null ? _generate : null,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('4件の話題を生成'),
                ),
              ),
            if (_drafts != null) ...[
              const SizedBox(height: 16),
              Text(
                '保存する話題を選択（${_selected.length}件）',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _drafts!.length; i++)
                _DraftCard(
                  draft: _drafts![i],
                  selected: _selected.contains(i),
                  onChanged: (selected) => setState(() {
                    if (selected) {
                      _selected.add(i);
                    } else {
                      _selected.remove(i);
                    }
                  }),
                ),
              if (_diagnostics != null)
                Text(
                  '生成時間: ${_diagnostics!.elapsed.inSeconds}秒 / '
                  'メモリ差分: ${_diagnostics!.rssDeltaBytes ~/ (1024 * 1024)}MB',
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _selected.isEmpty || _saving ? null : _saveSelected,
                child: Text('選択した話題を保存（${_selected.length}件）'),
              ),
            ],
          ],
        ),
      );
    },
  );

  Future<void> _downloadModel() async {
    await widget.modelManager.download();
  }

  String _progressLabel(LocalAIProgress progress) => switch (progress.stage) {
    LocalAIStage.loadingModel => 'モデルを読み込んでいます',
    LocalAIStage.generating => '話題を生成しています',
  };

  Future<void> _generate() async {
    if (widget.modelManager.status.state != LocalModelState.ready) return;
    final person = widget.store.personById(widget.person.id);
    if (person == null) return;
    final file = await widget.modelManager.modelFile();
    if (!mounted) return;
    setState(() {
      _error = null;
      _progress = const LocalAIProgress(LocalAIStage.loadingModel);
    });
    try {
      final result = await widget
          .serviceFactory(file.path)
          .suggest(
            LocalAIRequest(
              person: person,
              topics: widget.store
                  .personTopicsFor(person.id)
                  .map(
                    (relation) => widget.store.topicByIdIncludingArchived(
                      relation.topicId,
                    ),
                  )
                  .whereType<Topic>()
                  .toList(growable: false),
              personTopics: widget.store.personTopicsFor(person.id),
            ),
            onProgress: (progress) {
              if (mounted) setState(() => _progress = progress);
            },
          );
      if (!mounted) return;
      setState(() {
        _drafts = result.drafts;
        _selected.clear();
        _diagnostics = result.diagnostics;
        _progress = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _progress = null;
      });
    }
  }

  Future<void> _saveSelected() async {
    if (_drafts == null) return;
    setState(() => _saving = true);
    final selected = _selected
        .map((index) => _drafts![index])
        .toList(growable: false);
    List<String>? ids;
    try {
      ids = await widget.store.addAiGeneratedTopicsToPerson(
        widget.person.id,
        selected,
      );
    } catch (error) {
      if (mounted) setState(() => _error = '話題を保存できませんでした: $error');
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    if (ids == null) {
      setState(() => _error = '話題を保存できませんでした。選択を確認して再試行してください。');
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${ids.length}件の話題を保存しました。')));
    Navigator.of(context).pop();
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.status, required this.onDownload});

  final LocalModelStatus status;
  final Future<void> Function() onDownload;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ローカルAIモデル',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(qwenModelSpec.name),
            const Text('約491MB / Apache-2.0 / 個人情報は端末内で処理します。'),
            const SizedBox(height: 8),
            Text(_statusLabel(status)),
            if (status.state == LocalModelState.downloading)
              LinearProgressIndicator(
                value: (status.downloadedBytes / qwenModelSpec.sizeBytes).clamp(
                  0.0,
                  1.0,
                ),
              ),
            if (status.state == LocalModelState.unprepared ||
                status.state == LocalModelState.failed)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton.icon(
                  onPressed: onDownload,
                  icon: const Icon(Icons.download),
                  label: Text(
                    status.state == LocalModelState.failed
                        ? 'モデルを再試行'
                        : 'モデルをダウンロード',
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  String _statusLabel(LocalModelStatus status) => switch (status.state) {
    LocalModelState.unsupported => 'この端末ではローカルAIを利用できません。',
    LocalModelState.unprepared => 'モデルはまだ準備されていません。',
    LocalModelState.downloading =>
      'ダウンロード中: ${(status.downloadedBytes / 1024 / 1024).toStringAsFixed(1)}MB',
    LocalModelState.verifying => 'モデルを検証しています。',
    LocalModelState.ready => 'モデルの準備ができました。',
    LocalModelState.failed => '準備に失敗しました: ${status.message ?? ''}',
  };
}

class _ProfileHint extends StatelessWidget {
  const _ProfileHint({required this.store, required this.person});

  final WadeeController store;
  final Person person;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('プロフィールを追加すると、より相手に合う提案になります。'),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => PersonFormScreen(
                  store: store,
                  person: person,
                  initiallyExpandProfile: true,
                ),
              ),
            ),
            child: const Text('プロフィールを追加'),
          ),
        ],
      ),
    ),
  );
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.draft,
    required this.selected,
    required this.onChanged,
  });

  final TopicDraft draft;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: CheckboxListTile(
      value: selected,
      onChanged: (value) => onChanged(value ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(draft.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(draft.openingQuestion),
          ...draft.talkingPoints.map((point) => Text('・$point')),
        ],
      ),
    ),
  );
}
