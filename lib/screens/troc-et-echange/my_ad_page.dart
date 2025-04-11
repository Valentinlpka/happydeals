import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/screens/troc-et-echange/ad_card.dart';
import 'package:happy/screens/troc-et-echange/ad_creation_page.dart';
import 'package:happy/screens/troc-et-echange/ad_detail_page.dart';
import 'package:happy/widgets/app_bar/custom_app_bar_back.dart';

class MyAdsPage extends StatelessWidget {
  const MyAdsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(
            child: Text('Vous devez être connecté pour voir vos annonces')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: const CustomAppBarBack(title: 'Mes annonces'),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ads')
            .where('userId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.swap_horiz_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Vous n\'avez pas encore d\'annonces d\'échange',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _navigateToAdCreation(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[900],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Créer une annonce',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.55,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            padding: const EdgeInsets.all(10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              DocumentSnapshot doc = snapshot.data!.docs[index];
              return FutureBuilder<Ad>(
                future: Ad.fromFirestore(doc),
                builder: (context, adSnapshot) {
                  if (adSnapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                        child: Center(child: CircularProgressIndicator()));
                  }
                  if (adSnapshot.hasError || !adSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }
                  final ad = adSnapshot.data!;
                  return AdCard(
                    ad: ad,
                    onTap: () => _showAdOptions(context, ad),
                    onSaveTap: () {},
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAdCreation(context),
        backgroundColor: Colors.grey[900],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _navigateToAdCreation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdCreationScreen()),
    );
  }

  void _showAdOptions(BuildContext context, Ad ad) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('Voir l\'annonce'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => AdDetailPage(ad: ad)),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Modifier l\'annonce'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdCreationScreen(existingAd: ad),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Supprimer l\'annonce'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(context, ad);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, Ad ad) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content:
              const Text('Êtes-vous sûr de vouloir supprimer cette annonce ?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Supprimer'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAd(context, ad);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAd(BuildContext context, Ad ad) async {
    try {
      // Supprimer les images de Firebase Storage
      for (String photoUrl in ad.photos) {
        await FirebaseStorage.instance.refFromURL(photoUrl).delete();
      }

      // Supprimer l'annonce de Firestore
      await FirebaseFirestore.instance.collection('ads').doc(ad.id).delete();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Annonce supprimée avec succès')),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la suppression: $e')),
      );
    }
  }
}
