import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/widgets/custom_app_bar.dart';
import 'package:intl/intl.dart';

class ApplicationDetailsPage extends StatelessWidget {
  final DocumentSnapshot application;

  const ApplicationDetailsPage({
    super.key,
    required this.application,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          child: _buildMessageInput(),
        ),
      ),
      appBar: const CustomAppBar(
        align: Alignment.center,
        title: 'Détails de la candidature',
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildApplicationHeader(),
            _buildStatusSection(),
            _buildMessagesSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue[700],
                radius: 30,
                child: CircleAvatar(
                  radius: 28,
                  backgroundImage:
                      NetworkImage(application['companyLogo'] ?? ''),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application['jobTitle'] ?? 'Titre inconnu',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      application['companyName'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Candidature envoyée le ${_formatDate(application['appliedAt'])}',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statut de la candidature',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatusTimeline(),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: _getStatusColor(application['status']),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              application['status'],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Messages',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('applications')
                .doc(application.id)
                .collection('messages')
                .orderBy('timestamp', descending: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data!.docs;

              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.message_outlined,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun message pour le moment',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message =
                      messages[index].data() as Map<String, dynamic>;
                  final isUserMessage = message['senderId'] ==
                      FirebaseAuth.instance.currentUser?.uid;

                  // Marquer le message comme lu si ce n'est pas un message de l'utilisateur
                  if (!isUserMessage && message['read'] == false) {
                    FirebaseFirestore.instance
                        .collection('applications')
                        .doc(application.id)
                        .collection('messages')
                        .doc(messages[index].id)
                        .update({'read': true});
                  }

                  return _buildMessageBubble(
                    message: message['content'],
                    timestamp: message['timestamp'],
                    isUser: isUserMessage,
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String message,
    required Timestamp timestamp,
    required bool isUser,
  }) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[700] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDateTime(timestamp),
              style: TextStyle(
                fontSize: 12,
                color: isUser ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return StatefulBuilder(
      builder: (context, setState) {
        final messageController = TextEditingController();

        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    hintText: 'Écrivez votre message...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                color: Colors.blue[700],
                onPressed: () async {
                  if (messageController.text.trim().isEmpty) return;

                  final userId = FirebaseAuth.instance.currentUser?.uid;
                  if (userId == null) return;

                  // Créer un nouveau document dans la sous-collection messages
                  await FirebaseFirestore.instance
                      .collection('applications')
                      .doc(application.id)
                      .collection('messages')
                      .add({
                    'content': messageController.text.trim(),
                    'timestamp': Timestamp.now(),
                    'senderId': userId,
                    'read': false,
                  });

                  // Mettre à jour le document principal
                  await FirebaseFirestore.instance
                      .collection('applications')
                      .doc(application.id)
                      .update({
                    'lastUpdate': Timestamp.now(),
                    'hasUnreadMessages': true,
                    'status': 'Nouveau Message',
                  });

                  messageController.clear();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Envoyé':
        return Colors.blue;
      case 'Nouveau Message':
        return Colors.orange;
      case 'Accepté':
        return Colors.green;
      case 'Refusé':
        return Colors.red;
      case 'Demande d\'infos':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(Timestamp timestamp) {
    return DateFormat('dd/MM/yyyy').format(timestamp.toDate());
  }

  String _formatDateTime(Timestamp timestamp) {
    return DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());
  }
}
