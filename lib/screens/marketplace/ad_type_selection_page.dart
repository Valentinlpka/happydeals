import 'package:flutter/material.dart';
import 'package:happy/screens/marketplace/ad_creation_page.dart';

class AdTypeSelectionScreen extends StatelessWidget {
  const AdTypeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer une annonce'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choisissez le type d\'annonce',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildAdTypeCard(
                    context,
                    'Article à vendre',
                    'Créez une seule annonce pour un ou plusieurs articles à vendre.',
                    Icons.shopping_bag,
                    Colors.pink.shade100,
                    () => _navigateToAdCreation(context, 'article'),
                  ),
                  _buildAdTypeCard(
                    context,
                    'Véhicule à vendre',
                    'Vendez une voiture, un camion, ou un autre type de véhicule.',
                    Icons.directions_car,
                    Colors.green.shade100,
                    () => _navigateToAdCreation(context, 'vehicle'),
                  ),
                  _buildAdTypeCard(
                    context,
                    'Bien immobilier à vendre ou à louer',
                    'Passez une annonce pour une maison ou un appartement à vendre ou à louer.',
                    Icons.home,
                    Colors.orange.shade100,
                    () => _navigateToAdCreation(context, 'property'),
                  ),
                  _buildAdTypeCard(
                    context,
                    'Troc et Échange',
                    'Échangez des articles ou des services avec d\'autres utilisateurs.',
                    Icons.swap_horiz,
                    Colors.blue.shade100,
                    () => _navigateToAdCreation(context, 'exchange'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdTypeCard(BuildContext context, String title,
      String description, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: color,
                radius: 30,
                child: Icon(icon, size: 30, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToAdCreation(BuildContext context, String adType) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AdCreationScreen(adType: adType),
      ),
    );
  }
}
