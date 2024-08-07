import 'package:flutter/material.dart';

Widget buildAverageRating(averageRating) {
  return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
          5,
          (index) => Icon(
              size: 15,
              index < averageRating.round() ? Icons.star : Icons.star_border,
              color: Colors.amber)));
}
