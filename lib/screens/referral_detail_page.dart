import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/widgets/cards/parrainage_card.dart';
import 'package:happy/widgets/custom_app_bar_back.dart';
import 'package:intl/intl.dart';

class ReferralDetailPage extends StatefulWidget {
  final String? referralId;

  const ReferralDetailPage({super.key, this.referralId});

  @override
  _ReferralDetailPageState createState() => _ReferralDetailPageState();
}

class _ReferralDetailPageState extends State<ReferralDetailPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Future<Map<String, dynamic>?> _dataFuture;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetchData();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _fetchData() async {
    if (widget.referralId == null) {
      return null;
    }

    try {
      final referralDoc =
          await _firestore.collection('referrals').doc(widget.referralId).get();
      if (!referralDoc.exists) {
        return null;
      }

      final referralData = referralDoc.data() as Map<String, dynamic>;

      // On vérifie si referralId est vide ou null
      final postId = referralData['referralId'] as String?;
      if (postId == null || postId.isEmpty) {
        return {
          'referralData': referralData,
          'postData': null,
          'postId': null,
        };
      }

      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        return {
          'referralData': referralData,
          'postData': null,
          'postId': null,
        };
      }

      return {
        'referralData': referralData,
        'postData': postDoc.data(),
        'postId': postId,
      };
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
      return null;
    }
  }

  Widget _buildStatusBadge(String status) {
    final Map<String, dynamic> statusConfig = {
      'Envoyé': {
        'color': Colors.blue[700],
        'icon': Icons.send_rounded,
        'background': Colors.blue.withOpacity(0.1),
      },
      'En cours': {
        'color': Colors.orange[700],
        'icon': Icons.timeline_rounded,
        'background': Colors.orange.withOpacity(0.1),
      },
      'Terminé': {
        'color': Colors.green[700],
        'icon': Icons.check_circle_rounded,
        'background': Colors.green.withOpacity(0.1),
      },
      'Archivé': {
        'color': Colors.grey[700],
        'icon': Icons.archive_rounded,
        'background': Colors.grey.withOpacity(0.1),
      },
    };

    final config = statusConfig[status] ?? statusConfig['Envoyé'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: config['background'],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config['icon'],
            size: 18,
            color: config['color'],
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: TextStyle(
              color: config['color'],
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: true,
            backgroundColor: Colors.white,
            collapsedBackgroundColor: Colors.white,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? Colors.blue[700])!.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor ?? Colors.blue[700],
                size: 24,
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isCompany) {
    return Align(
      alignment: isCompany ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isCompany ? Colors.grey[100] : Colors.blue[50],
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomLeft: isCompany ? const Radius.circular(0) : null,
            bottomRight: !isCompany ? const Radius.circular(0) : null,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCompany ? 'Entreprise' : 'Vous',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: isCompany ? Colors.grey[700] : Colors.blue[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message['text'] ?? '',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd/MM/yyyy HH:mm')
                  .format((message['timestamp'] as Timestamp).toDate()),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    if (widget.referralId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final message = {
        'text': _messageController.text.trim(),
        'timestamp': Timestamp.now(),
        'senderType':
            'user', // type 'user' pour les messages envoyés par l'utilisateur
        'senderUid': currentUser.uid,
      };

      await _firestore.collection('referrals').doc(widget.referralId).update({
        'messages': FieldValue.arrayUnion([message]),
        'lastUpdated': Timestamp.now(),
      });

      // Réinitialiser le contrôleur et rafraîchir les données
      _messageController.clear();
      setState(() {
        _dataFuture = _fetchData();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'envoi du message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      appBar: const CustomAppBarBack(title: 'Détails du parrainage'),
      backgroundColor: Colors.grey[50],
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun détail disponible',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          final referralData = data['referralData'] as Map<String, dynamic>;
          final currentUserId = _auth.currentUser?.uid;
          final isParrain = currentUserId == referralData['sponsorUid'];
          final hasMessages = referralData['messages'] != null;

          return Column(
            children: [
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (referralData['status'] != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: _buildStatusBadge(referralData['status']),
                          ),

                        // Carte des récompenses
                        if (referralData['sponsorReward'] != null ||
                            referralData['refereeReward'] != null)
                          _buildInfoCard(
                            title: 'Récompenses',
                            icon: Icons.card_giftcard_rounded,
                            iconColor: Colors.purple[700],
                            children: [
                              if (referralData['sponsorReward'] != null)
                                _buildRewardItem(
                                  'Parrain',
                                  referralData['sponsorReward'].toString(),
                                  isParrain,
                                ),
                              if (referralData['refereeReward'] != null)
                                _buildRewardItem(
                                  'Filleul',
                                  referralData['refereeReward'].toString(),
                                  !isParrain,
                                ),
                            ],
                          ),

                        // Informations du filleul
                        _buildInfoCard(
                          title: 'Informations du filleul',
                          icon: Icons.person_outline_rounded,
                          iconColor: Colors.green[700],
                          children: [
                            _buildInfoRow('Nom', referralData['refereeName']),
                            _buildInfoRow(
                                'Contact', referralData['refereeContact']),
                            _buildInfoRow('Type de contact',
                                referralData['refereeContactType']),
                          ],
                        ),

                        // Informations du parrain
                        _buildInfoCard(
                          title: 'Informations du parrain',
                          icon: Icons.supervised_user_circle_outlined,
                          iconColor: Colors.orange[700],
                          children: [
                            _buildInfoRow('Nom', referralData['sponsorName']),
                            _buildInfoRow(
                                'Email', referralData['sponsorEmail']),
                          ],
                        ),

                        // Messages
                        if (hasMessages)
                          _buildInfoCard(
                            title: 'Conversation',
                            icon: Icons.message_outlined,
                            iconColor: Colors.teal[700],
                            children: [
                              ...(referralData['messages'] as List<dynamic>)
                                  .map((message) => _buildMessageBubble(
                                      message as Map<String, dynamic>,
                                      message['senderType'] == 'company')),
                            ],
                          ),

                        // Offre de parrainage originale
                        if (data['postData'] != null &&
                            data['postId'] != null &&
                            currentUserId != null) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Offre de parrainage',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildOriginalReferral(
                              data['postData'] as Map<String, dynamic>,
                              data['postId'] as String,
                              currentUserId),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Zone de saisie de message
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(
                          maxHeight: 120,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: TextField(
                          controller: _messageController,
                          focusNode: _messageFocusNode,
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Écrivez votre message...',
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3476B2), Color(0xFF2A5D8F)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isLoading ? null : _sendMessage,
                          borderRadius: BorderRadius.circular(24),
                          child: _isLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRewardItem(String type, String reward, bool isCurrentUser) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.purple[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser ? Colors.purple[200]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCurrentUser ? Colors.purple[100] : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              type == 'Parrain'
                  ? Icons.person_outline
                  : Icons.person_add_outlined,
              size: 20,
              color: isCurrentUser ? Colors.purple[700] : Colors.grey[700],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color:
                        isCurrentUser ? Colors.purple[700] : Colors.grey[700],
                  ),
                ),
                Text(
                  reward,
                  style: TextStyle(
                    fontSize: 13,
                    color:
                        isCurrentUser ? Colors.purple[900] : Colors.grey[900],
                  ),
                ),
              ],
            ),
          ),
          if (isCurrentUser)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Votre gain',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.purple[700],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOriginalReferral(
      Map<String, dynamic> postData, String postId, String currentUserId) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          _firestore.collection('companys').doc(postData['companyId']).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Impossible de charger les détails de l\'offre',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
        }

        final companyData = snapshot.data!.data() as Map<String, dynamic>;
        final referral = Referral(
          id: postId,
          timestamp: (postData['timestamp'] as Timestamp).toDate(),
          title: postData['title'] ?? '',
          searchText: postData['searchText'] ?? '',
          description: postData['description'] ?? '',
          sponsorBenefit: postData['sponsorBenefit'] ?? '',
          refereeBenefit: postData['refereeBenefit'] ?? '',
          companyId: postData['companyId'] ?? '',
          image: postData['image'] ?? '',
          dateFinal: (postData['date_final'] as Timestamp).toDate(),
          views: postData['views'] ?? 0,
          likes: postData['likes'] ?? 0,
          likedBy: List<String>.from(postData['likedBy'] ?? []),
          commentsCount: postData['commentsCount'] ?? 0,
          comments: (postData['comments'] as List<dynamic>?)
                  ?.map((commentData) => Comment.fromMap(commentData))
                  .toList() ??
              [],
        );

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // En-tête de l'entreprise

              // Carte de parrainage
              ParrainageCard(
                post: referral,
                currentUserId: currentUserId,
                companyLogo: companyData['logo'] ?? '',
                companyName: companyData['name'] ?? '',
              ),
            ],
          ),
        );
      },
    );
  }
}

// Extension utilitaire pour les couleurs de statut
extension StatusColorExtension on String {
  Color getStatusColor() {
    switch (toLowerCase()) {
      case 'envoyé':
        return Colors.blue[700]!;
      case 'en cours':
        return Colors.orange[700]!;
      case 'terminé':
        return Colors.green[700]!;
      case 'archivé':
        return Colors.grey[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  IconData getStatusIcon() {
    switch (toLowerCase()) {
      case 'envoyé':
        return Icons.send_rounded;
      case 'en cours':
        return Icons.timeline_rounded;
      case 'terminé':
        return Icons.check_circle_rounded;
      case 'archivé':
        return Icons.archive_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }
}
