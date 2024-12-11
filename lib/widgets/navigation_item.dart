import 'package:flutter/material.dart';

class NavigationItem {
  final String title;
  final IconData icon;
  final Widget page;

  NavigationItem({
    required this.title,
    required this.icon,
    required this.page,
  });
}
