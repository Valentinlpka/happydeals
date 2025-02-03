// savings_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/widgets/custom_app_bar_back.dart';
import 'package:intl/intl.dart';

class SavingsPage extends StatelessWidget {
  const SavingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: const CustomAppBarBack(title: 'Mes Économies'),
      body: StreamBuilder<SavingsData>(
        stream: _getSavingsData(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Erreur: ${snapshot.error}'),
            );
          }

          final savingsData = snapshot.data ?? SavingsData.empty();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child:
                    _buildSavingsSummary(context, savingsData, currencyFormat),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildStatisticsCards(savingsData, currencyFormat),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Historique des économies',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: _buildTransactionsList(savingsData.transactions),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSavingsSummary(
      BuildContext context, SavingsData data, NumberFormat formatter) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Total des économies',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            formatter.format(data.totalSavings),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSavingsStat(
                'Ce mois',
                formatter.format(data.monthSavings),
                Colors.white,
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.3),
              ),
              _buildSavingsStat(
                'Moyenne/commande',
                formatter.format(data.averageSavings),
                Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.8),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsCards(SavingsData data, NumberFormat formatter) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Happy Deals',
            formatter.format(data.happyDealSavings),
            Icons.local_offer,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Codes Promo',
            formatter.format(data.promoCodeSavings),
            Icons.confirmation_number,
            Colors.purple,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Deal Express',
            formatter.format(data.dealExpressSavings),
            Icons.flash_on,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(List<Transaction> transactions) {
    if (transactions.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.savings_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Aucune économie réalisée',
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
          final transaction = transactions[index];
          return _buildTransactionCard(transaction);
        },
        childCount: transactions.length,
      ),
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTransactionTypeChip(transaction.type),
                Text(
                  '-${currencyFormat.format(transaction.savings)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2ECC71),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getTypeColor(transaction.type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getTypeIcon(transaction.type),
                    color: _getTypeColor(transaction.type),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.itemName.isNotEmpty
                            ? transaction.itemName
                            : transaction.basketType ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(transaction.date.toDate()),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (transaction.promoCode != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.local_offer, size: 16, color: Colors.purple[700]),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      transaction.promoCode!,
                      style: TextStyle(
                        color: Colors.purple[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Prix initial: ${currencyFormat.format(transaction.originalPrice)}',
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    'Prix final: ${currencyFormat.format(transaction.finalPrice)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
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

  Color _getTypeColor(TransactionType type) {
    switch (type) {
      case TransactionType.happyDeal:
        return Colors.orange[700]!;
      case TransactionType.dealExpress:
        return Colors.purple[700]!;
      case TransactionType.promoCode:
        return Colors.blue[700]!;
    }
  }

  IconData _getTypeIcon(TransactionType type) {
    switch (type) {
      case TransactionType.happyDeal:
        return Icons.celebration;
      case TransactionType.dealExpress:
        return Icons.flash_on;
      case TransactionType.promoCode:
        return Icons.local_offer;
    }
  }

  Stream<SavingsData> _getSavingsData(String userId) {
    return Stream.fromFuture(() async {
      try {
        final ordersQuery = await FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: userId)
            .get();

        final reservationsQuery = await FirebaseFirestore.instance
            .collection('reservations')
            .where('userId', isEqualTo: userId)
            .get();

        final transactions = <Transaction>[];
        var totalSavings = 0.0;
        var monthSavings = 0.0;
        var happyDealSavings = 0.0;
        var promoCodeSavings = 0.0;
        var dealExpressSavings = 0.0;

        // Traitement des commandes
        for (var doc in ordersQuery.docs) {
          final data = doc.data();
          final items = data['items'] as List;
          final discountAmount = (data['discountAmount'] ?? 0.0) as num;
          final subtotal = (data['subtotal'] ?? 0.0) as num;
          final totalPrice = (data['totalPrice'] ?? 0.0) as num;

          if (items.isEmpty) continue;

          // Calculer les économies Happy Deal pour chaque produit
          for (var item in items) {
            final itemData = item as Map<String, dynamic>;
            final originalPrice = itemData['originalPrice'] as num;
            final appliedPrice = itemData['appliedPrice'] as num;
            final itemSaving = originalPrice - appliedPrice;

            if (itemSaving > 0) {
              final date =
                  (data['completedAt'] ?? data['createdAt']) as Timestamp;
              final now = DateTime.now();

              if (date.toDate().month == now.month &&
                  date.toDate().year == now.year) {
                monthSavings += itemSaving;
              }

              happyDealSavings += itemSaving;
              totalSavings += itemSaving;

              // Créer une transaction pour chaque produit avec une économie
              transactions.add(Transaction(
                type: TransactionType.happyDeal,
                date: date,
                savings: itemSaving,
                originalPrice: originalPrice,
                finalPrice: appliedPrice,
                itemName: itemData['name'] as String,
              ));
            }
          }

          // Traiter le code promo séparément
          if (discountAmount > 0) {
            final date =
                (data['completedAt'] ?? data['createdAt']) as Timestamp;
            final now = DateTime.now();

            if (date.toDate().month == now.month &&
                date.toDate().year == now.year) {
              monthSavings += discountAmount;
            }

            promoCodeSavings += discountAmount;
            totalSavings += discountAmount;

            transactions.add(Transaction(
              type: TransactionType.promoCode,
              date: date,
              savings: discountAmount,
              originalPrice: subtotal,
              finalPrice: totalPrice,
              itemName: 'Code promo',
              promoCode: data['promoCode'] as String?,
            ));
          }
        }

        // Traitement des Deal Express
        for (var doc in reservationsQuery.docs) {
          final data = doc.data();
          final originalPrice = (data['originalPrice'] ?? 0.0) as num;

          if (originalPrice <= 0) continue;

          final date = data['createdAt'] as Timestamp;
          if (date.toDate().month == DateTime.now().month) {
            monthSavings += originalPrice;
          }

          dealExpressSavings += originalPrice;
          totalSavings += originalPrice;

          transactions.add(Transaction(
            type: TransactionType.dealExpress,
            date: date,
            savings: originalPrice,
            originalPrice: originalPrice * 2,
            finalPrice: data['price'] ?? 0.0,
            itemName: data['basketType'] ?? 'Panier surprise',
          ));
        }

        transactions.sort((a, b) => b.date.compareTo(a.date));

        return SavingsData(
          totalSavings: totalSavings,
          monthSavings: monthSavings,
          happyDealSavings: happyDealSavings,
          promoCodeSavings: promoCodeSavings,
          dealExpressSavings: dealExpressSavings,
          averageSavings:
              transactions.isEmpty ? 0 : totalSavings / transactions.length,
          transactions: transactions,
        );
      } catch (e) {
        print('Erreur lors de la récupération des économies: $e');
        return SavingsData.empty();
      }
    }());
  }
}

enum TransactionType {
  happyDeal,
  dealExpress,
  promoCode,
}

class Transaction {
  final TransactionType type;
  final Timestamp date;
  final num savings;
  final num originalPrice;
  final num finalPrice;
  final String itemName;
  final String? promoCode;
  final String? basketType;

  Transaction({
    required this.type,
    required this.date,
    required this.savings,
    required this.originalPrice,
    required this.finalPrice,
    required this.itemName,
    this.promoCode,
    this.basketType,
  });
}

class SavingsData {
  final double totalSavings;
  final double monthSavings;
  final double happyDealSavings;
  final double promoCodeSavings;
  final double dealExpressSavings;
  final double averageSavings;
  final List<Transaction> transactions;

  const SavingsData({
    required this.totalSavings,
    required this.monthSavings,
    required this.happyDealSavings,
    required this.promoCodeSavings,
    required this.dealExpressSavings,
    required this.averageSavings,
    required this.transactions,
  });

  SavingsData.empty()
      : totalSavings = 0.0,
        monthSavings = 0.0,
        happyDealSavings = 0.0,
        promoCodeSavings = 0.0,
        dealExpressSavings = 0.0,
        averageSavings = 0.0,
        transactions = [];
}
