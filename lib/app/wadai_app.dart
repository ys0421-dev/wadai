import 'package:flutter/material.dart';

import '../state/wadee_controller.dart';
import 'app_shell.dart';
import 'app_theme.dart';

class WadaiApp extends StatefulWidget {
  const WadaiApp({this.store, super.key});

  final WadeeController? store;

  @override
  State<WadaiApp> createState() => _WadaiAppState();
}

class _WadaiAppState extends State<WadaiApp> {
  late final WadeeController _store;
  late final bool _ownsStore;

  @override
  void initState() {
    super.initState();
    _ownsStore = widget.store == null;
    _store = widget.store ?? WadeeController();
    _store.load();
  }

  @override
  void dispose() {
    if (_ownsStore) _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WADEE',
      theme: appTheme,
      home: AnimatedBuilder(
        animation: _store,
        builder: (context, _) {
          switch (_store.loadState) {
            case AppLoadState.ready:
              return AppShell(store: _store);
            case AppLoadState.error:
              return _LoadErrorScreen(onRetry: _store.load);
            case AppLoadState.initial:
            case AppLoadState.loading:
              return const _LoadingScreen();
          }
        },
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('読み込み中...'),
        ],
      ),
    ),
  );
}

class _LoadErrorScreen extends StatelessWidget {
  const _LoadErrorScreen({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              liveRegion: true,
              container: true,
              label: 'データを読み込めませんでした。再試行できます。',
              child: Icon(Icons.error_outline, size: 42),
            ),
            const SizedBox(height: 16),
            const Text('保存データを読み込めませんでした。'),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('再試行')),
          ],
        ),
      ),
    ),
  );
}
