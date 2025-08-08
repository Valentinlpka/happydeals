import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/service_promotion.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/screens/details_page/details_service_page.dart';
import 'package:happy/widgets/company_info_card.dart';
import 'package:intl/intl.dart';

class ServicePromotionDetailPage extends StatefulWidget {
  final ServicePromotion promotion;

  const ServicePromotionDetailPage({
    super.key,
    required this.promotion,
  });

  @override
  State<ServicePromotionDetailPage> createState() => _ServicePromotionDetailPageState();
}

class _ServicePromotionDetailPageState extends State<ServicePromotionDetailPage> {
  final ScrollController _scrollController = ScrollController();
  bool isDescriptionExpanded = false;
  final dateFormat = DateFormat('dd/MM/yyyy');
  late bool isValid;
  late bool isExpired;

  @override
  void initState() {
    super.initState();
    isValid = widget.promotion.isValid();
    isExpired = widget.promotion.endDate.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildPromotionHeader(),
                _buildMainContent(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      backgroundColor: Colors.grey[50],
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      title: Text(
        widget.promotion.title,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.black),
          onPressed: _showShareBottomSheet,
        ),
      ],
    );
  }

  Widget _buildPromotionHeader() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImageSection(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusBadge(),
                const SizedBox(height: 16),
                _buildTitleSection(),
                const SizedBox(height: 16),
                _buildPriceSection(),
                const SizedBox(height: 16),
                _buildValiditySection(),
                if (widget.promotion.description.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildDescriptionSection(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            width: double.infinity,
            color: Colors.grey[50],
            child: widget.promotion.photo.isNotEmpty
                ? Image.network(
                    widget.promotion.photo,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 40, color: Colors.grey),
                              SizedBox(height: 8),
                              Text(
                                'Image non disponible',
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[200],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                  )
                : Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'Aucune image',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
        if (isExpired)
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
            ),
            child: const Center(
              child: Text(
                'PROMOTION TERMINÉE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isExpired 
            ? Colors.grey 
            : isValid 
                ? Colors.red 
                : Colors.orange,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isExpired
            ? 'TERMINÉE'
            : widget.promotion.discountType == 'fixed'
                ? '-${widget.promotion.discountValue.toStringAsFixed(0)}€'
                : '-${widget.promotion.discountPercentage.toStringAsFixed(0)}%',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.promotion.title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isExpired ? Colors.grey : Colors.black,
            height: 1.3,
          ),
          maxLines: isDescriptionExpanded ? null : 2,
          overflow: isDescriptionExpanded ? null : TextOverflow.ellipsis,
        ),
        if (widget.promotion.title.length > 50)
          GestureDetector(
            onTap: () => setState(() => isDescriptionExpanded = !isDescriptionExpanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                isDescriptionExpanded ? 'Voir moins' : 'Voir plus',
                style: TextStyle(
                  color: Colors.blue[600],
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPriceSection() {
    return Row(
      children: [
        Text(
          '${widget.promotion.newPrice.toStringAsFixed(2)}€',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: isExpired ? Colors.grey : Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${widget.promotion.oldPrice.toStringAsFixed(2)}€',
          style: const TextStyle(
            fontSize: 20,
            decoration: TextDecoration.lineThrough,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildValiditySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today, 
            size: 20, 
            color: isExpired ? Colors.red : Colors.grey[600]
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpired ? 'Promotion terminée' : 'Période de validité',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isExpired ? Colors.red : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isExpired
                      ? 'Terminée le ${dateFormat.format(widget.promotion.endDate)}'
                      : 'Du ${dateFormat.format(widget.promotion.startDate)} au ${dateFormat.format(widget.promotion.endDate)}',
                  style: TextStyle(
                    fontSize: 16,
                    color: isExpired ? Colors.red : Colors.grey[600],
                    fontWeight: isExpired ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(8),
                spreadRadius: 0,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Text(
            widget.promotion.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[800],
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildCompanySection(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompanySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Entreprise',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
     CompanyInfoCard(
          name: widget.promotion.companyName,
          logo: widget.promotion.companyLogo,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailsEntreprise(
                    entrepriseId: widget.promotion.companyId,
                  ),
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(39),
            spreadRadius: 2,
            blurRadius: 15,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 44,
          child: ElevatedButton(
            onPressed: isExpired ? null : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ServiceDetailPage(
                    serviceId: widget.promotion.serviceId,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: isExpired ? Colors.grey : Colors.blue[600],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              isExpired ? 'Promotion terminée' : 'Voir le service',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showShareBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const ListTile(
                title: Text(
                  "Partager cette promotion",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Partager sur mon profil'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implémenter le partage
                },
              ),
              ListTile(
                leading: const Icon(Icons.message_outlined),
                title: const Text('Envoyer en message'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implémenter l'envoi en message
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _getCompanyPhoneNumber(String companyId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companys')
          .doc(companyId)
          .get();
      if (doc.exists) {
        final data = doc.data();
        return data?['phone'];
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération du numéro de téléphone: $e');
    }
    return null;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
} 