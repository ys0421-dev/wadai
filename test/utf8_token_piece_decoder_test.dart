import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lib_llama_cpp/lib_llama_cpp.dart';
// ignore: implementation_imports
import 'package:lib_llama_cpp/src/utf8_token_piece_decoder.dart';

void main() {
  group('UTF-8 token piece stream', () {
    test('emits completed split characters before close', () {
      final stream = Utf8TokenPieceStream();

      expect(stream.add(<int>[0xe3], index: 4), isEmpty);
      expect(stream.add(<int>[0x81, 0x82], index: 5), <LlamaTokenResponse>[
        LlamaTokenResponse(text: String.fromCharCodes(<int>[0x3042]), index: 5),
      ]);
      expect(stream.close(index: 6), isEmpty);
    });

    test('emits ASCII before close at the completed token index', () {
      final stream = Utf8TokenPieceStream();

      expect(
        stream.add(utf8.encode('ASCII'), index: 9),
        const <LlamaTokenResponse>[LlamaTokenResponse(text: 'ASCII', index: 9)],
      );
      expect(stream.close(index: 10), isEmpty);
    });

    test('decodes 2-, 3-, and 4-byte characters across several boundaries', () {
      final stream = Utf8TokenPieceStream();
      final responses = <LlamaTokenResponse>[];
      final pieces = <List<int>>[
        <int>[0xc2],
        <int>[0xa2],
        <int>[0xe3],
        <int>[0x81],
        <int>[0x82],
        <int>[0xf0, 0x9f],
        <int>[0x98],
        <int>[0x80],
      ];

      for (var index = 0; index < pieces.length; index += 1) {
        responses.addAll(stream.add(pieces[index], index: index));
      }
      responses.addAll(stream.close(index: pieces.length));

      expect(
        responses.map((response) => response.text).join(),
        String.fromCharCodes(<int>[0xa2, 0x3042, 0x1f600]),
      );
    });

    test('stops across piece boundaries and never emits later pieces', () {
      final stream = Utf8TokenPieceStream(stop: const <String>['<END>']);

      expect(
        stream.add(utf8.encode('before<EN'), index: 0),
        const <LlamaTokenResponse>[LlamaTokenResponse(text: 'befor', index: 0)],
      );
      expect(
        stream.add(utf8.encode('D>after'), index: 1),
        const <LlamaTokenResponse>[LlamaTokenResponse(text: 'e', index: 1)],
      );
      expect(stream.isStopped, isTrue);
      expect(stream.add(utf8.encode('ignored'), index: 2), isEmpty);
      expect(stream.close(index: 3), isEmpty);
    });

    test('close flushes text held for a possible stop sequence', () {
      final stream = Utf8TokenPieceStream(stop: const <String>['END']);

      expect(
        stream.add(utf8.encode('abc'), index: 0),
        const <LlamaTokenResponse>[LlamaTokenResponse(text: 'a', index: 0)],
      );
      expect(stream.close(index: 1), const <LlamaTokenResponse>[
        LlamaTokenResponse(text: 'bc', index: 1),
      ]);
    });

    test('throws on incomplete or malformed UTF-8', () {
      final incomplete = Utf8TokenPieceStream();
      expect(incomplete.add(<int>[0xe3, 0x81], index: 0), isEmpty);
      expect(() => incomplete.close(index: 1), throwsFormatException);

      final malformed = Utf8TokenPieceStream();
      expect(() => malformed.add(<int>[0x80], index: 0), throwsFormatException);
    });
  });
}
