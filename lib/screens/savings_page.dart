// savings_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SavingsPage extends StatelessWidget {
  const SavingsPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Économies'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Widget pour afficher le total des économies
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('userId', isEqualTo: userId)
                .snapshots(),
            builder: (context, ordersSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reservations')
                    .where('userId', isEqualTo: userId)
                    .snapshots(),
                builder: (context, reservationsSnapshot) {
                  double totalSavings = 0;

                  // Calculer les économies des commandes
                  if (ordersSnapshot.hasData) {
                    for (var doc in ordersSnapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final happyDealSavings =
                          (data['happyDealSavings'] ?? 0.0) as num;
                      final discountAmount =
                          (data['discountAmount'] ?? 0.0) as num;
                      totalSavings += happyDealSavings + discountAmount;
                    }
                  }

                  // Calculer les économies des réservations
                  if (reservationsSnapshot.hasData) {
                    for (var doc in reservationsSnapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final originalPrice =
                          (data['originalPrice'] ?? 0.0) * 2 as num;
                      totalSavings += originalPrice;
                    }
                  }

                  // Mettre à jour le UserModel avec le nouveau total

                  return Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor.withOpacity(0.8)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Total des économies',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${totalSavings.toStringAsFixed(2)}€',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          // Liste des transactions
          Expanded(
            child: StreamBuilder<List<TransactionData>>(
              stream: _getTransactions(userId),
              builder: (context, snapshot) {
                debugPrint(
                    'État du StreamBuilder: ${snapshot.connectionState}');

                if (snapshot.hasError) {
                  debugPrint('Erreur: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Erreur: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  debugPrint('En attente des données...');
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Chargement des transactions...'),
                      ],
                    ),
                  );
                }

                final transactions = snapshot.data ?? [];
                debugPrint(
                    'Nombre de transactions reçues: ${transactions.length}');

                if (transactions.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet_outlined,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Aucune économie réalisée pour le moment'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    debugPrint('Affichage transaction $index');
                    return TransactionCard(transaction: transaction);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

// Modifiez uniquement la partie _getTransactions dans votre code :

  Stream<List<TransactionData>> _getTransactions(String userId) {
    debugPrint('Démarrage de _getTransactions pour userId: $userId');

    return Stream.fromFuture(Future(() async {
      try {
        debugPrint('Vérification des commandes...');
        final ordersQuery = await FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: userId)
            .get();
        debugPrint('Nombre de commandes trouvées: ${ordersQuery.docs.length}');

        List<TransactionData> orderTransactions = ordersQuery.docs
            .map((doc) {
              try {
                final data = doc.data();
                debugPrint('Traitement commande ${doc.id}');

                final happyDealSavings =
                    (data['happyDealSavings'] ?? 0.0) as num;
                final discountAmount = (data['discountAmount'] ?? 0.0) as num;

                // Si pas d'économies, on ignore cette transaction
                if (happyDealSavings == 0 && discountAmount == 0) {
                  return null;
                }

                // Gérer les timestamps de manière sécurisée
                Timestamp timestamp;
                if (data['completedAt'] != null) {
                  timestamp = data['completedAt'] as Timestamp;
                } else if (data['createdAt'] != null) {
                  timestamp = data['createdAt'] as Timestamp;
                } else {
                  timestamp = Timestamp.now();
                }

                final isHappyDeal = happyDealSavings > 0;

                final items = data['items'] as List?;
                final firstItem =
                    items?.isNotEmpty == true ? items!.first : null;
                final itemName =
                    firstItem is Map ? firstItem['name'] as String? ?? '' : '';

                return TransactionData(
                  type: isHappyDeal
                      ? TransactionType.happyDeal
                      : TransactionType.promoCode,
                  date: timestamp,
                  savings: isHappyDeal ? happyDealSavings : discountAmount,
                  originalPrice: (data['subtotal'] ?? 0.0) as num,
                  finalPrice: (data['totalPrice'] ?? 0.0) as num,
                  companyName: data['entrepriseId']?.toString() ?? '',
                  promoCode: isHappyDeal
                      ? null
                      : data['promoCode']
                          ?.toString(), // N'afficher le code promo que si c'est une réduction par code promo
                  itemName: itemName,
                );
              } catch (e) {
                debugPrint('Erreur lors du traitement de la commande: $e');
                return null;
              }
            })
            .where((transaction) =>
                transaction != null) // Filtrer les transactions nulles
            .cast<TransactionData>()
            .toList();

        debugPrint('Vérification des réservations...');
        final reservationsQuery = await FirebaseFirestore.instance
            .collection('reservations')
            .where('userId', isEqualTo: userId)
            .get();

        List<TransactionData> reservationTransactions = reservationsQuery.docs
            .map((doc) {
              try {
                final data = doc.data();
                debugPrint('Traitement réservation ${doc.id}');

                final originalPrice = (data['originalPrice'] ?? 0.0) as num;
                final price = (data['price'] ?? 0.0) as num;

                // Si pas d'économies, on ignore cette réservation
                if (originalPrice <= 0) {
                  return null;
                }

                return TransactionData(
                  type: TransactionType.dealExpress,
                  date: (data['createdAt'] as Timestamp?) ?? Timestamp.now(),
                  savings: originalPrice,
                  originalPrice: originalPrice * 2,
                  finalPrice: price,
                  companyName: data['companyName']?.toString() ?? '',
                  basketType: data['basketType']?.toString(),
                );
              } catch (e) {
                debugPrint('Erreur lors du traitement de la réservation: $e');
                return null;
              }
            })
            .where((transaction) => transaction != null)
            .cast<TransactionData>()
            .toList();

        final allTransactions = [
          ...orderTransactions,
          ...reservationTransactions
        ];
        allTransactions.sort((a, b) => b.date.compareTo(a.date));

        debugPrint(
            'Total transactions avec économies: ${allTransactions.length}');
        return allTransactions;
      } catch (e, stackTrace) {
        debugPrint('Erreur lors de la récupération des données: $e');
        debugPrint('Stack trace: $stackTrace');
        return <TransactionData>[];
      }
    }));
  }
}

class TransactionCard extends StatelessWidget {
  final TransactionData transaction;

  const TransactionCard({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTransactionTypeChip(transaction.type),
                Text(
                  '-${transaction.savings.toStringAsFixed(2)}€',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              transaction.itemName.isNotEmpty
                  ? transaction.itemName
                  : transaction.basketType ?? '',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 4),
                Text(dateFormat.format(transaction.date.toDate())),
              ],
            ),
            if (transaction.promoCode != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.local_offer, size: 16),
                  const SizedBox(width: 4),
                  Text('Code promo: ${transaction.promoCode}'),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Prix initial: ${transaction.originalPrice.toStringAsFixed(2)}€',
                  style: const TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  'Prix final: ${transaction.finalPrice.toStringAsFixed(2)}€',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTypeChip(TransactionType type) {
    Color color;
    String label;
    IconData icon;

    switch (type) {
      case TransactionType.happyDeal:
        color = Colors.orange;
        label = 'Happy Deal';
        icon = Icons.celebration;
        break;
      case TransactionType.dealExpress:
        color = Colors.purple;
        label = 'Deal Express';
        icon = Icons.flash_on;
        break;
      case TransactionType.promoCode:
        color = Colors.blue;
        label = 'Code Promo';
        icon = Icons.local_offer;
        break;
    }

    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
    );
  }
}

enum TransactionType {
  happyDeal,
  dealExpress,
  promoCode,
}

class TransactionData {
  final TransactionType type;
  final Timestamp date;
  final num savings;
  final num originalPrice;
  final num finalPrice;
  final String companyName;
  final String? promoCode;
  final String? basketType;
  final String itemName;

  TransactionData({
    required this.type,
    required this.date,
    required this.savings,
    required this.originalPrice,
    required this.finalPrice,
    required this.companyName,
    this.promoCode,
    this.basketType,
    this.itemName = '',
  });
}
