import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ButtonCategories extends StatefulWidget {
  final String name;
  final IconData icon;

  const ButtonCategories(this.icon, this.name, {super.key});

  @override
  State<ButtonCategories> createState() => _ButtonCategoriesState();
}

class _ButtonCategoriesState extends State<ButtonCategories> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 15),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
            width: 0, color: const Color.fromARGB(138, 158, 158, 158)),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            spreadRadius: 0,
            blurRadius: 1,
            offset: const Offset(0, 1), // changes position of shadow
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(widget.icon),
          const Gap(6),
          Text(widget.name),
        ],
      ),
    );
  }
}
