import 'package:flutter/material.dart';

import 'app_theme.dart';
import '../features/people/people_screen.dart';
import '../features/topics/topics_screen.dart';
import '../state/wadee_controller.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.store, super.key});
  final WadeeController store;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _selectedIndex,
      children: [
        PeopleScreen(store: widget.store),
        TopicsScreen(store: widget.store),
      ],
    ),
    bottomNavigationBar: DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: appOutlineColor)),
      ),
      child: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: '相手',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: '話題',
          ),
        ],
      ),
    ),
  );
}
