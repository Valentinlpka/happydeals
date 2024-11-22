import 'package:flutter/material.dart';

class FilterButtons extends StatelessWidget {
  final String selectedFilter;
  final Function(String) onFilterChanged;

  const FilterButtons({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          _buildFilterButton('Tous', Icons.home),
          _buildFilterButton('Deals Express', Icons.flash_on),
          _buildFilterButton('Happy Deals', Icons.card_giftcard),
          _buildFilterButton('Offres d\'emploi', Icons.work),
          _buildFilterButton('Parrainage', Icons.people),
          _buildFilterButton('Jeux concours', Icons.emoji_events),
          _buildFilterButton('Produits', Icons.shopping_bag_outlined),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String title, IconData icon) {
    final isSelected = selectedFilter == title;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        child: ElevatedButton.icon(
          icon: Icon(
            icon,
            color: isSelected ? Colors.white : Colors.black87,
            size: 20,
          ),
          label: Text(title),
          onPressed: () => onFilterChanged(title),
          style: ElevatedButton.styleFrom(
            foregroundColor: isSelected ? Colors.white : Colors.black87,
            backgroundColor: isSelected ? Colors.blue[600] : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: isSelected ? 4 : 1,
          ),
        ),
      ),
    );
  }
}
