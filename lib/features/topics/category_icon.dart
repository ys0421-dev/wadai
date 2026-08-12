import 'package:flutter/material.dart';

IconData categoryIcon(String categoryId) {
  switch (categoryId) {
    case 'hobby':
      return Icons.palette_outlined;
    case 'travel':
      return Icons.flight_takeoff;
    case 'food':
      return Icons.restaurant_outlined;
    case 'entertainment':
      return Icons.movie_outlined;
    case 'work':
      return Icons.work_outline;
    case 'daily':
      return Icons.wb_sunny_outlined;
    case 'sports':
      return Icons.sports_tennis_outlined;
    case 'learning':
      return Icons.menu_book_outlined;
    default:
      return Icons.more_horiz;
  }
}
