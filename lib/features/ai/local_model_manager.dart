import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum LocalModelState {
  unsupported,
  unprepared,
  downloading,
  verifying,
  ready,
  failed,
}

class ModelSpec {
  const ModelSpec({
    required this.name,
    required this.fileName,
    required this.url,
    required this.sizeBytes,
    required this.sha256,
    required this.license,
  });

  final String name;
  final String fileName;
  final Uri url;
  final int sizeBytes;
  final String sha256;
  final String license;
}

final qwenModelSpec = ModelSpec(
  name: 'Qwen2.5-0.5B-Instruct (Q4_K_M)',
  fileName: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
  url: Uri.parse(
    'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf',
  ),
  sizeBytes: 491400032,
  sha256: '74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db',
  license: 'Apache-2.0',
);

class LocalModelStatus {
  const LocalModelStatus(this.state, {this.downloadedBytes = 0, this.message});
  final LocalModelState state;
  final int downloadedBytes;
  final String? message;
}

typedef ModelDirectoryProvider = Future<Directory> Function();
typedef ModelHttpClientFactory = HttpClient Function();

bool supportsLocalAIAbi(ffi.Abi abi) => abi == ffi.Abi.androidArm64;

class LocalModelManager extends ChangeNotifier {
  LocalModelManager({
    ModelSpec? spec,
    ModelDirectoryProvider? directoryProvider,
    ModelHttpClientFactory? clientFactory,
    bool Function()? supported,
  }) : spec = spec ?? qwenModelSpec,
       _directoryProvider = directoryProvider ?? _defaultDirectory,
       _clientFactory = clientFactory ?? HttpClient.new,
       _supported = supported ?? _defaultSupported;

  final ModelSpec spec;
  final ModelDirectoryProvider _directoryProvider;
  final ModelHttpClientFactory _clientFactory;
  final bool Function() _supported;
  LocalModelStatus _status = const LocalModelStatus(LocalModelState.unprepared);
  Future<bool>? _download;
  HttpClient? _activeClient;
  bool _disposed = false;

  LocalModelStatus get status => _status;
  bool get isSupported => _supported();

  Future<void> initialize() async {
    if (_disposed) return;
    if (!isSupported) {
      _set(const LocalModelStatus(LocalModelState.unsupported));
      return;
    }
    try {
      _set(const LocalModelStatus(LocalModelState.verifying));
      final model = await modelFile();
      if (_disposed) return;
      final previous = File('${model.path}.previous');
      if (model.existsSync() && await _isValid(model)) {
        if (previous.existsSync()) await previous.delete();
        _set(const LocalModelStatus(LocalModelState.ready));
      } else if (previous.existsSync() && await _isValid(previous)) {
        if (model.existsSync()) await model.delete();
        await previous.rename(model.path);
        _set(const LocalModelStatus(LocalModelState.ready));
      } else {
        if (model.existsSync()) {
          await model.delete();
        }
        if (previous.existsSync()) await previous.delete();
        _set(const LocalModelStatus(LocalModelState.unprepared));
      }
    } catch (error) {
      _set(LocalModelStatus(LocalModelState.failed, message: error.toString()));
    }
  }

  Future<File> modelFile() async {
    final directory = await _directoryProvider();
    return File('${directory.path}${Platform.pathSeparator}${spec.fileName}');
  }

  Future<bool> download() =>
      _download ??= _downloadModel().whenComplete(() => _download = null);

  Future<bool> _downloadModel() async {
    if (!isSupported) {
      _set(const LocalModelStatus(LocalModelState.unsupported));
      return false;
    }
    File? partial;
    try {
      final target = await modelFile();
      if (_disposed) return false;
      await target.parent.create(recursive: true);
      if (_disposed) return false;
      final previous = File('${target.path}.previous');
      if (target.existsSync() && await _isValid(target)) {
        if (previous.existsSync()) await previous.delete();
        _set(const LocalModelStatus(LocalModelState.ready));
        return true;
      }
      if (previous.existsSync() && await _isValid(previous)) {
        if (target.existsSync()) await target.delete();
        await previous.rename(target.path);
        _set(const LocalModelStatus(LocalModelState.ready));
        return true;
      }
      if (target.existsSync()) await target.delete();
      if (previous.existsSync()) await previous.delete();
      partial = File('${target.path}.part');
      if (partial.existsSync() && await _isValid(partial)) {
        await _promote(partial, target);
        _set(const LocalModelStatus(LocalModelState.ready));
        return true;
      }
      var offset = partial.existsSync() ? await partial.length() : 0;
      final client = _clientFactory();
      _activeClient = client;
      if (_disposed) {
        client.close(force: true);
        if (identical(_activeClient, client)) _activeClient = null;
        return false;
      }
      try {
        final request = await client.getUrl(spec.url);
        if (offset > 0) {
          request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
        }
        final response = await request.close();
        if (response.statusCode == HttpStatus.ok && offset > 0) {
          await partial.writeAsBytes(const <int>[]);
          offset = 0;
        } else if (response.statusCode == HttpStatus.partialContent) {
          final range = response.headers.value(HttpHeaders.contentRangeHeader);
          if (!_hasExpectedContentRange(range, offset)) {
            throw const HttpException('Invalid Content-Range');
          }
        } else if (response.statusCode != HttpStatus.ok) {
          throw HttpException('Model download failed: ${response.statusCode}');
        }
        final sink = partial.openWrite(
          mode: offset == 0 ? FileMode.write : FileMode.append,
        );
        var downloaded = offset;
        _set(
          LocalModelStatus(
            LocalModelState.downloading,
            downloadedBytes: downloaded,
          ),
        );
        try {
          await for (final chunk in response) {
            sink.add(chunk);
            downloaded += chunk.length;
            _set(
              LocalModelStatus(
                LocalModelState.downloading,
                downloadedBytes: downloaded,
              ),
            );
          }
        } finally {
          await sink.close();
        }
      } finally {
        client.close(force: true);
        if (identical(_activeClient, client)) _activeClient = null;
      }
      _set(const LocalModelStatus(LocalModelState.verifying));
      if (!await _isValid(partial)) {
        throw const FormatException('Model checksum mismatch');
      }
      await _promote(partial, target);
      _set(const LocalModelStatus(LocalModelState.ready));
      return true;
    } catch (error) {
      try {
        if (partial != null &&
            partial.existsSync() &&
            await partial.length() >= spec.sizeBytes) {
          await partial.delete();
        }
      } catch (_) {
        // Keep the original error as the actionable download failure.
      }
      _set(LocalModelStatus(LocalModelState.failed, message: error.toString()));
      return false;
    }
  }

  bool _hasExpectedContentRange(String? value, int offset) {
    if (value == null) return false;
    final match = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$').firstMatch(value);
    if (match == null) return false;
    final start = int.tryParse(match.group(1)!);
    final end = int.tryParse(match.group(2)!);
    final total = int.tryParse(match.group(3)!);
    if (start == null || end == null || total == null) return false;
    return start == offset &&
        end >= start &&
        total == spec.sizeBytes &&
        end < total;
  }

  void _set(LocalModelStatus value) {
    _status = value;
    if (!_disposed) notifyListeners();
  }

  Future<void> _promote(File partial, File target) async {
    File? backup;
    if (target.existsSync()) {
      backup = File('${target.path}.previous');
      if (backup.existsSync()) await backup.delete();
      await target.rename(backup.path);
    }
    try {
      await partial.rename(target.path);
      if (backup?.existsSync() ?? false) await backup!.delete();
    } catch (_) {
      final savedTarget = backup;
      if (savedTarget != null &&
          savedTarget.existsSync() &&
          !target.existsSync()) {
        await savedTarget.rename(target.path);
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _activeClient?.close(force: true);
    _activeClient = null;
    super.dispose();
  }

  Future<bool> _isValid(File file) async {
    if (await file.length() != spec.sizeBytes) return false;
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == spec.sha256;
  }

  static Future<Directory> _defaultDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}${Platform.pathSeparator}models');
  }

  static bool _defaultSupported() =>
      !kIsWeb && Platform.isAndroid && supportsLocalAIAbi(ffi.Abi.current());
}
