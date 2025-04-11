import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/bottom_sheet_emploi.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/widgets/company_info_card.dart';
import 'package:happy/widgets/share_confirmation_dialog.dart';
import 'package:provider/provider.dart';

class DetailsEmploiPage extends StatefulWidget {
  final JobOffer post;

  const DetailsEmploiPage({
    super.key,
    required this.post,
  });

  @override
  State<DetailsEmploiPage> createState() => _DetailsEmploiPageState();
}

class _DetailsEmploiPageState extends State<DetailsEmploiPage> {
  bool _isLoading = true;
  bool _hasApplied = false;
  final ScrollController _scrollController = ScrollController();
  bool _isStickyHeaderVisible = false;

  @override
  void initState() {
    super.initState();
    _checkApplicationStatus();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 100) {
      if (!_isStickyHeaderVisible) {
        setState(() => _isStickyHeaderVisible = true);
      }
    } else {
      if (_isStickyHeaderVisible) {
        setState(() => _isStickyHeaderVisible = false);
      }
    }
  }

  Future<void> _checkApplicationStatus() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _hasApplied = false;
      });
      return;
    }

    try {
      final applicationSnapshot = await FirebaseFirestore.instance
          .collection('applications')
          .where('applicantId', isEqualTo: userId)
          .where('jobOfferId', isEqualTo: widget.post.id)
          .get();

      setState(() {
        _hasApplied = applicationSnapshot.docs.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur lors de la vérification de la candidature: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showApplicationBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return ApplicationBottomSheet(
          jobOfferId: widget.post.id,
          companyId: widget.post.companyId,
          jobTitle: widget.post.title,
          onApplicationSubmitted: _createApplication,
        );
      },
    );
  }

  Future<void> _createApplication() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance.collection('applications').add({
        'applicantId': userId,
        'companyId': widget.post.companyId,
        'jobOfferId': widget.post.id,
        'jobTitle': widget.post.title,
        'status': 'Envoyé',
        'appliedAt': Timestamp.now(),
        'lastUpdate': Timestamp.now(),
        'messages': [],
        'hasUnreadMessages': false,
      });

      setState(() {
        _hasApplied = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Candidature envoyée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'envoi de la candidature: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLiked =
        context.watch<UserModel>().likedPosts.contains(widget.post.id);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: AnimatedOpacity(
          opacity: _isStickyHeaderVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            widget.post.title,
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                isLiked ? Icons.bookmark : Icons.bookmark_border,
                size: 20,
                color: isLiked ? Colors.blue[700] : Colors.grey[800],
              ),
            ),
            onPressed: () async {
              await Provider.of<UserModel>(context, listen: false)
                  .handleLike(widget.post);
            },
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.share_outlined, size: 20, color: Colors.grey[800]),
            ),
            onPressed: () => _showShareOptions(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête avec informations principales
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.title,
                        style: TextStyle(
                          fontSize: isMobile ? 24 : 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Badges d'information
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (widget.post.contractType != null)
                            _buildInfoChip(
                              Icons.work_outline,
                              widget.post.contractType!,
                              Colors.blue,
                            ),
                          if (widget.post.industrySector.isNotEmpty)
                            _buildInfoChip(
                              Icons.category_outlined,
                              widget.post.industrySector,
                              Colors.purple,
                            ),
                          if (widget.post.workplaceType.isNotEmpty)
                            _buildInfoChip(
                              Icons.business_outlined,
                              widget.post.workplaceType,
                              Colors.orange,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // CompanyInfoCard avec style amélioré
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance
                              .collection('companys')
                              .doc(widget.post.companyId)
                              .get(),
                          builder: (context, snapshot) {
                            if (_isLoading) {
                              return const SizedBox(
                                height: 80,
                                child: Center(
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            }
                            if (!snapshot.hasData) {
                              return const SizedBox(
                                height: 80,
                                child: Center(
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            }
                            final company =
                                Company.fromDocument(snapshot.data!);
                            return Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: CompanyInfoCard(
                                company: company,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DetailsEntreprise(
                                      entrepriseId: widget.post.companyId,
                                    ),
                                  ),
                                ),
                                isCompact: true,
                                showRating: false,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Informations clés
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informations clés',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildKeyInfoRow(
                        Icons.location_on_outlined,
                        'Localisation',
                        widget.post.city,
                      ),
                      _buildKeyInfoRow(
                        Icons.work_outline,
                        'Type de contrat',
                        widget.post.contractType ?? 'Non spécifié',
                      ),
                      if (widget.post.workingHours != null)
                        _buildKeyInfoRow(
                          Icons.access_time_outlined,
                          'Temps de travail',
                          widget.post.workingHours!,
                        ),
                      _buildKeyInfoRow(
                        Icons.euro_outlined,
                        'Salaire',
                        (widget.post.salary == null ||
                                widget.post.salary!.isEmpty)
                            ? 'À définir'
                            : widget.post.salary!,
                      ),
                      if (widget.post.industrySector.isNotEmpty)
                        _buildKeyInfoRow(
                          Icons.category_outlined,
                          'Catégorie',
                          widget.post.industrySector,
                        ),
                      if (widget.post.workplaceType.isNotEmpty)
                        _buildKeyInfoRow(
                          Icons.business_outlined,
                          'Type de lieu',
                          widget.post.workplaceType,
                        ),
                    ],
                  ),
                ),

                // Description du poste
                _buildSectionContainer(
                  'Description du poste',
                  widget.post.description,
                  isMobile,
                ),

                // Missions
                _buildSectionContainer(
                  'Missions',
                  widget.post.missions,
                  isMobile,
                ),

                // Profil recherché
                _buildSectionContainer(
                  'Profil recherché',
                  widget.post.profile,
                  isMobile,
                ),

                // Mots clés
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  margin: const EdgeInsets.only(top: 12),
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mots clés',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.post.keywords.map((keyword) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.indigo[50],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              keyword,
                              style: TextStyle(
                                color: Colors.indigo[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                // Avantages
                if (widget.post.benefits.isNotEmpty)
                  _buildSectionContainer(
                    'Avantages',
                    widget.post.benefits,
                    isMobile,
                  ),

                // Pourquoi nous rejoindre
                if (widget.post.whyJoin.isNotEmpty)
                  _buildSectionContainer(
                    'Pourquoi nous rejoindre',
                    widget.post.whyJoin,
                    isMobile,
                  ),
                // Padding pour éviter que le bouton flottant ne cache le contenu
                const SizedBox(height: 80),
              ],
            ),
          ),
          // Bouton flottant qui apparaît au scroll
          if (_isStickyHeaderVisible)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 10,
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: 12,
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.post.title,
                          style: TextStyle(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (!_hasApplied)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _showApplicationBottomSheet,
                          child: const Text(
                            'Postuler',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle,
                                  size: 16, color: Colors.green[700]),
                              const SizedBox(width: 8),
                              Text(
                                'Déjà postulé',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    final baseColor = color;
    final backgroundColor = Color.fromRGBO(
      baseColor.r.toInt(),
      baseColor.g.toInt(),
      baseColor.b.toInt(),
      0.1,
    );
    final borderColor = Color.fromRGBO(
      baseColor.r.toInt(),
      baseColor.g.toInt(),
      baseColor.b.toInt(),
      0.2,
    );
    final textColor = Color.fromRGBO(
      baseColor.r.toInt(),
      baseColor.g.toInt(),
      baseColor.b.toInt(),
      0.8,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: Colors.grey[700]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContainer(String title, String content, bool isMobile) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      margin: const EdgeInsets.only(top: 12),
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              height: 1.6,
              color: Colors.grey[800],
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
                        type: 'job',
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
                                  type: 'job',
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
