import 'package:flutter/material.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/followed_companies_page.dart';
import 'package:happy/screens/liked_post_page.dart';
import 'package:happy/screens/settings_page.dart';
import 'package:happy/services/auth_service.dart';
import 'package:provider/provider.dart';

void showProfileBottomSheet(BuildContext context) {
  final authService = AuthService(); // Instanciation de AuthService

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // User Profile Header
          Consumer<UserModel>(
            builder: (context, userProvider, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF3476B2), Color(0xFF0B7FE9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(
                          2), // Épaisseur du bord en dégradé
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors
                              .white, // Fond blanc entre le bord et l'image
                        ),
                        child: CircleAvatar(
                          radius: 25,
                          backgroundImage:
                              NetworkImage(userProvider.profileUrl),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${userProvider.firstName} ${userProvider.lastName}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userProvider.uniqueCode,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // Menu Options
          _buildMenuOption(
            icon: Icons.person_outline,
            label: 'Voir mon profil',
            onTap: () {
              // Navigation vers le profil
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ParametrePage()));
            },
            context: context,
          ),
          _buildMenuOption(
            context: context,
            icon: Icons.favorite_border,
            label: 'Posts likés',
            onTap: () {
              Navigator.pop(context);

              // Navigation vers les posts likés
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const LikedPostsPage()));
            },
          ),
          _buildMenuOption(
            context: context,
            icon: Icons.business,
            label: 'Entreprises suivies',
            onTap: () {
              // Navigation vers les posts likés
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const FollowedCompaniesPage()));

              // Navigation vers les entreprises suivies
            },
          ),
          _buildMenuOption(
            context: context,
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            hasNotification: true,
            onTap: () {
              // Navigation vers les notifications
            },
          ),

          const SizedBox(height: 8),
          // Logout Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[50],
                foregroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => authService.signOut(context),

              // Logique de déconnexio
              child: const Text(
                'Déconnexion',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          // Add extra padding for bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    ),
  );
}

Widget _buildMenuOption({
  required BuildContext context,
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  int? count,
  bool hasNotification = false,
}) {
  return InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue[600]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (count != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (hasNotification)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    ),
  );
}
