import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/classes/conversation.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/widgets/share_post_message.dart';
import 'package:provider/provider.dart';

class ConversationDetailScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String? otherUserId; // Nouveau paramètre
  final Ad? ad;
  final bool isGroup;
  final bool isNewConversation; // Nouveau paramètre

  const ConversationDetailScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    this.otherUserId,
    this.ad,
    this.isGroup = false,
    this.isNewConversation = false,
  });

  @override
  _ConversationDetailScreenState createState() =>
      _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> {
  String? _actualConversationId;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isFirstLoad = true;
  Map<String, String> _memberNames = {};

  @override
  void initState() {
    super.initState();
    _actualConversationId =
        widget.isNewConversation ? null : widget.conversationId;
    if (!widget.isNewConversation && widget.conversationId.isNotEmpty) {
      _initializeChat();
    }
    if (widget.isGroup) {
      _loadGroupMembers();
    }
  }

  Future<void> _loadGroupMembers() async {
    final doc = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;
    if (data['members'] != null) {
      final members = data['members'] as List<dynamic>;
      setState(() {
        _memberNames = Map.fromEntries(
          members.map((member) {
            final memberData = member as Map<String, dynamic>;
            return MapEntry(
              memberData['id'] as String,
              memberData['name'] as String,
            );
          }),
        );
      });
    }
  }

  void _initializeChat() {
    if (widget.isNewConversation) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isFirstLoad && widget.conversationId.isNotEmpty) {
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
      body: Column(
        children: [
          if (widget.ad != null) _buildAdInfo(widget.ad!),
          _buildMessageList(FirebaseAuth.instance.currentUser?.uid ?? ""),
          _buildMessageInput(FirebaseAuth.instance.currentUser?.uid ?? ""),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            widget.otherUserName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          if (widget.isGroup)
            Text(
              '${_memberNames.length} membres',
              style: const TextStyle(fontSize: 12),
            )
          else if (widget.ad != null)
            Text(widget.ad!.title, style: const TextStyle(fontSize: 12)),
        ],
      ),
      actions: [
        if (widget.isGroup)
          IconButton(
            icon: const Icon(Icons.group),
            onPressed: _showGroupInfo,
          )
        else if (widget.ad != null &&
            FirebaseAuth.instance.currentUser?.uid == widget.ad!.userId)
          _buildSellActionButton(),
      ],
    );
  }

  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                widget.otherUserName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_memberNames.length} membres',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Membres du groupe',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _memberNames.length,
                  itemBuilder: (context, index) {
                    final entry = _memberNames.entries.elementAt(index);
                    return ListTile(
                      title: Text(entry.value),
                      leading: CircleAvatar(
                        child: Text(entry.value[0]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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
    if (widget.isNewConversation && _actualConversationId == null) {
      return const Expanded(
        child: Center(
          child: Text(
            'Envoyez un message pour démarrer la conversation',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: StreamBuilder<List<Message>>(
        stream: _actualConversationId != null
            ? Provider.of<ConversationService>(context, listen: false)
                .getConversationMessages(_actualConversationId!)
            : Stream.value([]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final messages = snapshot.data!.reversed.toList();
          if (messages.isEmpty) {
            return const Center(
              child: Text(
                'Aucun message',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            );
          }

          // Grouper les messages par date
          final groupedMessages = <DateTime, List<Message>>{};
          for (var message in messages) {
            final date = DateTime(
              message.timestamp.year,
              message.timestamp.month,
              message.timestamp.day,
            );
            groupedMessages.putIfAbsent(date, () => []).add(message);
          }

          final sortedDates = groupedMessages.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          return ListView.builder(
            controller: _scrollController,
            reverse: true,
            itemCount: sortedDates.length,
            itemBuilder: (context, dateIndex) {
              final date = sortedDates[dateIndex];
              final dateMessages = groupedMessages[date]!;

              return Column(
                children: [
                  _buildDateDivider(date),
                  ...dateMessages.map((message) => MessageBubble(
                        message: message,
                        isMe: message.senderId == currentUserId,
                        isGroup: widget.isGroup,
                        senderName: widget.isGroup && message.senderId != null
                            ? _memberNames[message.senderId] ?? 'Membre'
                            : null,
                        onEdit: message.senderId == currentUserId
                            ? () => _showEditDialog(message)
                            : null,
                        onDelete: message.senderId == currentUserId
                            ? () => _showDeleteConfirmation(message)
                            : null,
                      )),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showEditDialog(Message message) {
    final editController = TextEditingController(text: message.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le message'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
            hintText: 'Nouveau message...',
          ),
          maxLines: null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await Provider.of<ConversationService>(context, listen: false)
                    .editMessage(_actualConversationId!, message.id,
                        editController.text);
                if (!mounted) return;
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur: $e')),
                );
              }
            },
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Message message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le message'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce message ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await Provider.of<ConversationService>(context, listen: false)
                    .deleteMessage(_actualConversationId!, message.id);
                if (!mounted) return;
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDateDivider(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _formatDateDivider(date),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300])),
        ],
      ),
    );
  }

  String _formatDateDivider(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return "Aujourd'hui";
    } else if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return "Hier";
    } else if (now.difference(date).inDays < 7) {
      return _getWeekDay(date);
    } else {
      return _formatFullDate(date);
    }
  }

  String _formatFullDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = _getMonthName(date.month);
    final year = date.year != DateTime.now().year ? ' ${date.year}' : '';
    return '$day $month$year';
  }

  String _getMonthName(int month) {
    switch (month) {
      case 1:
        return 'janvier';
      case 2:
        return 'février';
      case 3:
        return 'mars';
      case 4:
        return 'avril';
      case 5:
        return 'mai';
      case 6:
        return 'juin';
      case 7:
        return 'juillet';
      case 8:
        return 'août';
      case 9:
        return 'septembre';
      case 10:
        return 'octobre';
      case 11:
        return 'novembre';
      case 12:
        return 'décembre';
      default:
        return '';
    }
  }

  String _getWeekDay(DateTime date) {
    switch (date.weekday) {
      case 1:
        return 'Lundi';
      case 2:
        return 'Mardi';
      case 3:
        return 'Mercredi';
      case 4:
        return 'Jeudi';
      case 5:
        return 'Vendredi';
      case 6:
        return 'Samedi';
      case 7:
        return 'Dimanche';
      default:
        return '';
    }
  }

  Widget _buildMessageInput(String currentUserId) {
    return SafeArea(
      child: Container(
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
      ),
    );
  }

  Future<void> _sendMessage(String currentUserId) async {
    if (_messageController.text.isEmpty) return;

    final conversationService =
        Provider.of<ConversationService>(context, listen: false);

    try {
      if (widget.isNewConversation && _actualConversationId == null) {
        // Création d'une nouvelle conversation avec le premier message
        _actualConversationId = await conversationService.sendFirstMessage(
          senderId: currentUserId,
          receiverId: widget.otherUserId!,
          content: _messageController.text,
          adId: widget.ad?.id,
        );

        // Mettre à jour l'état avec l'ID de la nouvelle conversation
        setState(() {
          _actualConversationId = _actualConversationId;
        });

        // Si c'est une nouvelle conversation, initialiser le chat après création
        _initializeChat();
      } else {
        // Envoi normal de message dans une conversation existante
        await conversationService.sendMessage(
          _actualConversationId ?? widget.conversationId,
          currentUserId,
          _messageController.text,
        );
      }

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'envoi du message: $e')),
      );
    }
  }
}

// Widgets auxiliaires
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool isGroup;
  final String? senderName;
  final Function? onEdit;
  final Function? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isGroup = false,
    this.senderName,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Message supprimé',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      );
    }
    if (message.type == 'shared_post') {
      return SharedPostMessage(
        message: message,
        isMe: isMe,
      );
    }
    if (message.type == 'system') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.content,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: isMe ? () => _showOptions(context) : null,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (isGroup && !isMe && senderName != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 4),
                  child: Text(
                    senderName!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: isMe ? Colors.blue[600] : Colors.grey[300],
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
                child: Text(
                  message.content,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              if (message.isEdited)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Modifié',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                child: Text(
                  _formatMessageTime(message.timestamp),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Modifier'),
            onTap: () {
              Navigator.pop(context);
              onEdit?.call();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Supprimer'),
            onTap: () {
              Navigator.pop(context);
              onDelete?.call();
            },
          ),
        ],
      ),
    );
  }
}

String _formatMessageTime(DateTime timestamp) {
  final hour = timestamp.hour.toString().padLeft(2, '0');
  final minute = timestamp.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
