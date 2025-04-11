import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/widgets/app_bar/custom_app_bar_back.dart';
import 'package:intl/intl.dart';

class LoyaltyPointsPage extends StatelessWidget {
  const LoyaltyPointsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: const CustomAppBarBack(title: 'Cagnotte Up!'),
      body: StreamBuilder<LoyaltyData>(
        stream: _getLoyaltyData(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          final loyaltyData = snapshot.data ?? LoyaltyData.empty();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildPointsSummary(context, loyaltyData),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildRewardsSection(context, loyaltyData),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Mes codes promo disponibles',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: _buildPromoCodesList(loyaltyData.promoCodes),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Historique des points',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: _buildPointsHistory(loyaltyData.history),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPointsSummary(BuildContext context, LoyaltyData data) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withAlpha(204),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black..withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Mes points Up!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${data.currentPoints}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _getProgressToNextReward(data.currentPoints),
            backgroundColor: Colors.white.withAlpha(76),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            _getNextRewardText(data.currentPoints),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsSection(BuildContext context, LoyaltyData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Récompenses disponibles',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.8,
          children: [
            _buildRewardCard(
              context,
              points: 100,
              amount: 1,
              cashback: '1%',
              isEnabled: data.currentPoints >= 100,
              onClaim: () => _claimReward(context, 100, 1),
            ),
            _buildRewardCard(
              context,
              points: 300,
              amount: 6,
              cashback: '2%',
              isEnabled: data.currentPoints >= 300,
              onClaim: () => _claimReward(context, 300, 6),
            ),
            _buildRewardCard(
              context,
              points: 500,
              amount: 12.50,
              cashback: '2.5%',
              isEnabled: data.currentPoints >= 500,
              onClaim: () => _claimReward(context, 500, 12.50),
            ),
            _buildRewardCard(
              context,
              points: 700,
              amount: 21,
              cashback: '3%',
              isEnabled: data.currentPoints >= 700,
              onClaim: () => _claimReward(context, 700, 21),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRewardCard(
    BuildContext context, {
    required int points,
    required double amount,
    required String cashback,
    required bool isEnabled,
    required VoidCallback onClaim,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black..withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onClaim : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$points pts',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isEnabled
                        ? Theme.of(context).primaryColor
                        : Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${amount.toStringAsFixed(2)}€',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isEnabled ? Colors.black87 : Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cashback $cashback',
                  style: TextStyle(
                    fontSize: 14,
                    color: isEnabled ? Colors.grey[600] : Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 12),
                if (isEnabled)
                  ElevatedButton(
                    onPressed: onClaim,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Obtenir'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ... Suite dans le prochain message pour respecter la limite de caractères ...
}

class LoyaltyData {
  final int currentPoints;
  final double totalSavings;
  final double monthSavings;
  final double averageSavings;
  final List<PromoCode> promoCodes;
  final List<PointsHistory> history;

  const LoyaltyData({
    required this.currentPoints,
    required this.totalSavings,
    required this.monthSavings,
    required this.averageSavings,
    required this.promoCodes,
    required this.history,
  });

  factory LoyaltyData.empty() {
    return const LoyaltyData(
      currentPoints: 0,
      totalSavings: 0,
      monthSavings: 0,
      averageSavings: 0,
      promoCodes: [],
      history: [],
    );
  }
}

class PromoCode {
  final String code;
  final double amount;
  final DateTime expiryDate;
  final bool isUsed;

  const PromoCode({
    required this.code,
    required this.amount,
    required this.expiryDate,
    this.isUsed = false,
  });
}

class PointsHistory {
  final String type;
  final DateTime date;
  final int points;
  final double amount;
  final String referenceId;
  final String status;

  const PointsHistory({
    required this.type,
    required this.date,
    required this.points,
    required this.amount,
    required this.referenceId,
    required this.status,
  });
}

extension LoyaltyPointsPageMethods on LoyaltyPointsPage {
  Stream<LoyaltyData> _getLoyaltyData(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((userDoc) async {
      if (!userDoc.exists) {
        return LoyaltyData.empty();
      }

      final data = userDoc.data()!;
      final points = data['loyaltyPoints'] ?? 0;

      // Récupérer l'historique des points
      final historyQuery = await FirebaseFirestore.instance
          .collection('pointsHistory')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .get();

      final history = historyQuery.docs.map((doc) {
        final data = doc.data();
        return PointsHistory(
          type: data['type'],
          date: (data['date'] as Timestamp).toDate(),
          points: data['points'],
          amount: (data['amount'] as num).toDouble(),
          referenceId: data['referenceId'],
          status: data['status'],
        );
      }).toList();

      // Calculer les statistiques
      double totalEarned = 0;
      double monthEarned = 0;
      final now = DateTime.now();

      for (var item in history) {
        totalEarned += item.amount;
        if (item.date.month == now.month && item.date.year == now.year) {
          monthEarned += item.amount;
        }
      }

      // Récupérer les codes promo
      final promoCodesQuery = await FirebaseFirestore.instance
          .collection('promo_codes')
          .where('customerId', isEqualTo: userId)
          .where('companyId', isEqualTo: 'UP')
          .get();

      final promoCodes = promoCodesQuery.docs.map((doc) {
        final data = doc.data();
        return PromoCode(
          code: data['code'],
          amount: (data['discountValue'] as num).toDouble(),
          expiryDate: (data['expiresAt'] as Timestamp).toDate(),
          isUsed: data['currentUses'] > 0,
        );
      }).toList();

      return LoyaltyData(
        currentPoints: points,
        monthSavings: monthEarned,
        totalSavings: totalEarned,
        averageSavings: history.isEmpty ? 0 : totalEarned / history.length,
        promoCodes: promoCodes,
        history: history,
      );
    });
  }

  double _getProgressToNextReward(int currentPoints) {
    if (currentPoints >= 700) return 1.0;
    if (currentPoints >= 500) return (currentPoints - 500) / 200;
    if (currentPoints >= 300) return (currentPoints - 300) / 200;
    if (currentPoints >= 100) return (currentPoints - 100) / 200;
    return currentPoints / 100;
  }

  String _getNextRewardText(int currentPoints) {
    if (currentPoints >= 700) return 'Niveau maximum atteint !';
    if (currentPoints >= 500) return '${700 - currentPoints} points pour 21€';
    if (currentPoints >= 300) {
      return '${500 - currentPoints} points pour 12,50€';
    }
    if (currentPoints >= 100) return '${300 - currentPoints} points pour 6€';
    return '${100 - currentPoints} points pour 1€';
  }

  Widget _buildPromoCodesList(List<PromoCode> promoCodes) {
    if (promoCodes.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Column(
            children: [
              Icon(Icons.local_offer_outlined,
                  size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Aucun code promo disponible',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final promoCode = promoCodes[index];
          return _buildPromoCodeCard(context, promoCode);
        },
        childCount: promoCodes.length,
      ),
    );
  }

  Widget _buildPromoCodeCard(BuildContext context, PromoCode promoCode) {
    final isExpired = promoCode.expiryDate.isBefore(DateTime.now());
    final remainingDays =
        promoCode.expiryDate.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${promoCode.amount.toStringAsFixed(2)}€',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildStatusChip(promoCode),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.copy, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    promoCode.code,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isExpired
                  ? 'Expiré'
                  : 'Expire dans $remainingDays jour${remainingDays > 1 ? 's' : ''}',
              style: TextStyle(
                color: isExpired ? Colors.red : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(PromoCode promoCode) {
    final isExpired = promoCode.expiryDate.isBefore(DateTime.now());

    Color backgroundColor;
    Color textColor;
    String text;

    if (promoCode.isUsed) {
      backgroundColor = Colors.grey[100]!;
      textColor = Colors.grey[600]!;
      text = 'Utilisé';
    } else if (isExpired) {
      backgroundColor = Colors.red[50]!;
      textColor = Colors.red;
      text = 'Expiré';
    } else {
      backgroundColor = Colors.green[50]!;
      textColor = Colors.green;
      text = 'Disponible';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPointsHistory(List<PointsHistory> history) {
    if (history.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Column(
            children: [
              Icon(Icons.history, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Aucun historique disponible',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = history[index];
          return _buildHistoryCard(item);
        },
        childCount: history.length,
      ),
    );
  }

  Widget _buildHistoryCard(PointsHistory item) {
    String typeLabel;
    IconData typeIcon;

    switch (item.type) {
      case 'order':
        typeLabel = 'Commande';
        typeIcon = Icons.shopping_bag;
        break;
      case 'reservation':
        typeLabel = 'Deal Express';
        typeIcon = Icons.flash_on;
        break;
      case 'booking':
        typeLabel = 'Réservation';
        typeIcon = Icons.calendar_today;
        break;
      default:
        typeLabel = 'Transaction';
        typeIcon = Icons.paid;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            shape: BoxShape.circle,
          ),
          child: Icon(typeIcon, color: Colors.blue[700]),
        ),
        title: Text(
          typeLabel,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(item.date),
              style: TextStyle(color: Colors.grey[600]),
            ),
            Text(
              '+${item.points} points',
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: Text(
          '${item.amount.toStringAsFixed(2)}€',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Future<void> _claimReward(
      BuildContext context, int points, double amount) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(userId);
      final promoCodesCollection =
          FirebaseFirestore.instance.collection('promo_codes');

      // Générer un code promo unique
      final promoCode = 'UP${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();
      final expiryDate = now.add(const Duration(days: 30));

      // Créer le code promo dans la collection promo_codes
      await promoCodesCollection.doc(promoCode).set({
        'code': promoCode,
        'companyId': 'UP',
        'createdAt': Timestamp.fromDate(now),
        'currentUses': 0,
        'customerId': userId,
        'discountType': 'amount',
        'discountValue': amount,
        'expiresAt': Timestamp.fromDate(expiryDate),
        'isPercentage': false,
        'isPublic': false,
        'maxUses': '1',
        'status': 'active',
      });

      // Mettre à jour les points de l'utilisateur
      await userDoc.update({
        'loyaltyPoints': FieldValue.increment(-points),
        'promoCodes': FieldValue.arrayUnion([
          {
            'code': promoCode,
            'amount': amount,
            'expiryDate': Timestamp.fromDate(expiryDate),
            'isUsed': false,
          }
        ]),
      });

      // Afficher une confirmation
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Code promo de $amount € généré avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la génération du code promo'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
