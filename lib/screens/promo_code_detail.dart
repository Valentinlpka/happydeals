import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/classes/promo_code_post.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/widgets/company_info_card.dart';
import 'package:happy/widgets/custom_app_bar.dart';
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
      final promoDoc = await FirebaseFirestore.instance
          .collection('promo_codes')
          .doc(widget.post.promoCodeId)
          .get();

      if (promoDoc.exists) {
        setState(() {
          fullPromoCode = PromoCodePost.fromDocument(promoDoc);
        });

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
      debugPrint('Erreur lors du chargement des détails: $e');
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
              Text('Code "$code" copié !'),
            ],
          ),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
      appBar: const CustomAppBar(
        title: 'Code Promo',
        align: Alignment.center,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 10.0, bottom: 10),
                    child: Text(
                      'Code Promo',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  _buildPromoCodeCard(),
                  const SizedBox(height: 24),
                  _buildCompanySection(),
                  const SizedBox(height: 24),
                  _buildDescriptionSection(),
                  const SizedBox(height: 24),
                  _buildDetailsSection(),
                  if (fullPromoCode?.conditionType != null)
                    const SizedBox(height: 24),
                  _buildConditionCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoCodeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  fullPromoCode!.code,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.copy),
                  color: Colors.blue[700],
                  onPressed: () =>
                      _copyToClipboard(context, fullPromoCode!.code),
                ),
              ],
            ),
          ),
          if (fullPromoCode!.maxUses != null) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: fullPromoCode!.currentUses.toDouble() /
                  (int.parse(fullPromoCode!.maxUses!) * 1.0),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
            ),
            const SizedBox(height: 8),
            Text(
              'Utilisé ${fullPromoCode!.currentUses} fois sur ${fullPromoCode!.maxUses}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompanySection() {
    return Column(
      spacing: 12,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Entreprise',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('companys')
              .doc(widget.post.companyId)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('Entreprise non trouvée'));
            }

            final company = Company.fromDocument(snapshot.data!);
            return CompanyInfoCard(
              company: company,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailsEntreprise(
                    entrepriseId: widget.post.companyId,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() =>
      _buildSection('Description', widget.post.description);

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Informations',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            children: [
              if (fullPromoCode!.expiresAt != null)
                _buildInfoRow(
                  'Date d\'expiration',
                  DateFormat('dd/MM/yyyy à HH:mm')
                      .format(fullPromoCode!.expiresAt!),
                  Icons.calendar_today,
                ),
              _buildInfoRow(
                'Créé le',
                DateFormat('dd/MM/yyyy à HH:mm')
                    .format(fullPromoCode!.createdAt!),
                Icons.access_time,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConditionCard() {
    if (fullPromoCode?.conditionType == null) return const SizedBox.shrink();

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        const Text(
          'Condition d\'utilisation',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fullPromoCode?.conditionType == 'amount')
                  _buildAmountCondition()
                else if (fullPromoCode?.conditionType == 'quantity')
                  _buildQuantityCondition(),
              ],
            ),
          ),
        ),
      ],
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
          ListTile(
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
        ],
      ],
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

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              content,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[800],
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
