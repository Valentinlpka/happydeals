import 'package:flutter/material.dart';

class MotsClesEmploi extends StatelessWidget {
  final String text;

  const MotsClesEmploi(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xff3476B2),
              Color(0xff0B7FE9),
            ],
          )),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
