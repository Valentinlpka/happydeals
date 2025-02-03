import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/classes/promo_code_post.dart';
import 'package:intl/intl.dart';

class PromoCodeDetails extends StatefulWidget {
  final PromoCodePost post;
  final String companyName;
  final String companyLogo;

  const PromoCodeDetails({
    super.key,
    required this.post,
    required this.companyName,
    required this.companyLogo,
  });

  @override
  State<PromoCodeDetails> createState() => _PromoCodeDetailsState();
}

class _PromoCodeDetailsState extends State<PromoCodeDetails> {
  PromoCodePost? fullPromoCode;
  Product? conditionProduct;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFullDetails();
  }

  Future<void> _loadFullDetails() async {
    try {
      // Toujours charger depuis promo_codes
      final promoDoc = await FirebaseFirestore.instance
          .collection('promo_codes')
          .doc(widget.post.promoCodeId) // Utiliser l'ID directement
          .get();

      print(widget.post.promoCodeId);

      if (promoDoc.exists) {
        setState(() {
          fullPromoCode = PromoCodePost.fromDocument(promoDoc);
        });

        // Si c'est une condition de type quantité, charger le produit associé
        if (fullPromoCode?.conditionType == 'quantity' &&
            fullPromoCode?.conditionProductId != null &&
            fullPromoCode!.conditionProductId!.isNotEmpty) {
          final productDoc = await FirebaseFirestore.instance
              .collection('products')
              .doc(fullPromoCode!.conditionProductId)
              .get();

          if (productDoc.exists) {
            setState(() {
              conditionProduct = Product.fromFirestore(productDoc);
            });
          }
        }
      }
    } catch (e) {
      print('Erreur lors du chargement des détails: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _copyToClipboard(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Code "$code" copié avec succès !'),
            ],
          ),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildConditionCard() {
    if (fullPromoCode?.conditionType == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Condition d\'utilisation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (fullPromoCode?.conditionType == 'amount')
              _buildAmountCondition()
            else if (fullPromoCode?.conditionType == 'quantity')
              _buildQuantityCondition(),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCondition() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.shopping_cart, color: Colors.blue[700]),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Montant minimum d\'achat',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${fullPromoCode!.conditionValue?.toStringAsFixed(2)}€',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuantityCondition() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.inventory_2, color: Colors.purple[700]),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quantité minimum requise',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${fullPromoCode!.conditionValue?.toInt()} unité(s)',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[700],
                  ),
                ),
              ],
            ),
          ],
        ),
        if (conditionProduct != null) ...[
          const SizedBox(height: 16),
          const Text(
            'Produit concerné',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: conditionProduct!.variants.isNotEmpty &&
                      conditionProduct!.variants[0].images.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        conditionProduct!.variants[0].images[0],
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.image_not_supported),
                    ),
              title: Text(
                conditionProduct!.name,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Prix: ${conditionProduct!.basePrice.toStringAsFixed(2)}€',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Toujours utiliser les données complètes
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (fullPromoCode == null) {
      return const Scaffold(
        body: Center(child: Text('Code promo non trouvé')),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[700]!, Colors.blue[900]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 42,
                          backgroundImage: NetworkImage(widget.companyLogo),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.companyName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Code Promo Card avec les données complètes
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 32),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey[300]!,
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  fullPromoCode!.code,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  color: Colors.blue[700],
                                  onPressed: () => _copyToClipboard(
                                    context,
                                    fullPromoCode!.code,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              fullPromoCode!.isPercentage
                                  ? '${fullPromoCode!.discountValue.toStringAsFixed(0)}% de réduction'
                                  : '${fullPromoCode!.discountValue.toStringAsFixed(2)}€ de réduction',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fullPromoCode!.description,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 24),

                  // Informations détaillées
                  if (fullPromoCode!.expiresAt != null)
                    _buildInfoRow(
                      'Valable jusqu\'au',
                      DateFormat('dd/MM/yyyy à HH:mm')
                          .format(fullPromoCode!.expiresAt!),
                      Icons.calendar_today,
                    ),
                  if (fullPromoCode!.maxUses != null)
                    _buildInfoRow(
                      'Utilisations',
                      '${fullPromoCode!.currentUses}/${fullPromoCode!.maxUses}',
                      Icons.people,
                    ),
                  _buildInfoRow(
                    'Créé le',
                    DateFormat('dd/MM/yyyy à HH:mm')
                        .format(fullPromoCode!.createdAt!),
                    Icons.access_time,
                  ),
                  if (fullPromoCode!.conditionType != null)
                    _buildConditionCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
