import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final AlignmentGeometry align;

  const CustomAppBar(
      {super.key, required this.title, this.actions, required this.align});

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(50.0),
      child: Column(
        children: [
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
              child: AppBar(
                centerTitle: true,
                title: Align(
                  alignment: align,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                    ),
                  ),
                ),
                actions: actions,
              ),
            ),
          ),
          Container(
            height: 1,
            color: Colors.grey[300],
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize =>
      const Size.fromHeight(67.0); // Augmentez aussi cette valeur}
}
