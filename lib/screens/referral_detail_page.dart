import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/classes/referral.dart';
import 'package:happy/widgets/cards/parrainage_card.dart';
import 'package:intl/intl.dart';

class ReferralDetailPage extends StatefulWidget {
  final String referralId;

  const ReferralDetailPage({super.key, required this.referralId});

  @override
  _ReferralDetailPageState createState() => _ReferralDetailPageState();
}

class _ReferralDetailPageState extends State<ReferralDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetchData();
  }

  Future<Map<String, dynamic>> _fetchData() async {
    final referralDoc =
        await _firestore.collection('referrals').doc(widget.referralId).get();
    if (!referralDoc.exists) {
      throw Exception('Parrainage non trouvé');
    }

    final referralData = referralDoc.data() as Map<String, dynamic>;
    final postId = referralData['referralId'] as String?;

    if (postId == null) {
      throw Exception('ID du post non trouvé dans le parrainage');
    }

    final postDoc = await _firestore.collection('posts').doc(postId).get();
    if (!postDoc.exists) {
      throw Exception('Post non trouvé');
    }

    return {
      'referralData': referralData,
      'postData': postDoc.data() as Map<String, dynamic>,
      'postId': postId,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du parrainage',
            style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Text('Une erreur est survenue: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('Données non trouvées'));
          }

          final referralData =
              snapshot.data!['referralData'] as Map<String, dynamic>;
          final postData = snapshot.data!['postData'] as Map<String, dynamic>;
          final postId = snapshot.data!['postId'] as String;
          final currentUserId = _auth.currentUser?.uid;
          final isParrain = currentUserId == referralData['sponsorUid'];

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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (referralData['status'] != null)
                  _buildStatusSection(referralData['status']),
                const SizedBox(height: 24),
                _buildRewardSection(referralData, isParrain),
                const SizedBox(height: 24),
                _buildInfoSection('Informations du filleul', [
                  if (referralData['refereeName'] != null)
                    'Nom: ${referralData['refereeName']}',
                  if (referralData['refereeContact'] != null)
                    'Contact: ${referralData['refereeContact']}',
                  if (referralData['refereeContactType'] != null)
                    'Type de contact: ${referralData['refereeContactType']}',
                ]),
                const SizedBox(height: 24),
                _buildInfoSection('Informations du parrain', [
                  if (referralData['sponsorName'] != null)
                    'Nom: ${referralData['sponsorName']}',
                  if (referralData['sponsorEmail'] != null)
                    'Email: ${referralData['sponsorEmail']}',
                ]),
                const SizedBox(height: 24),
                if (referralData['message'] != null)
                  _buildInfoSection('Message', [referralData['message']]),
                const SizedBox(height: 24),
                if (referralData['timestamp'] != null)
                  _buildInfoSection('Détails du parrainage', [
                    'Date: ${DateFormat('dd/MM/yyyy HH:mm').format((referralData['timestamp'] as Timestamp).toDate())}',
                  ]),
                const SizedBox(height: 24),
                _buildMessagesSection(
                    referralData['messages'] as List<dynamic>? ?? []),
                const SizedBox(height: 24),
                _buildReferralCard(referral, currentUserId ?? ''),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusSection(String status) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(status), color: Colors.white),
          const SizedBox(width: 8),
          Text(
            'Statut: $status',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardSection(
      Map<String, dynamic> referralData, bool isParrain) {
    final reward = isParrain
        ? referralData['sponsorReward']
        : referralData['refereeReward'];
    if (reward == null || (reward is String && reward.isEmpty)) {
      return const SizedBox
          .shrink(); // Ne rien afficher si la récompense est null ou vide
    }
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isParrain
                  ? 'Votre récompense (Parrain)'
                  : 'Votre récompense (Filleul)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(reward.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<String> infos) {
    if (infos.isEmpty) {
      return const SizedBox.shrink(); // Ne rien afficher si la liste est vide
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...infos.map((info) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(info),
            )),
      ],
    );
  }

  Widget _buildMessagesSection(List<dynamic> messages) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Messages',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (messages.isEmpty)
          const Text('Aucun message')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index] as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message['senderType'] == 'company'
                            ? 'Entreprise'
                            : 'Vous',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (message['text'] != null) Text(message['text']),
                      if (message['timestamp'] != null)
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(
                              (message['timestamp'] as Timestamp).toDate()),
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Envoyé':
        return Colors.blue;
      case 'En cours':
        return Colors.orange;
      case 'Terminé':
        return Colors.green;
      case 'Archivé':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Envoyé':
        return Icons.send;
      case 'En cours':
        return Icons.hourglass_empty;
      case 'Terminé':
        return Icons.check_circle;
      case 'Archivé':
        return Icons.archive;
      default:
        return Icons.info;
    }
  }

  Widget _buildReferralCard(Referral referral, String currentUserId) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('companys').doc(referral.companyId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const Text(
              'Impossible de charger les informations de l\'entreprise');
        }

        final companyData = snapshot.data!.data() as Map<String, dynamic>;
        final companyLogo = companyData['logo'] as String? ?? '';
        final companyName = companyData['name'] as String? ?? '';

        return ParrainageCard(
          post: referral,
          currentUserId: currentUserId,
          companyLogo: companyLogo,
          companyName: companyName,
        );
      },
    );
  }
}
