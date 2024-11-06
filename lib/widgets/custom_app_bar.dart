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
      preferredSize: const Size.fromHeight(1.0),
      child: Column(
        children: [
          SafeArea(
            child: Container(
              child: AppBar(
                titleSpacing: 0,
                centerTitle:
                    align == Alignment.center, // Condition sur l'alignement

                title: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
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
