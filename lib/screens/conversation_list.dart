import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/conversation.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/screens/conversation_detail.dart';
import 'package:provider/provider.dart';

class ConversationsListScreen extends StatelessWidget {
  final String userId;

  const ConversationsListScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final conversationService = Provider.of<ConversationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey[300],
            height: 1.0,
          ),
        ),
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
                    .collection('companys')
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
                  final String companyName = userData['name'] ?? 'Inconnu';
                  final String profilePicUrl = userData['logo'] ?? '';

                  final isUnread = conversation.unreadCount > 0 &&
                      conversation.unreadBy == userId;

                  return Column(
                    children: [
                      Container(
                          color: isUnread ? Colors.grey[100] : Colors.white,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            leading: CircleAvatar(
                              radius:
                                  25, // Réduire légèrement la taille de l'avatar
                              backgroundImage: profilePicUrl.isNotEmpty
                                  ? NetworkImage(profilePicUrl)
                                  : null,
                              child: profilePicUrl.isEmpty
                                  ? Text(companyName[0],
                                      style: const TextStyle(fontSize: 18))
                                  : null,
                            ),
                            title: Text(
                              companyName,
                              style: TextStyle(
                                fontWeight: isUnread
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
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
                            trailing: Column(
                              mainAxisSize: MainAxisSize
                                  .min, // Utiliser le minimum d'espace vertical
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
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ConversationDetailScreen(
                                    conversationId: conversation.id,
                                    otherUserName: companyName,
                                  ),
                                ),
                              );
                            },
                          )),
                      Divider(height: 1, color: Colors.grey[300]),
                    ],
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
