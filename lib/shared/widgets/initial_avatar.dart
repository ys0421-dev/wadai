import 'package:flutter/material.dart';

import '../../app/app_theme.dart';

class InitialAvatar extends StatelessWidget {
  const InitialAvatar({required this.displayName, this.radius = 22, super.key});

  final String displayName;
  final double radius;

  String get _initial {
    final name = displayName.trim();
    return name.isEmpty ? '?' : name.characters.first;
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CircleAvatar(
      radius: radius,
      backgroundColor: appSubtleColor,
      foregroundColor: brandColor,
      child: Text(
        _initial,
        style: TextStyle(fontSize: radius * .8, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
