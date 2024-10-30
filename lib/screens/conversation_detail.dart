import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/classes/conversation.dart';
import 'package:happy/classes/rating.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:provider/provider.dart';

class ConversationDetailScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final Ad? ad;

  const ConversationDetailScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    this.ad,
  });

  @override
  _ConversationDetailScreenState createState() =>
      _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isFirstLoad) {
        final conversationService =
            Provider.of<ConversationService>(context, listen: false);
        final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
        conversationService.markMessageAsRead(
            widget.conversationId, currentUserId);
        _isFirstLoad = false;
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.conversationId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final conversation = Conversation.fromFirestore(snapshot.data!);
          final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

          return Column(
            children: [
              if (widget.ad != null) _buildAdInfo(widget.ad!),
              if (conversation.isAdSold!)
                _buildRatingButton(conversation, currentUserId),
              _buildMessageList(currentUserId),
              _buildMessageInput(currentUserId),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            widget.otherUserName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          if (widget.ad != null)
            Text(widget.ad!.title, style: const TextStyle(fontSize: 12)),
        ],
      ),
      actions: [
        if (widget.ad != null && currentUserId == widget.ad!.userId)
          _buildSellActionButton(),
      ],
    );
  }

  Widget _buildSellActionButton() {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'markAsSold') {
          await _markAsSold();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'markAsSold',
          child: Text('Marquer comme vendu'),
        ),
      ],
    );
  }

  Future<void> _markAsSold() async {
    final conversationService =
        Provider.of<ConversationService>(context, listen: false);
    await conversationService.markAdAsSold(widget.conversationId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Article marqué comme vendu')),
    );
  }

  Widget _buildAdInfo(Ad ad) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey[200],
      child: Row(
        children: [
          if (ad.photos.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                ad.photos[0],
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ad.title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${ad.price.toStringAsFixed(2)} €',
                    style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(String currentUserId) {
    final conversationService =
        Provider.of<ConversationService>(context, listen: false);

    return Expanded(
      child: StreamBuilder<List<Message>>(
        stream:
            conversationService.getConversationMessages(widget.conversationId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucun message'));
          }

          final messages = snapshot.data!.reversed.toList();
          return ListView.builder(
            controller: _scrollController,
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              return MessageBubble(
                message: message,
                isMe: message.senderId == currentUserId,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMessageInput(String currentUserId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 6.0,
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Écrivez votre message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 10.0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          FloatingActionButton(
            onPressed: () => _sendMessage(currentUserId),
            mini: true,
            elevation: 0,
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  void _sendMessage(String currentUserId) {
    if (_messageController.text.isEmpty) return;

    final conversationService =
        Provider.of<ConversationService>(context, listen: false);
    conversationService.sendMessage(
      widget.conversationId,
      currentUserId,
      _messageController.text,
    );

    _messageController.clear();
    _scrollToBottom();
  }

  Future<void> _showRatingDialog(Conversation conversation,
      String currentUserId, bool isCurrentUserSeller) async {
    double rating = 5;
    final commentController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
                'Évaluer ${isCurrentUserSeller ? "l'acheteur" : "le vendeur"}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRatingStars(rating, (newRating) {
                  setState(() => rating = newRating);
                }),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    labelText: 'Commentaire',
                    hintText: 'Partagez votre expérience...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => _submitRating(
                  conversation,
                  currentUserId,
                  isCurrentUserSeller,
                  rating,
                  commentController.text,
                ),
                child: const Text('Envoyer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRatingStars(
      double currentRating, Function(double) onRatingChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return IconButton(
          icon: Icon(
            index < currentRating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 32,
          ),
          onPressed: () => onRatingChanged(index + 1.0),
        );
      }),
    );
  }

  Future<void> _submitRating(
    Conversation conversation,
    String currentUserId,
    bool isCurrentUserSeller,
    double rating,
    String comment,
  ) async {
    print('====== SUBMIT RATING DEBUG ======');
    print('Current User ID: $currentUserId');
    print('Is Current User Seller: $isCurrentUserSeller');
    print('Conversation Seller ID: ${conversation.sellerId}');
    print('Conversation Particulier ID: ${conversation.particulierId}');

    // Détermine le destinataire de l'évaluation
    String toUserId;
    if (isCurrentUserSeller) {
      // Si le vendeur évalue, le destinataire est l'acheteur (particulier)
      toUserId = conversation.particulierId;
      print('Seller rating buyer - toUserId: $toUserId');
    } else {
      // Si l'acheteur évalue, le destinataire est le vendeur
      toUserId = conversation.sellerId;
      print('Buyer rating seller - toUserId: $toUserId');
    }

    if (toUserId.isEmpty) {
      print('ERROR: toUserId is empty!');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Erreur: Impossible d\'identifier le destinataire de l\'évaluation')),
      );
      return;
    }

    final ratingData = Rating(
      id: '',
      fromUserId: currentUserId,
      toUserId: toUserId,
      adId: conversation.adId ?? '',
      adTitle: widget.ad?.title ?? '',
      rating: rating,
      comment: comment,
      createdAt: DateTime.now(),
      conversationId: conversation.id,
      isSellerRating: isCurrentUserSeller,
    );

    print('Rating Data:');
    print('From: ${ratingData.fromUserId}');
    print('To: ${ratingData.toUserId}');
    print('Rating: ${ratingData.rating}');
    print('Is Seller Rating: ${ratingData.isSellerRating}');

    try {
      await Provider.of<ConversationService>(context, listen: false)
          .submitRating(ratingData);

      print('Rating submitted successfully');
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Évaluation envoyée avec succès')),
      );
    } catch (e) {
      print('Error submitting rating: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'envoi de l\'évaluation: $e')),
      );
    }
    print('==============================');
  }

  Widget _buildRatingButton(Conversation conversation, String currentUserId) {
    print('====== RATING BUTTON DEBUG ======');
    print('Current User ID: $currentUserId');
    print('Seller ID: ${conversation.sellerId}');
    print('Particulier ID: ${conversation.particulierId}');

    final bool isCurrentUserSeller = currentUserId == conversation.sellerId;
    print('Is Current User Seller: $isCurrentUserSeller');

    final bool hasAlreadyRated = isCurrentUserSeller
        ? conversation.sellerHasRated
        : conversation.buyerHasRated;
    print('Has Already Rated: $hasAlreadyRated');
    print('==============================');

    if (hasAlreadyRated) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text(
          'Évaluation envoyée',
          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.star),
        label: Text(
            'Évaluer ${isCurrentUserSeller ? "l'acheteur" : "le vendeur"}'),
        onPressed: () =>
            _showRatingDialog(conversation, currentUserId, isCurrentUserSeller),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}

// Widgets auxiliaires
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const MessageBubble({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: isMe ? Theme.of(context).primaryColor : Colors.grey[300],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                message.content,
                style: TextStyle(color: isMe ? Colors.white : Colors.black87),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Text(
                _formatTimestamp(message.timestamp),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}';
  }
}
