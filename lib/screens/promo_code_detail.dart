import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/classes/promo_code_post.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/widgets/app_bar/custom_app_bar.dart';
import 'package:happy/widgets/company_info_card.dart';
import 'package:happy/widgets/share_confirmation_dialog.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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

    final isLiked =
        context.watch<UserModel>().likedPosts.contains(widget.post.id);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Code Promo',
        align: Alignment.center,
        actions: [
          IconButton(
            icon: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.red : Colors.grey[800],
            ),
            onPressed: () async {
              await Provider.of<UserModel>(context, listen: false)
                  .handleLike(widget.post);
            },
          ),
          IconButton(
            icon: Icon(Icons.share, color: Colors.grey[800]),
            onPressed: () => _showShareOptions(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _copyToClipboard(context, fullPromoCode!.code),
        backgroundColor: Colors.blue[800],
        elevation: 2,
        label: const Row(
          children: [
            Icon(Icons.copy, size: 20),
            SizedBox(width: 8),
            Text(
              'Copier le code',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
            color: Colors.black.withAlpha(13),
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

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
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
                color: Colors.black.withAlpha(13),
                blurRadius: 10,
              ),
            ],
          ),
          child: Text(
            widget.post.description,
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
                color: Colors.black.withAlpha(13),
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

  void _showShareOptions(BuildContext context) {
    final users = Provider.of<UserModel>(context, listen: false);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Partager sur mon profil'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return ShareConfirmationDialog(
                      post: Post(
                        id: widget.post.id,
                        companyId: widget.post.companyId,
                        timestamp: DateTime.now(),
                        type: 'promo_code',
                      ),
                      onConfirm: (String comment) async {
                        try {
                          Navigator.of(dialogContext).pop();

                          await FirebaseFirestore.instance
                              .collection('posts')
                              .doc(widget.post.id)
                              .update({
                            'sharesCount': FieldValue.increment(1),
                          });

                          await users.sharePost(
                            widget.post.id,
                            users.userId,
                            comment: comment,
                          );

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Publication partagée avec succès!'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur lors du partage: $e'),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                    );
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.message_outlined),
              title: const Text('Envoyer en message'),
              onTap: () {
                Navigator.pop(context);
                _showConversationsList(context, users);
              },
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  void _showConversationsList(BuildContext context, UserModel users) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    'Envoyer à...',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where(FieldPath.documentId,
                            whereIn: users.followedUsers)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                            child: Text('Une erreur est survenue'));
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final users = snapshot.data!.docs;

                      if (users.isEmpty) {
                        return const Center(
                          child: Text('Vous ne suivez aucun utilisateur'),
                        );
                      }

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final userData =
                              users[index].data() as Map<String, dynamic>;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage:
                                  NetworkImage(userData['image_profile'] ?? ''),
                            ),
                            title: Text(
                                '${userData['firstName']} ${userData['lastName']}'),
                            onTap: () async {
                              try {
                                final post = Post(
                                  id: widget.post.id,
                                  companyId: widget.post.companyId,
                                  timestamp: DateTime.now(),
                                  type: 'promo_code',
                                );

                                await Provider.of<ConversationService>(context,
                                        listen: false)
                                    .sharePostInConversation(
                                  senderId: Provider.of<UserModel>(context,
                                          listen: false)
                                      .userId,
                                  receiverId: users[index].id,
                                  post: post,
                                );

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Message envoyé avec succès!'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Erreur lors de l\'envoi: $e'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
