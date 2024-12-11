import 'package:flutter/material.dart';
import 'package:happy/screens/marketplace/ad_creation_page.dart';

class AdTypeSelectionScreen extends StatelessWidget {
  const AdTypeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Que souhaitez-vous',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                ),
                Text(
                  "vendre aujourd'hui ?",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                ),
                const SizedBox(height: 32),
                _buildAdTypeCard(
                  context,
                  'Article à vendre',
                  'Parfait pour vendre vos objets, vêtements, électronique...',
                  Icons.shopping_bag_outlined,
                  const Color(0xFF4B88DA),
                  () => _navigateToAdCreation(context, 'article'),
                ),
                const SizedBox(height: 16),
                _buildAdTypeCard(
                  context,
                  'Véhicule',
                  'Vendez votre voiture, moto, vélo ou tout autre véhicule',
                  Icons.directions_car_outlined,
                  const Color(0xFF50C878),
                  () => _navigateToAdCreation(context, 'vehicle'),
                ),
                const SizedBox(height: 16),
                _buildAdTypeCard(
                  context,
                  'Troc et Échange',
                  "Échangez vos biens contre d'autres articles qui vous intéressent",
                  Icons.swap_horiz_outlined,
                  const Color(0xFFFFA500),
                  () => _navigateToAdCreation(context, 'exchange'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdTypeCard(BuildContext context, String title,
      String description, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: color,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
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
