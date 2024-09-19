import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
  late Future<DocumentSnapshot> _referralFuture;

  @override
  void initState() {
    super.initState();
    _referralFuture =
        _firestore.collection('referrals').doc(widget.referralId).get();
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
      body: FutureBuilder<DocumentSnapshot>(
        future: _referralFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Text('Une erreur est survenue: ${snapshot.error}'));
          } else if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Parrainage non trouvé'));
          }

          final referralData = snapshot.data!.data() as Map<String, dynamic>;
          final currentUserId = _auth.currentUser?.uid;
          final isParrain = currentUserId == referralData['sponsorUid'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusSection(referralData['status']),
                const SizedBox(height: 24),
                _buildRewardSection(referralData, isParrain),
                const SizedBox(height: 24),
                _buildInfoSection('Informations du filleul', [
                  'Nom: ${referralData['refereeName']}',
                  'Contact: ${referralData['refereeContact']}',
                  'Type de contact: ${referralData['refereeContactType']}',
                ]),
                const SizedBox(height: 24),
                _buildInfoSection('Informations du parrain', [
                  'Nom: ${referralData['sponsorName']}',
                  'Email: ${referralData['sponsorEmail']}',
                ]),
                const SizedBox(height: 24),
                _buildInfoSection(
                    'Message', [referralData['message'] ?? 'Aucun message']),
                const SizedBox(height: 24),
                _buildInfoSection('Détails du parrainage', [
                  'Date: ${DateFormat('dd/MM/yyyy HH:mm').format((referralData['timestamp'] as Timestamp).toDate())}',
                ]),
                const SizedBox(height: 24),
                _buildMessagesSection(referralData['messages'] ?? []),
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
            Text(reward ?? 'Récompense non spécifiée'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<String> infos) {
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
              final message = messages[index];
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
                      Text(message['text']),
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
}
