import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/classes/conversation.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/screens/conversation_detail.dart';
import 'package:happy/widgets/custom_app_bar.dart';
import 'package:provider/provider.dart';

class ConversationsListScreen extends StatelessWidget {
  final String userId;

  const ConversationsListScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final conversationService = Provider.of<ConversationService>(context);

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Conversations',
      ),
      body: StreamBuilder<List<Conversation>>(
        stream: conversationService.getUserConversations(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucune conversation'));
          }

          final conversations = snapshot.data!;
          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final otherUserId = conversation.entrepriseId == userId
                  ? conversation.particulierId
                  : conversation.entrepriseId;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherUserId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }
                  if (userSnapshot.hasError || !userSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>;
                  final String userName =
                      '${userData['firstName']} ${userData['lastName']}';
                  final String profilePicUrl = userData['image_profile'] ?? '';

                  return FutureBuilder<DocumentSnapshot?>(
                    future: conversation.adId != null
                        ? FirebaseFirestore.instance
                            .collection('ads')
                            .doc(conversation.adId)
                            .get()
                        : Future.value(null),
                    builder: (context, adSnapshot) {
                      String? adTitle;
                      String? adThumbnail;
                      double? adPrice;

                      if (adSnapshot.hasData && adSnapshot.data != null) {
                        final adData =
                            adSnapshot.data!.data() as Map<String, dynamic>;
                        adTitle = adData['title'];
                        adPrice = (adData['price'] as num).toDouble();
                        final photos =
                            List<String>.from(adData['photos'] ?? []);
                        adThumbnail = photos.isNotEmpty ? photos[0] : null;
                      }

                      print('====== CONVERSATION LIST ITEM DEBUG ======');
                      print('Current user ID: $userId');
                      print(
                          'Conversation unreadCount: ${conversation.unreadCount}');
                      print('Conversation unreadBy: ${conversation.unreadBy}');
                      print(
                          'Conversation lastMessageSenderId: ${conversation.lastMessageSenderId}');

                      // Modification de la condition isUnread
                      final isUnread = conversation.unreadCount > 0 &&
                          conversation.unreadBy == userId; // Simplifié

                      print('Is unread? $isUnread');
                      print('==============================');

                      return Column(
                        children: [
                          Container(
                            color: isUnread ? Colors.grey[100] : Colors.white,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              leading: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 25,
                                    backgroundImage: profilePicUrl.isNotEmpty
                                        ? NetworkImage(profilePicUrl)
                                        : null,
                                    child: profilePicUrl.isEmpty
                                        ? Text(userName[0],
                                            style:
                                                const TextStyle(fontSize: 18))
                                        : null,
                                  ),
                                  if (conversation.isAdSold == true)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userName,
                                    style: TextStyle(
                                      fontWeight: isUnread
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (adTitle != null)
                                    Text(
                                      adTitle,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Row(
                                children: [
                                  if (adThumbnail != null)
                                    Container(
                                      width: 40,
                                      height: 40,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        image: DecorationImage(
                                          image: NetworkImage(adThumbnail),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          conversation.lastMessage,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isUnread
                                                ? Colors.black87
                                                : Colors.grey[600],
                                            fontWeight: isUnread
                                                ? FontWeight.w500
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        if (adPrice != null)
                                          Text(
                                            '${adPrice.toStringAsFixed(2)} €',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _formatRelativeTime(
                                        conversation.lastMessageTimestamp),
                                    style: TextStyle(
                                      color: isUnread
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (isUnread)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${conversation.unreadCount}',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                              onTap: () async {
                                if (conversation.adId != null) {
                                  final adDoc = await FirebaseFirestore.instance
                                      .collection('ads')
                                      .doc(conversation.adId)
                                      .get();
                                  if (adDoc.exists) {
                                    final ad = await Ad.fromFirestore(adDoc);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ConversationDetailScreen(
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
                                      builder: (context) =>
                                          ConversationDetailScreen(
                                        conversationId: conversation.id,
                                        otherUserName: userName,
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          Divider(height: 1, color: Colors.grey[300]),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
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
