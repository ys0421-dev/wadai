import 'dart:convert';
import 'dart:math' as math;

import 'llama_response.dart';

/// Decodes raw llama.cpp token pieces without losing UTF-8 sequences that
/// span more than one token.
///
/// The default UTF-8 decoder is deliberately strict: malformed bytes and
/// unfinished trailing sequences throw [FormatException].
final class Utf8TokenPieceDecoder {
  Utf8TokenPieceDecoder() {
    _sink = utf8.decoder.startChunkedConversion(
      StringConversionSink.fromStringSink(_buffer),
    );
  }

  final StringBuffer _buffer = StringBuffer();
  late final ByteConversionSink _sink;

  List<String> add(List<int> bytes) => _collect(() => _sink.add(bytes));

  /// Finishes decoding and returns any completed trailing text.
  ///
  /// Throws [FormatException] if the final bytes are invalid or incomplete.
  List<String> close() => _collect(_sink.close);

  List<String> _collect(void Function() convert) {
    convert();
    final decoded = _buffer.toString();
    _buffer.clear();
    return decoded.isEmpty ? const <String>[] : <String>[decoded];
  }
}

/// Holds back text that may still become a configured stop sequence.
///
/// This accepts only complete Dart strings, so stop matching never observes a
/// fragment of a multi-byte UTF-8 sequence.
final class TokenPieceStopMatcher {
  TokenPieceStopMatcher(List<String> stop)
    : _stop = stop.where((item) => item.isNotEmpty).toList(),
      _maxStopLength = stop
          .where((item) => item.isNotEmpty)
          .fold<int>(0, (max, item) => math.max(max, item.length));

  final List<String> _stop;
  final int _maxStopLength;
  final StringBuffer _buffer = StringBuffer();
  var _emittedLength = 0;
  var isStopped = false;

  String add(String text) {
    if (isStopped) {
      return '';
    }

    _buffer.write(text);
    final value = _buffer.toString();
    final stopIndex = _firstStopIndex(value);
    if (stopIndex != null) {
      isStopped = true;
      final delta = value.substring(_emittedLength, stopIndex);
      _emittedLength = stopIndex;
      return delta;
    }

    if (_maxStopLength == 0) {
      final delta = value.substring(_emittedLength);
      _emittedLength = value.length;
      return delta;
    }

    final safeEnd = math.max(0, value.length - _maxStopLength + 1);
    if (safeEnd <= _emittedLength) {
      return '';
    }

    final delta = value.substring(_emittedLength, safeEnd);
    _emittedLength = safeEnd;
    return delta;
  }

  String flush() {
    if (isStopped) {
      return '';
    }

    final value = _buffer.toString();
    if (_emittedLength >= value.length) {
      return '';
    }

    final delta = value.substring(_emittedLength);
    _emittedLength = value.length;
    return delta;
  }

  int? _firstStopIndex(String value) {
    int? result;
    for (final stop in _stop) {
      final index = value.indexOf(stop);
      if (index >= 0 && (result == null || index < result)) {
        result = index;
      }
    }
    return result;
  }
}

/// Converts raw token bytes into streamable responses while preserving UTF-8
/// boundaries and stop-sequence semantics.
///
/// This is internal package plumbing. It is intentionally not exported by the
/// package entrypoint, but remains independently testable from package tests.
final class Utf8TokenPieceStream {
  Utf8TokenPieceStream({List<String> stop = const []})
    : _stopMatcher = TokenPieceStopMatcher(stop);

  final Utf8TokenPieceDecoder _decoder = Utf8TokenPieceDecoder();
  final TokenPieceStopMatcher _stopMatcher;

  bool get isStopped => _stopMatcher.isStopped;

  List<LlamaTokenResponse> add(List<int> piece, {required int index}) {
    final responses = <LlamaTokenResponse>[];
    for (final text in _decoder.add(piece)) {
      _addDecodedText(text, index: index, responses: responses);
    }
    return List<LlamaTokenResponse>.unmodifiable(responses);
  }

  /// Finishes the decoder, then flushes text that could not be emitted until
  /// every configured stop sequence was ruled out.
  List<LlamaTokenResponse> close({required int index}) {
    final responses = <LlamaTokenResponse>[];
    for (final text in _decoder.close()) {
      _addDecodedText(text, index: index, responses: responses);
    }
    final tail = _stopMatcher.flush();
    if (tail.isNotEmpty) {
      responses.add(LlamaTokenResponse(text: tail, index: index));
    }
    return List<LlamaTokenResponse>.unmodifiable(responses);
  }

  void _addDecodedText(
    String text, {
    required int index,
    required List<LlamaTokenResponse> responses,
  }) {
    final delta = _stopMatcher.add(text);
    if (delta.isNotEmpty) {
      responses.add(LlamaTokenResponse(text: delta, index: index));
    }
  }
}
