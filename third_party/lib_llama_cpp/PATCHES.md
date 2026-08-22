# WADEE local patch for `lib_llama_cpp`

This package is a vendored copy of [`lib_llama_cpp` 0.7.3](https://pub.dev/packages/lib_llama_cpp/versions/0.7.3), sourced from upstream commit [`c04786f3e333b96ebc4b546a12b27cf94eb15eca`](https://github.com/gsmlg-app/lib_llama_cpp/commit/c04786f3e333b96ebc4b546a12b27cf94eb15eca). The pub.dev archive checksum is `94cb9dd4cae4e3138be5fb4a666b565f9030d4d053298520628290dcbdf277c6`.

It remains under the upstream MIT license; see [LICENSE](LICENSE). The copied source is intentionally retained in this repository so the UTF-8 token-piece fix is reproducible while upstream does not contain it.

## WADEE patch

The vendor contains the full upstream package surface: library sources, README, CHANGELOG, analysis options, and upstream tests. It is deliberately not a generated partial copy.

`llama_token_to_piece` results are retained as raw bytes. `Utf8TokenPieceStream` performs strict chunked UTF-8 decoding across token boundaries, sends completed text to stop-sequence matching, and emits `LlamaTokenResponse` values immediately. A final decoder close reports incomplete or malformed input instead of replacing it.

The intentional source changes are limited to:

- `lib/src/native_runtime.dart`
- `lib/src/utf8_token_piece_decoder.dart` (added)
- `pubspec.yaml` (local version, `publish_to: none`, and removal of the
  upstream workspace-only `resolution: workspace` setting)
- `.gitignore` (excludes local Flutter test/build outputs and the vendor lockfile)

When updating upstream, copy the new upstream release contents first, reapply the files above, compare every other vendored file with that release, then run `dart format lib test`, `flutter test`, `flutter analyze`, and the WADEE root test suite. The root `pubspec.lock` records the local path package version.
