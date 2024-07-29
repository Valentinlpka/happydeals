import 'package:flutter/material.dart';
import 'package:happy/screens/profile_page.dart';
import 'package:happy/screens/reservation_list_deal_express.dart';
import 'package:happy/screens/shop/user_order_page.dart';
import 'package:happy/services/auth_service.dart';

class ParametrePage extends StatelessWidget {
  const ParametrePage({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Paramètre'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Mes services',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildServiceItem(
                  context, 'Mes achats', 'assets/images/mes_achats.png', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const UserOrdersPages()),
                );
                // Navigation vers l'écran Mes achats
              }),
              _buildServiceItem(context, 'Mes réservations',
                  'assets/images/mes_reservations.png', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ReservationListDealExpress()),
                );
                // Navigation vers l'écran Mes réservations
              }),
              _buildServiceItem(
                  context, 'Ma brocante', 'assets/images/ma_brocante.png', () {
                // Navigation vers l'écran Ma brocante
              }),
              _buildServiceItem(
                  context, 'Mon profil', 'assets/images/mon_profil.png', () {
                // Navigation vers l'écran Mon profil
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              }),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Tous nos services',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildServiceItem(
                  context, 'Parrainage', 'assets/images/happy_deals.png', () {
                // Navigation vers l'écran Parrainage
              }),
              _buildServiceItem(
                  context, 'Happy Deals', 'assets/images/happy_deals.png', () {
                // Navigation vers l'écran Happy Deals
              }),
              _buildServiceItem(
                  context, 'Deals Express', 'assets/images/happy_deals.png',
                  () {
                // Navigation vers l'écran Deals Express
              }),
              _buildServiceItem(
                  context, 'Jeux concours', 'assets/images/happy_deals.png',
                  () {
                // Navigation vers l'écran Jeux concours
              }),
              _buildServiceItem(
                  context, 'Offres d\'emploi', 'assets/images/happy_deals.png',
                  () {
                // Navigation vers l'écran Offres d'emploi
              }),
              _buildServiceItem(
                  context, 'Évènements', 'assets/images/happy_deals.png', () {
                // Navigation vers l'écran Évènements
              }),
            ],
          ),
          const SizedBox(height: 24),
          _buildSettingsItem(context, 'Paramètres', Icons.settings, () {
            // Navigation vers l'écran Paramètres
          }),
          _buildSettingsItem(context, 'Se déconnecter', Icons.logout, () {
            authService.signOut(context);
            // Logique de déconnexion
          }, color: Colors.red),
        ],
      ),
    );
  }

  Widget _buildServiceItem(BuildContext context, String title, String imagePath,
      VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, height: 60),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem(
      BuildContext context, String title, IconData icon, VoidCallback onTap,
      {Color color = Colors.black}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }
}
