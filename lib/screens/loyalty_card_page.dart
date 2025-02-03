import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/loyalty_card.dart';
import 'package:happy/classes/loyalty_program.dart';
import 'package:happy/widgets/custom_app_bar_back.dart';
import 'package:intl/intl.dart';

class LoyaltyCardsPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  LoyaltyCardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBarBack(
        title: 'Mes cartes de fidélité',
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('LoyaltyCards')
            .where('customerId', isEqualTo: userId)
            .where('status', isEqualTo: 'active')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Erreur: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Retour'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.card_giftcard_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Aucune carte de fidélité',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Faites des achats pour gagner des points !',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
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
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final companyData = snapshot.data!.data() as Map<String, dynamic>;
        final companyName = companyData['name'] as String;
        final companyLogo = companyData['logo'] as String;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Stack(
            children: [
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  onTap: () => _showLoyaltyCardDetails(context, card),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue[700]!,
                          Colors.blue[900]!,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CircleAvatar(
                              backgroundImage: NetworkImage(companyLogo),
                              radius: 24,
                              backgroundColor: Colors.white,
                            ),
                            Text(
                              companyName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildProgressBar(context, card),
                        const SizedBox(height: 16),
                        if (card.lastTransaction != null)
                          Text(
                            'Dernière utilisation: ${_formatDate(card.lastTransaction!.date)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (card.currentValue > 0)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${card.currentValue} points',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressBar(BuildContext context, LoyaltyCard card) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore
          .collection('LoyaltyPrograms')
          .doc(card.loyaltyProgramId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final program = LoyaltyProgram.fromFirestore(snapshot.data!);
        double progress = 0;
        String progressText = '';

        switch (program.type) {
          case LoyaltyProgramType.visits:
            progress = card.currentValue / program.targetValue;
            progressText =
                '${card.currentValue}/${program.targetValue} visites';
            break;
          case LoyaltyProgramType.amount:
            progress = card.currentValue / program.targetValue;
            progressText = '${card.currentValue}€/${program.targetValue}€';
            break;
          case LoyaltyProgramType.points:
            final nextTier = program.tiers?.entries
                .where((entry) => entry.key > card.currentValue)
                .reduce((a, b) => a.key < b.key ? a : b);
            if (nextTier != null) {
              progress = card.currentValue / nextTier.key;
              progressText = '${card.currentValue}/${nextTier.key} points';
            }
            break;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              progressText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              height: 50, child: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return Text("Erreur: ${snapshot.error}");
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const Text(
              'Codes promo disponibles:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...snapshot.data!.docs.map((doc) {
              final promoData = doc.data() as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          promoData['code'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          promoData['isPercentage']
                              ? '${promoData['value']}%'
                              : '${promoData['value']}€',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Expire le ${_formatDate((promoData['expiresAt'] as Timestamp).toDate())}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  void _showLoyaltyCardDetails(BuildContext context, LoyaltyCard card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    FutureBuilder<DocumentSnapshot>(
                      future: _firestore
                          .collection('LoyaltyPrograms')
                          .doc(card.loyaltyProgramId)
                          .get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final program =
                            LoyaltyProgram.fromFirestore(snapshot.data!);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // En-tête avec les informations principales
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _getProgramTypeIcon(program.type),
                                    color: Colors.blue[700],
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getProgramTypeString(program.type),
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Valeur actuelle: ${card.currentValue}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Barre de progression
                            _buildProgressBar(context, card),
                            const SizedBox(height: 24),

                            // Section des récompenses
                            const Text(
                              'Récompenses disponibles',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildRewardsInfo(program),
                            const SizedBox(height: 24),

                            // Historique des transactions
                            const Text(
                              'Dernières transactions',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildTransactionHistory(card),
                            const SizedBox(height: 24),

                            // Codes promo disponibles
                            _buildPromoCodesList(card.companyId),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRewardsInfo(LoyaltyProgram program) {
    switch (program.type) {
      case LoyaltyProgramType.visits:
      case LoyaltyProgramType.amount:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.card_giftcard, color: Colors.green[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Obtenez ${program.rewardValue}${program.isPercentage ? '%' : '€'} '
                  'après ${program.targetValue}${program.type == LoyaltyProgramType.visits ? ' visites' : '€'}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        );
      case LoyaltyProgramType.points:
        if (program.tiers == null) return const SizedBox.shrink();
        return Column(
          children: program.tiers!.entries.map((tier) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.stars, color: Colors.green[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${tier.value.reward}${tier.value.isPercentage ? '%' : '€'} '
                      'à ${tier.key} points',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
    }
  }

  IconData _getProgramTypeIcon(LoyaltyProgramType type) {
    switch (type) {
      case LoyaltyProgramType.visits:
        return Icons.local_activity;
      case LoyaltyProgramType.points:
        return Icons.stars;
      case LoyaltyProgramType.amount:
        return Icons.account_balance_wallet;
    }
  }

  Widget _buildTransactionHistory(LoyaltyCard card) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('LoyaltyHistory')
          .where('cardId', isEqualTo: card.id)
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          print(snapshot.error);
          return Text('Erreur: ${snapshot.error}');
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey),
                SizedBox(width: 12),
                Text(
                  'Aucune transaction récente',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: data['type'] == 'earn'
                          ? Colors.green[50]
                          : Colors.blue[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      data['type'] == 'earn'
                          ? Icons.add_circle_outline
                          : Icons.redeem,
                      color: data['type'] == 'earn'
                          ? Colors.green[700]
                          : Colors.blue[700],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['type'] == 'earn'
                              ? 'Points gagnés'
                              : 'Récompense utilisée',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _formatDate(
                              (data['timestamp'] as Timestamp).toDate()),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${data['type'] == 'earn' ? '+' : '-'}${data['amount']}',
                    style: TextStyle(
                      color: data['type'] == 'earn'
                          ? Colors.green[700]
                          : Colors.blue[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
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
