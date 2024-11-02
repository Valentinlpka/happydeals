import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final Map<String, int> unreadCounts;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.unreadCounts,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return Container(
      height: isIOS ? 56 + bottomPadding : 56,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.pink, Colors.blue],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Accueil',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.search,
                  activeIcon: Icons.search,
                  label: 'Rechercher',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.favorite_outline,
                  activeIcon: Icons.favorite,
                  label: 'Likes',
                  index: 2,
                ),
                _buildMessageItem(
                  index: 3,
                  unreadCount: unreadCounts['total'] ?? 0,
                ),
                _buildNavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profil',
                  index: 4,
                ),
                _buildNavItem(
                  icon: Icons.shopping_bag_outlined,
                  activeIcon: Icons.shopping_bag,
                  label: 'Panier',
                  index: 5,
                ),
              ],
            ),
          ),
          if (isIOS) SizedBox(height: bottomPadding),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    IconData? activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = currentIndex == index;

    return InkWell(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 16.0 : 8.0,
            vertical: 8,
          ),
          decoration: isSelected
              ? BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? (activeIcon ?? icon) : icon,
                color: Colors.white,
                size: 24,
              ),
              if (isSelected) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem({
    required int index,
    required int unreadCount,
  }) {
    final isSelected = currentIndex == index;

    return InkWell(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 16.0 : 8.0,
            vertical: 8,
          ),
          decoration: isSelected
              ? BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                )
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              badges.Badge(
                position: badges.BadgePosition.topEnd(top: -4, end: -4),
                showBadge: unreadCount > 0,
                badgeStyle: const badges.BadgeStyle(
                  padding: EdgeInsets.all(4),
                  badgeColor: Colors.red,
                ),
                badgeContent: Text(
                  unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Icon(
                  isSelected ? Icons.message : Icons.message_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 4),
                const Text(
                  'Messages',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
