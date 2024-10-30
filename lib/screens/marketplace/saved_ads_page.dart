import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/screens/marketplace/ad_card.dart';
import 'package:happy/screens/marketplace/ad_detail_page.dart';
import 'package:happy/widgets/custom_app_bar_back.dart';

class SavedAdsPage extends StatefulWidget {
  const SavedAdsPage({super.key});

  @override
  _SavedAdsPageState createState() => _SavedAdsPageState();
}

class _SavedAdsPageState extends State<SavedAdsPage> {
  final List<Ad> _savedAds = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedAds();
  }

  Future<void> _loadSavedAds() async {
    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final savedAdIds = List<String>.from(userDoc.data()?['savedAds'] ?? []);

      final adDocs = await Future.wait(savedAdIds.map(
          (id) => FirebaseFirestore.instance.collection('ads').doc(id).get()));

      final savedAds = await Future.wait(adDocs
          .where((doc) => doc.exists)
          .map((doc) => Ad.fromFirestore(doc)));

      setState(() {
        _savedAds.clear();
        _savedAds.addAll(savedAds);
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des annonces sauvegardées: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSaveAd(Ad ad) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Vous devez être connecté pour gérer vos annonces sauvegardées')),
      );
      return;
    }

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        List<String> savedAds =
            List<String>.from(userDoc.data()?['savedAds'] ?? []);

        savedAds.remove(ad.id);

        transaction.update(userRef, {'savedAds': savedAds});
      });

      setState(() {
        _savedAds.removeWhere((savedAd) => savedAd.id == ad.id);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBarBack(
        title: 'Annonces sauvegardées',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedAds.isEmpty
              ? const Center(child: Text('Aucune annonce sauvegardée'))
              : RefreshIndicator(
                  onRefresh: _loadSavedAds,
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    padding: const EdgeInsets.all(10),
                    itemCount: _savedAds.length,
                    itemBuilder: (context, index) {
                      return AdCard(
                        ad: _savedAds[index],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AdDetailPage(ad: _savedAds[index]),
                          ),
                        ),
                        onSaveTap: () => _toggleSaveAd(_savedAds[index]),
                      );
                    },
                  ),
                ),
    );
  }
}
