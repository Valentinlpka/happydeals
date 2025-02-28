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
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black87, size: 18),
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
                  'Proposer un échange',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Échangez vos objets avec la communauté',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                _buildExchangeCard(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExchangeCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _navigateToAdCreation(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.swap_horiz_outlined,
                    size: 32,
                    color: Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Créer une annonce d\'échange',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Proposez vos objets à échanger et découvrez ce que les autres membres peuvent vous offrir en retour.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      'Commencer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward,
                      size: 20,
                      color: Colors.grey[900],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToAdCreation(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AdCreationScreen(),
      ),
    );
  }
}
