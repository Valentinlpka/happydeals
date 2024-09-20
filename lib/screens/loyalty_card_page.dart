import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/loyalty_card.dart';
import 'package:happy/classes/loyalty_program.dart';

class LoyaltyCardsPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  LoyaltyCardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes cartes de fidélité'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('LoyaltyCards')
            .where('customerId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text('Aucune carte de fidélité trouvée.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final loyaltyCard =
                  LoyaltyCard.fromFirestore(snapshot.data!.docs[index]);
              return _buildLoyaltyCardItem(context, loyaltyCard);
            },
          );
        },
      ),
    );
  }

  Widget _buildLoyaltyCardItem(BuildContext context, LoyaltyCard card) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('companys').doc(card.companyId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final companyData = snapshot.data!.data() as Map<String, dynamic>;
        final companyName = companyData['name'] as String;
        final companyLogo = companyData['logo'] as String;

        return Card(
          margin: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () => _showLoyaltyCardDetails(context, card),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage:
                            CachedNetworkImageProvider(companyLogo),
                        radius: 24,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          companyName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Valeur actuelle: ${card.currentValue}'),
                  const SizedBox(height: 8),
                  _buildPromoCodesList(card.companyId),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPromoCodesList(String companyId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('PromoCodes')
          .where('customerId', isEqualTo: userId)
          .where('companyId', isEqualTo: companyId)
          .where('usedAt', isNull: true)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Codes promo disponibles:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...snapshot.data!.docs.map((doc) {
              final promoData = doc.data() as Map<String, dynamic>;
              return Text(
                  '${promoData['code']} - ${promoData['value']}${promoData['isPercentage'] ? '%' : '€'}');
            }),
          ],
        );
      },
    );
  }

  void _showLoyaltyCardDetails(BuildContext context, LoyaltyCard card) {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<DocumentSnapshot>(
        future: _firestore
            .collection('LoyaltyPrograms')
            .doc(card.loyaltyProgramId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const AlertDialog(
              content: CircularProgressIndicator(),
            );
          }

          final program = LoyaltyProgram.fromFirestore(snapshot.data!);

          return AlertDialog(
            title: const Text('Détails de la carte de fidélité'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Type de programme: ${_getProgramTypeString(program.type)}'),
                const SizedBox(height: 8),
                Text('Valeur actuelle: ${card.currentValue}'),
                const SizedBox(height: 8),
                Text('Objectif: ${program.targetValue}'),
                const SizedBox(height: 8),
                Text(
                    'Récompense: ${program.rewardValue}${program.isPercentage ? '%' : '€'}'),
                if (program.type == LoyaltyProgramType.points &&
                    program.tiers != null) ...[
                  const SizedBox(height: 8),
                  const Text('Paliers:'),
                  ...program.tiers!.entries.map((entry) => Text(
                      '${entry.key} points: ${entry.value}${program.isPercentage ? '%' : '€'}')),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getProgramTypeString(LoyaltyProgramType type) {
    switch (type) {
      case LoyaltyProgramType.visits:
        return 'Carte de passage';
      case LoyaltyProgramType.points:
        return 'Carte à points';
      case LoyaltyProgramType.amount:
        return 'Carte à montant';
    }
  }
}
