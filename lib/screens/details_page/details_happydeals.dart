import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:happy/classes/happydeal.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/product.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/screens/shop/product_detail_page.dart';
import 'package:happy/widgets/share_confirmation_dialog.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DetailsHappyDeals extends StatefulWidget {
  final HappyDeal happydeal;

  const DetailsHappyDeals({
    super.key,
    required this.happydeal,
  });

  @override
  State<DetailsHappyDeals> createState() => _DetailsHappyDealsState();
}

class _DetailsHappyDealsState extends State<DetailsHappyDeals> {
  late Future<Product?> _productFuture;
  final ScrollController _scrollController = ScrollController();
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      ScreenUtil.init(
        context,
        designSize: const Size(375, 812),
      );
      _isInitialized = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _productFuture = _fetchProduct();
  }

  Future<Product?> _fetchProduct() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.happydeal.productId)
          .get();
      return doc.exists ? Product.fromFirestore(doc) : null;
    } catch (e) {
      return null;
    }
  }



  String _formatDateTime(DateTime dateTime) {
    return DateFormat('d MMMM yyyy', 'fr_FR').format(dateTime);
  }

  String _getRemainingTime() {
    final now = DateTime.now();
    final difference = widget.happydeal.endDate.difference(now);

    if (difference.isNegative) return 'Offre expirée';

    final days = difference.inDays;
    final hours = difference.inHours % 24;

    if (days > 0) {
      return '$days jour${days > 1 ? 's' : ''} restant${days > 1 ? 's' : ''}';
    } else if (hours > 0) {
      return '$hours heure${hours > 1 ? 's' : ''} restante${hours > 1 ? 's' : ''}';
    } else {
      final minutes = difference.inMinutes % 60;
      return '$minutes minute${minutes > 1 ? 's' : ''} restante${minutes > 1 ? 's' : ''}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 300.h,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.white,
      leadingWidth: 200.w,
      leading: Row(
        children: [
          _buildBackButton(),
          _buildLikeButton(),
          _buildShareButton(),
        ],
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            _buildHeroImage(),
            _buildGradientOverlay(),
            _buildDealBadge(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return IconButton(
      icon: Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8.r,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(Icons.arrow_back, color: Colors.black87, size: 20.w),
      ),
      onPressed: () => Navigator.pop(context),
    );
  }

  Widget _buildHeroImage() {
    return FutureBuilder<Product?>(
      future: _productFuture,
      builder: (context, snapshot) {
        // Vérification de la validité de l'URL de l'image
        bool hasValidImage = snapshot.hasData && 
                           snapshot.data!.variants.isNotEmpty && 
                           snapshot.data!.variants.first.images.isNotEmpty &&
                           snapshot.data!.variants.first.images.first.isNotEmpty &&
                           (snapshot.data!.variants.first.images.first.startsWith('http://') ||
                            snapshot.data!.variants.first.images.first.startsWith('https://'));

        return Hero(
          tag: 'deal-${widget.happydeal.id}',
          child: hasValidImage
              ? Image.network(
                  snapshot.data!.variants.first.images.first,
            fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildDefaultImage(),
                )
              : _buildDefaultImage(),
        );
      },
    );
  }

  Widget _buildDefaultImage() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              color: Colors.grey[400],
              size: 50.w,
            ),
            SizedBox(height: 8.h),
            Text(
              'Image non disponible',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withAlpha(70),
          ],
        ),
      ),
    );
  }

  Widget _buildDealBadge() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16.h,
      right: 16.w,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.red[600],
          borderRadius: BorderRadius.circular(25.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8.r,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_offer, color: Colors.white, size: 18.w),
            SizedBox(width: 4.w),
            Text(
              '-${widget.happydeal.discountPercentage.toStringAsFixed(0)}%',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLikeButton() {
    return Consumer<UserModel>(
      builder: (context, userModel, _) {
        final isLiked = userModel.likedPosts.contains(widget.happydeal.id);
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          child: IconButton(
            icon: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: isLiked ? Colors.red[50] : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8.r,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? Colors.red : Colors.black87,
                size: 20.w,
              ),
            ),
            onPressed: () async => await userModel.handleLike(widget.happydeal),
          ),
        );
      },
    );
  }

  Widget _buildShareButton() {
    return Container(
      margin: EdgeInsets.only(right: 4.w),
      child: IconButton(
        icon: Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8.r,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(Icons.share, color: Colors.blue[800], size: 20.w),
        ),
        onPressed: () => _showShareOptions(context),
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
                        companyName: widget.happydeal.companyName,
                        companyLogo: widget.happydeal.companyLogo,
                        id: widget.happydeal.id,
                        companyId: widget.happydeal.companyId,
                        timestamp: DateTime.now(),
                        type: 'happydeal',
                      ),
                      onConfirm: (String comment) async {
                        try {
                          Navigator.of(dialogContext).pop();

                          await FirebaseFirestore.instance
                              .collection('posts')
                              .doc(widget.happydeal.id)
                              .update({
                            'sharesCount': FieldValue.increment(1),
                          });

                          await users.sharePost(
                            widget.happydeal.id,
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
                                  companyName: widget.happydeal.companyName,
                                  companyLogo: widget.happydeal.companyLogo,
                                  id: widget.happydeal.id,
                                  companyId: widget.happydeal.companyId,
                                  timestamp: DateTime.now(),
                                  type: 'happydeal',
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

  Widget _buildContent() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitle(),
            SizedBox(height: 24.h),
            _buildPriceSection(),
            SizedBox(height: 24.h),
            _buildTimeSection(),
            SizedBox(height: 24.h),
            _buildDescription(),
            SizedBox(height: 24.h),
            _buildProductSection(),
            SizedBox(height: 32.h),
            _buildCompanySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      widget.happydeal.title,
      style: TextStyle(
        fontSize: 24.sp,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildPriceSection() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.happydeal.newPrice.toStringAsFixed(2)} €',
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              Text(
                '${widget.happydeal.oldPrice.toStringAsFixed(2)} €',
                style: TextStyle(
                  fontSize: 16.sp,
                  decoration: TextDecoration.lineThrough,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              'Économisez ${(widget.happydeal.oldPrice - widget.happydeal.newPrice).toStringAsFixed(2)} €',
              style: TextStyle(
                color: Colors.red[700],
                fontWeight: FontWeight.bold,
                fontSize: 14.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSection() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10.r,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: Colors.blue[800], size: 24.w),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getRemainingTime(),
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Du ${_formatDateTime(widget.happydeal.startDate)} au ${_formatDateTime(widget.happydeal.endDate)}',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Text(
      widget.happydeal.description,
      style: TextStyle(
        fontSize: 16.sp,
        color: Colors.black87,
        height: 1.5,
      ),
    );
  }

  Widget _buildProductSection() {
    return FutureBuilder<Product?>(
      future: _productFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final product = snapshot.data!;
        bool hasValidImage = product.variants.isNotEmpty && 
                           product.variants.first.images.isNotEmpty &&
                           product.variants.first.images.first.isNotEmpty;

        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ModernProductDetailPage(product: product),
            ),
          ),
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 10.r,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.r),
                  child: hasValidImage
                      ? Image.network(
                      product.variants.first.images.first,
                      width: 80.w,
                      height: 80.h,
                      fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80.w,
                            height: 80.h,
                            color: Colors.grey[200],
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.grey[400],
                              size: 30.w,
                            ),
                          ),
                        )
                      : Container(
                          width: 80.w,
                          height: 80.h,
                          color: Colors.grey[200],
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.grey[400],
                            size: 30.w,
                          ),
                    ),
                  ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Voir le produit',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.w500,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    color: Colors.blue[800], size: 16.w),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompanySection() {
    bool hasValidLogo = widget.happydeal.companyLogo.isNotEmpty && 
                       (widget.happydeal.companyLogo.startsWith('http://') || 
                        widget.happydeal.companyLogo.startsWith('https://'));

        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailsEntreprise(
                entrepriseId: widget.happydeal.companyId,
              ),
            ),
          ),
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 10.r,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24.r,
                  backgroundColor: Colors.blue[700],
                  child: CircleAvatar(
                    radius: 22.r,
                backgroundImage: hasValidLogo
                    ? NetworkImage(widget.happydeal.companyLogo)
                        : null,
                    backgroundColor: Colors.white,
                child: !hasValidLogo
                        ? Icon(Icons.business,
                            color: Colors.blue[700], size: 20.w)
                        : null,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
              child: Text(
                widget.happydeal.companyName,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    color: Colors.grey[400], size: 16.w),
              ],
            ),
          ),
    );
  }
}
