import 'package:flutter/material.dart';

class CustomAppBarBack extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const CustomAppBarBack({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(
          color: Colors.grey[300],
          height: 1.0,
        ),
      ),
      title: Text(title,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.black, fontSize: 17, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
