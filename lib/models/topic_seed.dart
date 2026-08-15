import 'dart:collection';

/// Non-persistent input material used to ask AI for person-specific topics.
class TopicSeed {
  TopicSeed({
    required this.id,
    required this.categoryId,
    required this.theme,
    Iterable<String> conversationPatterns = const <String>[],
    Iterable<String> hintCandidates = const <String>[],
  }) : _conversationPatterns = UnmodifiableListView<String>(
         List<String>.from(conversationPatterns),
       ),
       _hintCandidates = UnmodifiableListView<String>(
         List<String>.from(hintCandidates),
       );

  final String id;
  final String categoryId;
  final String theme;
  final List<String> _conversationPatterns;
  final List<String> _hintCandidates;

  List<String> get conversationPatterns =>
      List.unmodifiable(_conversationPatterns);
  List<String> get hintCandidates => List.unmodifiable(_hintCandidates);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'categoryId': categoryId,
    'theme': theme,
    'conversationPatterns': List<String>.from(_conversationPatterns),
    'hintCandidates': List<String>.from(_hintCandidates),
  };
}
