import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/classes/conversation.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/screens/conversation_detail.dart';
import 'package:happy/widgets/custom_app_bar.dart';
import 'package:provider/provider.dart';

class ConversationsListScreen extends StatefulWidget {
  final String userId;

  const ConversationsListScreen({super.key, required this.userId});

  @override
  State<ConversationsListScreen> createState() =>
      _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  late final ConversationService _conversationService;

  @override
  void initState() {
    super.initState();
    _conversationService =
        Provider.of<ConversationService>(context, listen: false);
    _initializeService();
  }

  Future<void> _initializeService() async {
    if (!_conversationService.isInitialized) {
      await _conversationService.initializeForUser(widget.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Conversations',
        align: Alignment.center,
      ),
      body: Consumer<ConversationService>(
        builder: (context, service, _) {
          return StreamBuilder<List<Conversation>>(
            stream: service.getUserConversationsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Erreur lors du chargement des conversations'),
                      TextButton(
                        onPressed: _initializeService,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final conversations = snapshot.data!;
              if (conversations.isEmpty) {
                return const Center(child: Text('Aucune conversation'));
              }

              return ConversationsList(
                conversations: conversations,
                userId: widget.userId,
              );
            },
          );
        },
      ),
    );
  }
}

class ConversationsList extends StatelessWidget {
  final List<Conversation> conversations;
  final String userId;

  const ConversationsList({
    super.key,
    required this.conversations,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        return ConversationListItem(
          key: ValueKey(conversations[index].id),
          conversation: conversations[index],
          userId: userId,
        );
      },
    );
  }
}

class ConversationListItem extends StatelessWidget {
  final Conversation conversation;
  final String userId;

  const ConversationListItem({
    super.key,
    required this.conversation,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadConversationData(conversation, userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 80);
        }

        final data = snapshot.data!;
        return ConversationTile(
          conversation: conversation,
          userData: data['userData'],
          adData: data['adData'],
          userId: userId,
        );
      },
    );
  }

  Future<Map<String, dynamic>> _loadConversationData(
    Conversation conversation,
    String userId,
  ) async {
    final otherUserId = conversation.entrepriseId == userId
        ? conversation.particulierId
        : conversation.entrepriseId;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(otherUserId)
        .get();

    DocumentSnapshot? adDoc;
    if (conversation.adId != null) {
      adDoc = await FirebaseFirestore.instance
          .collection('ads')
          .doc(conversation.adId)
          .get();
    }

    return {
      'userData': userDoc.data() as Map<String, dynamic>,
      'adData': adDoc?.data() as Map<String, dynamic>?,
    };
  }
}

class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final Map<String, dynamic> userData;
  final Map<String, dynamic>? adData;
  final String userId;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.userData,
    required this.userId,
    this.adData,
  });

  @override
  Widget build(BuildContext context) {
    final otherUserId = conversation.entrepriseId == userId
        ? conversation.particulierId
        : conversation.entrepriseId;

    final bool shouldUseCompanyName =
        conversation.adId == null && otherUserId == conversation.entrepriseId;

    final String userName = shouldUseCompanyName
        ? userData['companyName'] ?? 'Entreprise'
        : '${userData['firstName']} ${userData['lastName']}';
    final String profilePicUrl = userData['image_profile'] ?? '';

    final isUnread =
        conversation.unreadCount > 0 && conversation.unreadBy == userId;

    return Column(
      children: [
        Container(
          color: isUnread ? Colors.grey[100] : Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            leading: UserAvatar(
              profilePicUrl: profilePicUrl,
              userName: userName,
              isAdSold: conversation.isAdSold,
            ),
            title: ConversationTitle(
              userName: userName,
              adTitle: adData?['title'],
              isUnread: isUnread,
            ),
            subtitle: MessagePreview(
              message: conversation.lastMessage,
              adThumbnail: adData?['photos']?.first,
              adPrice: adData?['price']?.toDouble(),
              isUnread: isUnread,
            ),
            trailing: ConversationTrailing(
              conversation: conversation,
              isUnread: isUnread,
            ),
            onTap: () => _onTapConversation(context, userName),
          ),
        ),
        Divider(height: 1, color: Colors.grey[300]),
      ],
    );
  }

  Future<void> _onTapConversation(BuildContext context, String userName) async {
    if (conversation.adId != null && adData != null) {
      // Créer un DocumentSnapshot manuellement
      final adDoc = await FirebaseFirestore.instance
          .collection('ads')
          .doc(conversation.adId)
          .get();

      if (!context.mounted) return;

      if (adDoc.exists) {
        final ad = await Ad.fromFirestore(adDoc);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConversationDetailScreen(
              conversationId: conversation.id,
              otherUserName: userName,
              ad: ad,
            ),
          ),
        );
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConversationDetailScreen(
            conversationId: conversation.id,
            otherUserName: userName,
          ),
        ),
      );
    }
  }
}

// Widgets d'interface utilisateur extraits
class UserAvatar extends StatelessWidget {
  final String profilePicUrl;
  final String userName;
  final bool? isAdSold;

  const UserAvatar({
    super.key,
    required this.profilePicUrl,
    required this.userName,
    this.isAdSold,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundImage:
              profilePicUrl.isNotEmpty ? NetworkImage(profilePicUrl) : null,
          child: profilePicUrl.isEmpty
              ? Text(userName[0], style: const TextStyle(fontSize: 18))
              : null,
        ),
        if (isAdSold == true)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 12),
            ),
          ),
      ],
    );
  }
}

class ConversationTitle extends StatelessWidget {
  final String userName;
  final String? adTitle;
  final bool isUnread;

  const ConversationTitle({
    super.key,
    required this.userName,
    required this.isUnread,
    this.adTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          userName,
          style: TextStyle(
            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (adTitle != null)
          Text(
            adTitle!,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
      ],
    );
  }
}

class MessagePreview extends StatelessWidget {
  final String message;
  final String? adThumbnail;
  final double? adPrice;
  final bool isUnread;

  const MessagePreview({
    super.key,
    required this.message,
    required this.isUnread,
    this.adThumbnail,
    this.adPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (adThumbnail != null)
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              image: DecorationImage(
                image: NetworkImage(adThumbnail!),
                fit: BoxFit.cover,
              ),
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isUnread ? Colors.black87 : Colors.grey[600],
                  fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              if (adPrice != null)
                Text(
                  '${adPrice!.toStringAsFixed(2)} €',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class ConversationTrailing extends StatelessWidget {
  final Conversation conversation;
  final bool isUnread;

  const ConversationTrailing({
    super.key,
    required this.conversation,
    required this.isUnread,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _formatRelativeTime(conversation.lastMessageTimestamp),
          style: TextStyle(
            color: isUnread ? Theme.of(context).primaryColor : Colors.grey[600],
            fontSize: 12,
          ),
        ),
        if (isUnread)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${conversation.unreadCount}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
      ],
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) return 'À l\'instant';
    if (difference.inMinutes < 60) return 'Il y a ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'Il y a ${difference.inHours} h';
    if (difference.inDays < 7) return 'Il y a ${difference.inDays} j';
    if (difference.inDays < 30)
      return 'Il y a ${(difference.inDays / 7).floor()} sem';
    if (difference.inDays < 365)
      return 'Il y a ${(difference.inDays / 30).floor()} mois';
    return 'Il y a ${(difference.inDays / 365).floor()} an${difference.inDays >= 730 ? 's' : ''}';
  }
}
