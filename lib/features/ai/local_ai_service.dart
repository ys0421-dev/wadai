import 'dart:convert';
import 'dart:io';

import 'package:lib_llama_cpp/lib_llama_cpp.dart';

import '../../data/topic_catalog.dart';
import '../../data/topic_seed_catalog.dart';
import '../../models/person.dart';
import '../../models/person_topic.dart';
import '../../models/topic.dart';
import '../../models/topic_draft.dart';

enum LocalAIStage { loadingModel, generating }

class LocalAIProgress {
  const LocalAIProgress(this.stage);
  final LocalAIStage stage;
}

class LocalAIDiagnostics {
  const LocalAIDiagnostics({
    required this.elapsed,
    required this.rssDeltaBytes,
  });
  final Duration elapsed;
  final int rssDeltaBytes;
}

class LocalAIResult {
  const LocalAIResult({required this.drafts, required this.diagnostics});
  final List<TopicDraft> drafts;
  final LocalAIDiagnostics diagnostics;
}

class LocalAIRequest {
  const LocalAIRequest({
    required this.person,
    required this.topics,
    required this.personTopics,
  });
  final Person person;
  final List<Topic> topics;
  final List<PersonTopic> personTopics;
}

abstract interface class LocalAIService {
  Future<LocalAIResult> suggest(
    LocalAIRequest request, {
    required void Function(LocalAIProgress progress) onProgress,
  });
}

/// Builds the local-only input. No part of this request is sent to a network.
class LocalAIPromptBuilder {
  const LocalAIPromptBuilder();

  String build(LocalAIRequest request) {
    final relations = <String, PersonTopic>{
      for (final item in request.personTopics) item.topicId: item,
    };
    final existing = request.topics
        .where((topic) => relations.containsKey(topic.id))
        .map((topic) {
          final relation = relations[topic.id]!;
          return <String, Object?>{
            'title': topic.title,
            'categoryId': topic.categoryId,
            'openingQuestion': topic.openingQuestion,
            'talkingPoints': topic.talkingPoints,
            'note': topic.note,
            'status': relation.status.name,
            'personNote': relation.note,
          };
        })
        .toList(growable: false);
    final seeds = <Object?>[
      for (final category in categories)
        ...topicSeeds
            .where((seed) => seed.categoryId == category.id)
            .take(1)
            .map((seed) => seed.toJson()),
    ];
    return '''あなたは会話の話題を提案するアシスタントです。入力JSONを参照し、本人に合う日本語の会話話題を正確に4件提案してください。既存話題との重複と避けたい話題を尊重し、Markdownや説明を含めずJSON配列だけを返してください。各要素のキーは title, categoryId, openingQuestion, talkingPoints, note のみです。
${jsonEncode(<String, Object?>{
      'person': <String, Object?>{'displayName': request.person.displayName, 'note': request.person.note, 'profile': request.person.profile.toStructuredMap()},
      'existingTopics': existing,
      'topicSeeds': seeds,
      'categories': categories.map((category) => category.id).toList(),
    })}''';
  }
}

class LocalAISuggestionParser {
  const LocalAISuggestionParser();
  List<TopicDraft> parse(String raw) {
    final Object? value;
    try {
      value = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('AI response must be a JSON array');
    }
    if (value is! List || value.length != 4) {
      throw const FormatException(
        'AI response must contain exactly four topics',
      );
    }
    final seen = <String>{};
    final drafts = <TopicDraft>[];
    for (final item in value) {
      if (item is! Map<String, dynamic> ||
          item.keys.toSet().difference(const <String>{
            'title',
            'categoryId',
            'openingQuestion',
            'talkingPoints',
            'note',
          }).isNotEmpty ||
          item.length < 4 ||
          item['title'] is! String ||
          item['categoryId'] is! String ||
          item['openingQuestion'] is! String ||
          (item['note'] != null && item['note'] is! String) ||
          item['talkingPoints'] is! List ||
          (item['talkingPoints'] as List).any((point) => point is! String)) {
        throw const FormatException('Invalid AI topic fields');
      }
      final title = (item['title'] as String).trim();
      final opening = (item['openingQuestion'] as String).trim();
      final categoryId = item['categoryId'] as String;
      final points = (item['talkingPoints'] as List)
          .cast<String>()
          .map((point) => point.trim())
          .toList(growable: false);
      if (title.isEmpty ||
          opening.isEmpty ||
          points.isEmpty ||
          points.any((point) => point.isEmpty) ||
          !categories.any((category) => category.id == categoryId)) {
        throw const FormatException('Invalid AI topic values');
      }
      if (!seen.add('${_normalize(title)}\u0000${_normalize(opening)}')) {
        throw const FormatException('Duplicate AI topic');
      }
      drafts.add(
        TopicDraft(
          title: title,
          categoryId: categoryId,
          openingQuestion: opening,
          talkingPoints: points,
          note: (item['note'] as String? ?? '').trim(),
        ),
      );
    }
    return List.unmodifiable(drafts);
  }

  String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

class LlamaLocalAIService implements LocalAIService {
  LlamaLocalAIService({
    required this.modelPath,
    LocalAIPromptBuilder? promptBuilder,
    LocalAISuggestionParser? parser,
    this.engine = const LibLlamaCpp(),
  }) : _promptBuilder = promptBuilder ?? const LocalAIPromptBuilder(),
       _parser = parser ?? const LocalAISuggestionParser();
  final String modelPath;
  final LocalAIPromptBuilder _promptBuilder;
  final LocalAISuggestionParser _parser;
  final LlamaEngine engine;

  @override
  Future<LocalAIResult> suggest(
    LocalAIRequest request, {
    required void Function(LocalAIProgress progress) onProgress,
  }) async {
    final beforeRss = ProcessInfo.currentRss;
    final stopwatch = Stopwatch()..start();
    onProgress(const LocalAIProgress(LocalAIStage.loadingModel));
    final output = StringBuffer();
    var generating = false;
    await for (final response in engine.transform(_commands(request))) {
      switch (response) {
        case LlamaTokenResponse(:final text):
          if (!generating) {
            generating = true;
            onProgress(const LocalAIProgress(LocalAIStage.generating));
          }
          output.write(text);
        case LlamaErrorResponse(:final message):
          throw StateError(message);
        case LlamaReadyResponse() ||
            LlamaStateChangedResponse() ||
            LlamaToolCallResponse() ||
            LlamaDoneResponse():
          break;
      }
    }
    stopwatch.stop();
    return LocalAIResult(
      drafts: _parser.parse(output.toString()),
      diagnostics: LocalAIDiagnostics(
        elapsed: stopwatch.elapsed,
        rssDeltaBytes: ProcessInfo.currentRss - beforeRss,
      ),
    );
  }

  Stream<LlamaCommand> _commands(LocalAIRequest request) async* {
    try {
      yield LlamaLoadModelCommand(modelPath: modelPath, contextSize: 4096);
      yield LlamaGenerateMessagesCommand(
        messages: <LlamaMessage>[
          const LlamaMessage(
            role: 'system',
            content: '日本語の会話話題を提案してください。説明やMarkdownを含めず、有効なJSON配列だけを出力してください。',
          ),
          LlamaMessage(role: 'user', content: _promptBuilder.build(request)),
        ],
        maxTokens: 900,
        temperature: 0.7,
      );
    } finally {
      yield const LlamaDisposeCommand();
    }
  }
}
