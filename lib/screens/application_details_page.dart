import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/widgets/app_bar/custom_app_bar.dart';
import 'package:intl/intl.dart';

class ApplicationDetailsPage extends StatefulWidget {
  final DocumentSnapshot application;

  const ApplicationDetailsPage({
    super.key,
    required this.application,
  });

  @override
  State<ApplicationDetailsPage> createState() => _ApplicationDetailsPageState();
}

class _ApplicationDetailsPageState extends State<ApplicationDetailsPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        // Attendre que le clavier soit complètement ouvert
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if ((widget.application.data() as Map<String, dynamic>)
        .containsKey('userUnreadMessages')) {
      FirebaseFirestore.instance
          .collection('applications')
          .doc(widget.application.id)
          .update({'userUnreadMessages': false});
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      resizeToAvoidBottomInset: true,
      appBar: const CustomAppBar(
        align: Alignment.center,
        title: 'Candidature',
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildApplicationHeader(),
            Expanded(
              child: _buildMessagesSection(),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationHeader() {
    final status = widget.application['status'];
    final statusColor = _getStatusColor(status);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Hero(
                tag: 'company_logo_${widget.application.id}',
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image:
                          NetworkImage(widget.application['companyLogo'] ?? ''),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(20),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.application['jobTitle'] ?? 'Titre inconnu',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.application['companyName'] ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today, size: 18, color: Colors.grey[800]),
                const SizedBox(width: 12),
                Text(
                  'Postuler le ${_formatDate(widget.application['appliedAt'])}',
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getStatusIcon(status), size: 18, color: statusColor),
                const SizedBox(width: 12),
                Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
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
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('applications')
                  .doc(widget.application.id)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                // Scroll to bottom after messages are loaded
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController
                        .jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message =
                        messages[index].data() as Map<String, dynamic>;
                    final isUserMessage = message['senderId'] ==
                        FirebaseAuth.instance.currentUser?.uid;

                    return _buildMessageBubble(
                      message: message['content'],
                      timestamp: message['timestamp'],
                      isUser: isUserMessage,
                    );
                  },
                );
              },
            ),
          ),
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
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: 'Votre message...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  fillColor: Colors.grey[50],
                  filled: true,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(100),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.blue[600],
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_forward),
              color: Colors.white,
              onPressed: () async {
                if (_messageController.text.trim().isEmpty) return;

                final userId = FirebaseAuth.instance.currentUser?.uid;
                if (userId == null) return;

                await FirebaseFirestore.instance
                    .collection('applications')
                    .doc(widget.application.id)
                    .collection('messages')
                    .add({
                  'content': _messageController.text.trim(),
                  'timestamp': Timestamp.now(),
                  'senderId': userId,
                  'read': false,
                });

                await FirebaseFirestore.instance
                    .collection('applications')
                    .doc(widget.application.id)
                    .update({
                  'lastUpdate': Timestamp.now(),
                  'lastMessageSenderId': userId,
                  'companyUnreadMessages': true,
                });

                _messageController.clear();
                _focusNode.unfocus();
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Envoyé':
        return Colors.blue;
      case 'En cours':
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

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Envoyé':
        return Icons.send_outlined;
      case 'Accepté':
        return Icons.check_circle_outline;
      case 'Refusé':
        return Icons.cancel_outlined;
      case 'En cours':
        return Icons.hourglass_empty;
      case 'Demande d\'infos':
        return Icons.info_outline;
      default:
        return Icons.help_outline;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
