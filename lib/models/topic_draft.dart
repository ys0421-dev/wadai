import 'dart:collection';

/// Immutable input used when AI proposes several topics for one person.
class TopicDraft {
  TopicDraft({
    required this.title,
    required this.categoryId,
    required this.openingQuestion,
    Iterable<String> talkingPoints = const <String>[],
    this.note = '',
  }) : _talkingPoints = UnmodifiableListView<String>(
         List<String>.from(talkingPoints),
       );

  final String title;
  final String categoryId;
  final String openingQuestion;
  final List<String> _talkingPoints;
  final String note;

  List<String> get talkingPoints => List.unmodifiable(_talkingPoints);
}
