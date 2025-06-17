import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/classes/conversation.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/screens/conversation_detail.dart';
import 'package:happy/widgets/app_bar/custom_app_bar.dart';
import 'package:happy/widgets/new_chat_bottom_sheet.dart';
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
      appBar: CustomAppBar(
        title: 'Conversations',
        align: Alignment.center,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const NewChatBottomSheet(),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('conversations')
            .where(Filter.or(
              Filter('particulierId', isEqualTo: widget.userId),
              Filter('otherUserId', isEqualTo: widget.userId),
              Filter('entrepriseId', isEqualTo: widget.userId),
              Filter('members', arrayContains: widget.userId),
            ))
            .orderBy('lastMessageTimestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print(snapshot.error);
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

          final conversations = snapshot.data!.docs
              .map((doc) => Conversation.fromFirestore(doc))
              .toList();

          if (conversations.isEmpty) {
            return const Center(child: Text('Aucune conversation'));
          }

          return ConversationsList(
            conversations: conversations,
            userId: widget.userId,
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('pinnedConversations')
          .snapshots(),
      builder: (context, snapshot) {
        // Trier les conversations : épinglées d'abord, puis par date
        final sortedConversations = List<Conversation>.from(conversations)
          ..sort((a, b) {
            // Vérifier si la conversation est épinglée dans Firestore
            final isAPinned =
                snapshot.data?.docs.any((doc) => doc.id == a.id) ?? a.isPinned;
            final isBPinned =
                snapshot.data?.docs.any((doc) => doc.id == b.id) ?? b.isPinned;

            if (isAPinned && !isBPinned) return -1;
            if (!isAPinned && isBPinned) return 1;
            return b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp);
          });

        return ListView.builder(
          itemCount: sortedConversations.length,
          itemBuilder: (context, index) {
            final conversation = sortedConversations[index];
            final isPinned =
                snapshot.data?.docs.any((doc) => doc.id == conversation.id) ??
                    conversation.isPinned;

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: ConversationListItem(
                key: ValueKey(conversation.id),
                conversation: conversation,
                userId: userId,
                isPinned: isPinned,
              ),
            );
          },
        );
      },
    );
  }
}

class ConversationListItem extends StatefulWidget {
  final Conversation conversation;
  final String userId;
  final bool isPinned;

  const ConversationListItem({
    super.key,
    required this.conversation,
    required this.userId,
    required this.isPinned,
  });

  @override
  State<ConversationListItem> createState() => _ConversationListItemState();
}

class _ConversationListItemState extends State<ConversationListItem> {
  bool _isDismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _loadConversationData(widget.conversation, widget.userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 80,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final data = snapshot.data!;
        return ConversationTile(
          conversation: widget.conversation,
          userData: data['userData'],
          adData: data['adData'],
          userId: widget.userId,
          isPinned: widget.isPinned,
          onDismissed: () {
            setState(() {
              _isDismissed = true;
            });
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _loadConversationData(
    Conversation conversation,
    String userId,
  ) async {
    String? otherUserId;

    if (conversation.adId != null) {
      otherUserId = conversation.sellerId;
    } else if (conversation.entrepriseId != null) {
      otherUserId = conversation.entrepriseId == userId
          ? conversation.particulierId
          : conversation.entrepriseId;
    } else {
      otherUserId = conversation.particulierId == userId
          ? conversation.otherUserId
          : conversation.particulierId;
    }

    if (otherUserId == null) {
      return {
        'userData': {
          'firstName': 'Utilisateur',
          'lastName': 'Inconnu',
        },
        'isCompany': false
      };
    }

    try {
      // Vérifier si c'est une association
      final associationDoc = await FirebaseFirestore.instance
          .collection('associations')
          .doc(otherUserId)
          .get();

      if (associationDoc.exists) {
        final associationData = associationDoc.data() as Map<String, dynamic>;
        return {
          'userData': {
            'firstName': associationData['name'],
            'lastName': '',
            'companyName': associationData['name'],
            'logo': associationData['logo'],
          },
          'adData': null,
          'isCompany': true,
          'isAssociation': true,
        };
      }

      // Vérifier si c'est une entreprise
      final companyDoc = await FirebaseFirestore.instance
          .collection('companys')
          .doc(otherUserId)
          .get();

      if (companyDoc.exists) {
        final companyData = companyDoc.data() as Map<String, dynamic>;
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

        if (!userDoc.exists) {
          return {
            'userData': {
              'firstName': companyData['name'],
              'lastName': '',
              'companyName': companyData['name'],
              'logo': companyData['logo'],
            },
            'adData': adDoc?.data() as Map<String, dynamic>?,
            'isCompany': true,
          };
        }

        final userData = userDoc.data() as Map<String, dynamic>;
        userData['companyName'] = companyData['name'];
        userData['logo'] = companyData['logo'];

        return {
          'userData': userData,
          'adData': adDoc?.data() as Map<String, dynamic>?,
          'isCompany': true,
        };
      }

      // C'est une conversation avec un particulier
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .get();

      if (!userDoc.exists) {
        return {
          'userData': {
            'firstName': 'Utilisateur',
            'lastName': 'Inconnu',
          },
          'isCompany': false
        };
      }

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
        'isCompany': false,
      };
    } catch (e) {
      return {
        'userData': {
          'firstName': 'Erreur',
          'lastName': 'Chargement',
        },
        'isCompany': false
      };
    }
  }
}

class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final Map<String, dynamic> userData;
  final Map<String, dynamic>? adData;
  final String userId;
  final VoidCallback onDismissed;
  final bool isPinned;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.userData,
    required this.userId,
    required this.onDismissed,
    required this.isPinned,
    this.adData,
  });

  @override
  Widget build(BuildContext context) {
    final bool isGroup = conversation.isGroup || userData['isGroup'] == true;
    String userName;
    String? profilePicUrl;
    bool isPro = false;

    if (isGroup) {
      userName = conversation.groupName ?? 'Groupe';
      profilePicUrl = conversation.groupImage ?? '';
    } else {
      String? otherUserId;
      if (conversation.entrepriseId != null) {
        otherUserId = conversation.entrepriseId == userId
            ? conversation.particulierId
            : conversation.entrepriseId;
      } else if (conversation.adId != null) {
        otherUserId = conversation.sellerId;
      } else {
        otherUserId = conversation.particulierId == userId
            ? conversation.otherUserId
            : conversation.particulierId;
      }

      final bool isWithCompany =
          otherUserId == conversation.entrepriseId && conversation.adId == null;
      isPro = isWithCompany;

      if (isWithCompany) {
        userName = userData['companyName'] ?? 'Entreprise';
        profilePicUrl = userData['logo'] ?? '';
      } else {
        if (conversation.adId != null) {
          userName =
              '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}';
          profilePicUrl = userData['image_profile'] ?? '';
        } else {
          userName =
              '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}';
          profilePicUrl = userData['image_profile'] ?? '';
        }
      }
    }

    final isUnread = isGroup
        ? (conversation.unreadBy as List?)?.contains(userId) ?? false
        : conversation.adId != null
            ? conversation.unreadCount > 0 &&
                conversation.unreadBy == userId &&
                conversation.lastMessageSenderId != userId
            : conversation.unreadCount > 0 && conversation.unreadBy == userId;

    return Dismissible(
      key: Key(conversation.id),
      direction: DismissDirection.horizontal,
      background: Container(
        color: isPinned ? Colors.orange : Colors.green,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Icon(
          isPinned ? Icons.push_pin : Icons.push_pin_outlined,
          color: Colors.white,
        ),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Épingler/Désépingler la conversation
          try {
            final conversationService =
                Provider.of<ConversationService>(context, listen: false);
            if (isPinned) {
              await conversationService.unpinConversation(
                  conversation.id, userId);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Conversation désépinglée'),
                  backgroundColor: Colors.orange,
                ),
              );
            } else {
              await conversationService.pinConversation(
                  conversation.id, userId);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Conversation épinglée'),
                  backgroundColor: Colors.green,
                ),
              );
            }
            onDismissed();
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          // Supprimer la conversation
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Confirmer la suppression'),
              content: const Text(
                  'Voulez-vous vraiment supprimer cette conversation ?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Supprimer'),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            try {
              final conversationService =
                  Provider.of<ConversationService>(context, listen: false);
              await conversationService.deleteConversationForUser(
                  conversation.id, userId);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Conversation supprimée'),
                  backgroundColor: Colors.green,
                ),
              );
              onDismissed();
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erreur: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      },
      child: Column(
        children: [
          Container(
            color: isUnread ? Colors.grey[100] : Colors.white,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _onTapConversation(context, userName),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          UserAvatar(
                            profilePicUrl: profilePicUrl ?? '',
                            userName: userName,
                            isAdSold: conversation.isAdSold,
                            isGroup: isGroup,
                            isPro: isPro,
                          ),
                          if (isPinned)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.push_pin,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ConversationTitle(
                              userName: userName,
                              adTitle: adData?['title'],
                              isUnread: isUnread,
                              isGroup: isGroup,
                              memberCount: isGroup
                                  ? (conversation.members?.length ?? 0)
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            MessagePreview(
                              message: conversation.lastMessage,
                              adThumbnail: adData?['photos']?.first,
                              adPrice: adData?['price']?.toDouble(),
                              isUnread: isUnread,
                            ),
                          ],
                        ),
                      ),
                      ConversationTrailing(
                        conversation: conversation,
                        isUnread: isUnread,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Divider(height: 1, color: Colors.grey[300]),
        ],
      ),
    );
  }

  Future<void> _onTapConversation(BuildContext context, String userName) async {
    if (conversation.isGroup) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConversationDetailScreen(
            conversationId: conversation.id,
            otherUserName: userName,
            isGroup: true,
          ),
        ),
      );
      return;
    }

    if (conversation.entrepriseId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConversationDetailScreen(
            conversationId: conversation.id,
            otherUserName: userName,
            isGroup: false,
          ),
        ),
      );
      return;
    }

    if (conversation.adId != null) {
      try {
        final adDoc = await FirebaseFirestore.instance
            .collection('ads')
            .doc(conversation.adId)
            .get();

        if (adDoc.exists) {
          final ad = await Ad.fromFirestore(adDoc);
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConversationDetailScreen(
                conversationId: conversation.id,
                otherUserName: userName,
                isGroup: false,
              ),
            ),
          );
        }
      } catch (e) {
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConversationDetailScreen(
              conversationId: conversation.id,
              otherUserName: userName,
              isGroup: false,
            ),
          ),
        );
      }
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationDetailScreen(
          conversationId: conversation.id,
          otherUserName: userName,
          isGroup: false,
        ),
      ),
    );
  }
}

// Widgets d'interface utilisateur extraits
class UserAvatar extends StatelessWidget {
  final String profilePicUrl;
  final String userName;
  final bool? isAdSold;
  final bool isGroup;
  final bool isPro;

  const UserAvatar({
    super.key,
    required this.profilePicUrl,
    required this.userName,
    this.isAdSold,
    this.isGroup = false,
    this.isPro = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: isGroup
              ? Colors.grey[300]
              : (isPro ? Colors.grey[500] : Colors.blue[500]),
          backgroundImage:
              profilePicUrl.isNotEmpty ? NetworkImage(profilePicUrl) : null,
          child: profilePicUrl.isEmpty
              ? Icon(
                  isGroup
                      ? Icons.group
                      : (isPro ? Icons.business : Icons.person),
                  size: 24,
                  color: Colors.white,
                )
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
  final bool isGroup;
  final int? memberCount;

  const ConversationTitle({
    super.key,
    required this.userName,
    required this.isUnread,
    this.adTitle,
    this.isGroup = false,
    this.memberCount,
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
        if (isGroup && memberCount != null)
          Text(
            '$memberCount membres',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          )
        else if (adTitle != null)
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
    if (difference.inDays < 30) {
      return 'Il y a ${(difference.inDays / 7).floor()} sem';
    }
    if (difference.inDays < 365) {
      return 'Il y a ${(difference.inDays / 30).floor()} mois';
    }
    return 'Il y a ${(difference.inDays / 365).floor()} an${difference.inDays >= 730 ? 's' : ''}';
  }
}
