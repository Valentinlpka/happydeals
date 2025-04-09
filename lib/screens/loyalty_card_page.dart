import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/loyalty_card.dart';
import 'package:happy/classes/loyalty_program.dart';
import 'package:happy/widgets/app_bar/custom_app_bar.dart';
import 'package:intl/intl.dart';

class LoyaltyCardsPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  LoyaltyCardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const CustomAppBar(
          title: 'Mes cartes de fidélité',
          align: Alignment.center,
          bottom: TabBar(
            tabs: [
              Tab(text: 'Cartes actives'),
              Tab(text: 'Historique'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildActiveCards(),
            _buildHistoryCards(),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('LoyaltyCards')
          .where('customerId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
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
                  'Aucune carte active',
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
    );
  }

  Widget _buildHistoryCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('LoyaltyCards')
          .where('customerId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          print(snapshot.error);
          return const Center(
            child: Text('Aucun historique disponible'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final loyaltyCard =
                LoyaltyCard.fromFirestore(snapshot.data!.docs[index]);
            return _buildHistoryCardItem(context, loyaltyCard);
          },
        );
      },
    );
  }

  Widget _buildHistoryCardItem(BuildContext context, LoyaltyCard card) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('companys').doc(card.companyId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final companyData = snapshot.data!.data() as Map<String, dynamic>;
        final companyName = companyData['name'] as String;
        final companyLogo = companyData['logo'] as String;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(companyLogo),
              backgroundColor: Colors.white,
            ),
            title: Text(companyName),
            subtitle: Text(
              'Terminée le ${_formatDate(card.lastUsed ?? card.createdAt)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHistoryTransactions(card),
                    _buildPromoCodesList(card.companyId, card.id),
                    _buildHistoryPromoCodes(card.companyId, card.id),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTransactions(LoyaltyCard card) {
    print('Recherche historique pour la carte: ${card.id}'); // Debug

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('LoyaltyHistory')
          .orderBy('timestamp', descending: true)
          .where('customerId', isEqualTo: userId)
          .where('companyId', isEqualTo: card.companyId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Erreur: ${snapshot.error}');
          return const Text('Une erreur est survenue');
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          print('Pas de données ou données vides');
          return const SizedBox.shrink();
        }

        // Filtrer les documents qui contiennent cette carte dans leurs détails
        final relevantDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final details = data['details'] as List?;
          return details?.any((detail) => detail['cardId'] == card.id) ?? false;
        }).toList();

        if (relevantDocs.isEmpty) {
          print('Aucune transaction trouvée pour la carte ${card.id}');
          return const SizedBox.shrink();
        }

        print('Nombre de transactions trouvées: ${relevantDocs.length}');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Historique des transactions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...relevantDocs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final details = (data['details'] as List).firstWhere(
                (detail) => detail['cardId'] == card.id,
                orElse: () => null,
              );

              if (details == null) return const SizedBox.shrink();

              final amount = details['amount'] as num;
              final detailType = details['type'] as String;

              return ListTile(
                dense: true,
                leading: const Icon(
                  Icons.add_circle,
                  color: Colors.green,
                ),
                title: Text(
                  detailType == 'complete_card'
                      ? 'Carte complétée'
                      : 'Points gagnés',
                ),
                subtitle: Text(
                  _formatDate((data['timestamp'] as Timestamp).toDate()),
                ),
                trailing: Text(
                  '+$amount',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildHistoryPromoCodes(String companyId, String loyaltyCardId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('promo_codes')
          .where('customerId', isEqualTo: userId)
          .where('companyId', isEqualTo: companyId)
          .where('loyaltyCardId', isEqualTo: loyaltyCardId)
          .where('usageHistory', isNotEqualTo: []).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              height: 50, child: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData ||
            snapshot.data!.docs.isEmpty ||
            snapshot.hasError) {
          print(snapshot.error);
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const Text(
              'Codes promo utilisés',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...snapshot.data!.docs.map((doc) {
              final promoData = doc.data() as Map<String, dynamic>;
              final usageHistory = promoData['usageHistory'] as List?;
              final lastUsage = usageHistory?.isNotEmpty == true
                  ? (usageHistory!.last['date'] as Timestamp).toDate()
                  : null;

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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              promoData['code'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              promoData['discountType'] == 'amount'
                                  ? '-${promoData['discountValue']}€'
                                  : '-${promoData['discountValue']}%',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        if (lastUsage != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Utilisé le',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(lastUsage),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (promoData['description']?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 8),
                      Text(
                        promoData['description'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                    if (promoData['applicableTo'] != 'all') ...[
                      const SizedBox(height: 4),
                      Text(
                        _getApplicableToText(promoData['applicableTo']),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildLoyaltyCardItem(BuildContext context, LoyaltyCard card) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('companys').doc(card.companyId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final companyData = snapshot.data!.data() as Map<String, dynamic>;
        final companyName = companyData['name'] as String;
        final companyLogo = companyData['logo'] as String;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(companyLogo),
              backgroundColor: Colors.white,
            ),
            title: Text(companyName),
            subtitle: Text(
              'Valeur actuelle: ${card.currentValue.toStringAsFixed(0)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Barre de progression
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _buildProgressBar(context, card),
                    ),
                    const SizedBox(height: 16),

                    // Historique des transactions
                    _buildHistoryTransactions(card),
                  ],
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
        String rewardText = '';

        switch (program.type) {
          case LoyaltyProgramType.visits:
            progress = card.currentValue / program.targetValue;
            progressText =
                '${card.currentValue.toInt()}/${program.targetValue.toInt()} visites';
            rewardText =
                '${program.rewardValue}${program.isPercentage ? '%' : '€'} de réduction';
            break;
          case LoyaltyProgramType.amount:
            progress = card.currentValue / program.targetValue;
            progressText =
                '${card.currentValue.toInt()}€/${program.targetValue.toInt()}€';
            rewardText =
                '${program.rewardValue}${program.isPercentage ? '%' : '€'} de réduction';
            break;
          case LoyaltyProgramType.points:
            final nextTier = program.tiers?.entries
                .where((entry) => entry.key > card.currentValue)
                .reduce((a, b) => a.key < b.key ? a : b);
            if (nextTier != null) {
              progress = card.currentValue / nextTier.key;
              progressText =
                  '${card.currentValue.toInt()}/${nextTier.key.toInt()} points';
              rewardText =
                  '${nextTier.value.reward}${nextTier.value.isPercentage ? '%' : '€'} de réduction';
            }
            break;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  progressText,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  rewardText,
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                backgroundColor: Colors.white,
                valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor),
                minHeight: 8,
              ),
            ),
          ],
        );
      },
    );
  }

  int _calculateLevel(double points) {
    if (points < 100) return 1;
    if (points < 500) return 2;
    if (points < 1000) return 3;
    if (points < 2000) return 4;
    return 5;
  }

  Widget _buildPromoCodesList(String companyId, String loyaltyCardId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('promo_codes')
          .where('customerId', isEqualTo: userId)
          .where('companyId', isEqualTo: companyId)
          .where('loyaltyCardId', isEqualTo: loyaltyCardId)
          .where('isActive', isEqualTo: true)
          .where('usageHistory', isEqualTo: [])
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              height: 50, child: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          print(snapshot.error);
          return Text("Erreur: ${snapshot.error}");
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          print("Aucun code promo disponible");
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const Text(
              'Codes promo valides:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...snapshot.data!.docs.map((doc) {
              final promoData = doc.data() as Map<String, dynamic>;
              final currentUses = promoData['currentUses'] ?? 0;
              final maxUses = int.tryParse(promoData['maxUses'] ?? '1') ?? 1;
              final remainingUses = maxUses - currentUses;

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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              promoData['code'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              promoData['discountType'] == 'amount'
                                  ? '-${promoData['discountValue']}€'
                                  : '-${promoData['discountValue']}%',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Utilisations restantes: $remainingUses',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Expire le ${_formatDate((promoData['expiresAt'] as Timestamp).toDate())}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (promoData['description']?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 8),
                      Text(
                        promoData['description'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                    if (promoData['conditionType'] != 'none') ...[
                      const SizedBox(height: 8),
                      Text(
                        _getConditionText(promoData),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                    if (promoData['applicableTo'] != 'all') ...[
                      const SizedBox(height: 4),
                      Text(
                        _getApplicableToText(promoData['applicableTo']),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  String _getConditionText(Map<String, dynamic> promoData) {
    switch (promoData['conditionType']) {
      case 'minimum_amount':
        return 'Minimum d\'achat: ${promoData['conditionValue']}€';
      case 'minimum_quantity':
        return 'Minimum de quantité: ${promoData['conditionValue']}';
      case 'specific_product':
        return 'Applicable sur un produit spécifique';
      default:
        return '';
    }
  }

  String _getApplicableToText(String applicableTo) {
    switch (applicableTo) {
      case 'services':
        return 'Applicable uniquement sur les services';
      case 'products':
        return 'Applicable uniquement sur les produits';
      case 'deal_express':
        return 'Applicable uniquement sur les deals express';
      default:
        return 'Applicable sur tout';
    }
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
                            _buildPromoCodesList(card.companyId, card.id),
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
            final amount = data['amount'];
            final amountStr = amount is num ? amount.toString() : '0';

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
                    '${data['type'] == 'earn' ? '+' : '-'}$amountStr',
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

  Widget _buildDetailRow(String label, dynamic value) {
    // Convertir la valeur en String de manière sûre
    String displayValue = '';
    if (value is num) {
      displayValue = value.toStringAsFixed(0);
    } else if (value is String) {
      displayValue = value;
    } else {
      displayValue = value?.toString() ?? '';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(
            displayValue,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
