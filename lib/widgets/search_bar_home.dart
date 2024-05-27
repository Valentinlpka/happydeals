import 'package:flutter/material.dart';

class SearchBarHome extends StatelessWidget {
  const SearchBarHome({super.key});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xff999999);
    return Container(
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
      width: 250,
      child: const TextField(
        style: TextStyle(fontSize: 14),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.only(),
          prefixIcon: Icon(Icons.search, color: color),
          labelText: 'Rechercher',
          labelStyle: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: color),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
