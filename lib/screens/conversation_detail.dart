import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:happy/classes/conversation.dart';
import 'package:happy/config/app_router.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/widgets/share_post_message.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

class ConversationDetailScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String? otherUserId;
  final bool isGroup;
  final bool isNewConversation;

  const ConversationDetailScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    this.otherUserId,
    this.isGroup = false,
    this.isNewConversation = false,
  });

  @override
  State<ConversationDetailScreen> createState() =>
      _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> {
  String? _actualConversationId;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isFirstLoad = true;
  Map<String, String> _memberNames = {};
  bool _shouldScrollToBottom = true;
  List<Message> _messages = [];
  StreamSubscription<List<Message>>? _messagesSubscription;
  bool _isLoadingMore = false;

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
    _scrollController.addListener(_handleScroll);
    _setupMessagesListener();

    // Ajouter un délai pour s'assurer que les messages sont chargés
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  void _setupMessagesListener() {
    if (_actualConversationId != null) {
      final conversationService =
          Provider.of<ConversationService>(context, listen: false);
      _messagesSubscription = conversationService
          .getConversationMessages(_actualConversationId!)
          .listen((messages) {
        if (mounted) {
          final wasAtBottom = _scrollController.hasClients &&
              _scrollController.position.pixels ==
                  _scrollController.position.maxScrollExtent;

          setState(() {
            _messages = messages;
            _shouldScrollToBottom = wasAtBottom;
          });

          if (wasAtBottom) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        }
      });
    }
  }

  void _handleScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      setState(() {
        _shouldScrollToBottom = true;
      });
    } else {
      setState(() {
        _shouldScrollToBottom = false;
      });
    }
  }

  void _scrollToBottom() {
    if (_shouldScrollToBottom && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _messagesSubscription?.cancel();
    super.dispose();
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_isFirstLoad && widget.conversationId.isNotEmpty) {
        final conversationService =
            Provider.of<ConversationService>(context, listen: false);
        final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

        // Vérifier si le service est initialisé
        if (!conversationService.isInitialized) {
          await conversationService.initializeForUser(currentUserId);
        }

        await conversationService.markMessageAsRead(
            widget.conversationId, currentUserId);
        _isFirstLoad = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildMessageList(FirebaseAuth.instance.currentUser?.uid ?? ""),
          _buildMessageInput(FirebaseAuth.instance.currentUser?.uid ?? ""),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            widget.otherUserName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17.sp,
              color: Colors.black87,
            ),
          ),
          if (widget.isGroup)
            Text(
              '${_memberNames.length} membres',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
            )
        ],
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (widget.isGroup)
          IconButton(
            icon: Icon(Icons.group, color: Colors.blue[700]),
            onPressed: _showGroupInfo,
          )
      ],
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

    if (_messages.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text(
            'Aucun message',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    // Trier les messages par date (du plus ancien au plus récent)
    final sortedMessages = List<Message>.from(_messages)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Grouper les messages par jour
    final groupedMessages = <DateTime, List<Message>>{};
    for (var message in sortedMessages) {
      final date = DateTime(
        message.timestamp.year,
        message.timestamp.month,
        message.timestamp.day,
      );
      groupedMessages.putIfAbsent(date, () => []).add(message);
    }

    // Trier les dates (du plus ancien au plus récent)
    final sortedDates = groupedMessages.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    return Expanded(
      child: Column(
        children: [
          if (_isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                if (scrollInfo is ScrollEndNotification &&
                    scrollInfo.metrics.pixels == 0 &&
                    !_isLoadingMore) {
                  _loadMoreMessages();
                }
                return true;
              },
              child: ListView.builder(
                controller: _scrollController,
                reverse: false,
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
                            senderName: widget.isGroup
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(String currentUserId) {
    return Container(
      padding: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            IconButton(
              onPressed: () {
                // TODO: Implémenter le sélecteur d'emoji
              },
              icon: Icon(
                Icons.emoji_emotions_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Écrivez votre message...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _messageController,
              builder: (context, value, child) {
                final hasText = value.text.trim().isNotEmpty;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: hasText
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: hasText ? () => _sendMessage(currentUserId) : null,
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.send_rounded,
                          color: hasText
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              },
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
        _actualConversationId = await conversationService.sendFirstMessage(
          senderId: currentUserId,
          receiverId: widget.otherUserId!,
          content: _messageController.text,
        );

        setState(() {
          _actualConversationId = _actualConversationId;
        });

        _initializeChat();
        _setupMessagesListener();
      } else {
        await conversationService.sendMessage(
          _actualConversationId ?? widget.conversationId,
          currentUserId,
          _messageController.text,
        );
      }

      _messageController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'envoi du message: $e')),
      );
    }
  }

  void _showGroupInfo() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
    final conversationService =
        Provider.of<ConversationService>(context, listen: false);

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
              // En-tête avec photo de groupe et nom
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('conversations')
                    .doc(widget.conversationId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final isCreator = data['creatorId'] == currentUserId;
                  final groupImage = data['groupImage'] as String?;
                  final groupName = data['groupName'] as String?;

                  return Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: groupImage != null
                                ? NetworkImage(groupImage)
                                : null,
                            child: groupImage == null
                                ? const Icon(Icons.group, size: 40)
                                : null,
                          ),
                          if (isCreator)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.camera_alt,
                                      color: Colors.white),
                                  onPressed: () => _changeGroupImage(),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            groupName ?? widget.otherUserName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isCreator)
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _changeGroupName(),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
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
                child: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('conversations')
                      .doc(widget.conversationId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final members =
                        List<Map<String, dynamic>>.from(data['members'] ?? []);
                    final isCreator = data['creatorId'] == currentUserId;

                    // Séparer les membres en entreprises et particuliers
                    final companies =
                        members.where((m) => m['type'] == 'company').toList();
                    final individuals =
                        members.where((m) => m['type'] != 'company').toList();

                    return ListView(
                      controller: scrollController,
                      children: [
                        if (companies.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'Entreprises',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          ...companies.map((member) => _buildMemberTile(
                                member: member,
                                isCreator: isCreator,
                                currentUserId: currentUserId,
                              )),
                          const Divider(),
                        ],
                        if (individuals.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'Particuliers',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          ...individuals.map((member) => _buildMemberTile(
                                member: member,
                                isCreator: isCreator,
                                currentUserId: currentUserId,
                              )),
                        ],
                      ],
                    );
                  },
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.exit_to_app),
                title: const Text('Quitter le groupe'),
                onTap: () => _leaveGroup(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberTile({
    required Map<String, dynamic> member,
    required bool isCreator,
    required String currentUserId,
  }) {
    final isCurrentUser = member['id'] == currentUserId;
    final isCompany = member['type'] == 'company';

    return FutureBuilder<DocumentSnapshot>(
      future: isCompany
          ? FirebaseFirestore.instance
              .collection('companys')
              .doc(member['id'])
              .get()
          : FirebaseFirestore.instance
              .collection('users')
              .doc(member['id'])
              .get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return ListTile(
            leading: CircleAvatar(
              child: Text(member['name'][0]),
            ),
            title: Text(member['name']),
            subtitle: Text(isCompany ? 'Entreprise' : 'Particulier'),
          );
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final imageUrl = isCompany
            ? userData['logo'] as String?
            : userData['image_profile'] as String?;

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
            child: imageUrl == null ? Text(member['name'][0]) : null,
          ),
          title: Text(member['name']),
          subtitle: Text(isCompany ? 'Entreprise' : 'Particulier'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCreator && !isCurrentUser)
                IconButton(
                  icon: const Icon(Icons.person_remove),
                  onPressed: () => _removeMember(member['id']),
                ),
              if (!isCurrentUser)
                IconButton(
                  icon: const Icon(Icons.person),
                  onPressed: () => _showMemberProfile(member),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _changeGroupImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        allowCompression: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) return;

      // Afficher un indicateur de chargement
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Lire et compresser l'image
      final File imageFile = File(file.path!);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? decodedImage = img.decodeImage(imageBytes);

      if (decodedImage == null) {
        throw Exception('Impossible de décoder l\'image');
      }

      // Redimensionner l'image si elle est trop grande
      const int maxSize = 800;
      final img.Image resizedImage = img.copyResize(
        decodedImage,
        width: decodedImage.width > maxSize ? maxSize : null,
        height: decodedImage.height > maxSize ? maxSize : null,
      );

      // Encoder l'image en JPEG avec une qualité de 80%
      final Uint8List compressedBytes =
          Uint8List.fromList(img.encodeJpg(resizedImage, quality: 80));

      // Télécharger l'image compressée vers Firebase Storage
      final String fileName =
          'group_images/${widget.conversationId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef =
          FirebaseStorage.instance.ref().child(fileName);
      final UploadTask uploadTask = storageRef.putData(compressedBytes);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Mettre à jour l'URL de l'image dans Firestore
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({'groupImage': downloadUrl});

      // Fermer le dialogue de chargement
      if (!mounted) return;
      Navigator.pop(context);

      // Afficher un message de succès
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Image de groupe mise à jour avec succès')),
      );
    } catch (e) {
      // Fermer le dialogue de chargement
      if (!mounted) return;
      Navigator.pop(context);

      // Afficher un message d'erreur
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur lors de la mise à jour de l\'image: $e')),
      );
    }
  }

  Future<void> _changeGroupName() async {
    final TextEditingController controller = TextEditingController(
      text: widget.otherUserName,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changer le nom du groupe'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Nouveau nom du groupe',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.conversationId)
            .update({'groupName': result});
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _removeMember(String memberId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer un membre'),
        content: const Text(
            'Êtes-vous sûr de vouloir retirer ce membre du groupe ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final conversationService =
            Provider.of<ConversationService>(context, listen: false);
        await conversationService.removeMemberFromGroup(
            widget.conversationId, memberId);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _showMemberProfile(Map<String, dynamic> member) async {
    if (member['type'] == 'company') {
      await AppRouter.navigateTo(
        context,
        AppRouter.companyDetails,
        arguments: member['id'],
      );
    } else {
      await AppRouter.navigateTo(
        context,
        AppRouter.userProfile,
        arguments: member['id'],
      );
    }
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter le groupe'),
        content: const Text('Êtes-vous sûr de vouloir quitter ce groupe ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final conversationService =
            Provider.of<ConversationService>(context, listen: false);
        final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
        await conversationService.removeMemberFromGroup(
            widget.conversationId, currentUserId);
        if (!mounted) return;
        Navigator.pop(context); // Retourner à l'écran précédent
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _showEditDialog(Message message) {
    final TextEditingController controller =
        TextEditingController(text: message.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le message'),
        content: TextField(
          controller: controller,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'Modifier votre message...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Le message ne peut pas être vide')),
                );
                return;
              }

              try {
                final conversationService =
                    Provider.of<ConversationService>(context, listen: false);
                await conversationService.editMessage(
                  _actualConversationId ?? widget.conversationId,
                  message.id,
                  controller.text.trim(),
                );
                if (!mounted) return;
                Navigator.pop(context);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur lors de la modification: $e')),
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
          TextButton(
            onPressed: () async {
              try {
                final conversationService =
                    Provider.of<ConversationService>(context, listen: false);
                await conversationService.deleteMessage(
                  _actualConversationId ?? widget.conversationId,
                  message.id,
                );
                if (!mounted) return;
                Navigator.pop(context);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur lors de la suppression: $e')),
                );
              }
            },
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateDivider(DateTime date) {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    String dateText;
    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      dateText = 'Aujourd\'hui';
    } else if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      dateText = 'Hier';
    } else {
      dateText = '${date.day}/${date.month}/${date.year}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: Colors.grey[300],
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              dateText,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: Colors.grey[300],
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMoreMessages() async {
    if (_messages.isEmpty || _isLoadingMore) return;

    final conversationService =
        Provider.of<ConversationService>(context, listen: false);
    setState(() => _isLoadingMore = true);

    final oldestMessage = _messages.last;
    final moreMessages = await conversationService.loadMoreMessages(
      widget.conversationId,
      oldestMessage.timestamp,
    );

    if (moreMessages.isNotEmpty) {
      setState(() {
        _messages.addAll(moreMessages);
      });
    }

    setState(() => _isLoadingMore = false);
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
        margin: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
        child: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              'Message supprimé',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12.sp,
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
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.90,
          ),
          margin: EdgeInsets.symmetric(vertical: 4.h, horizontal: 8.w),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (isGroup && !isMe && senderName != null)
                Padding(
                  padding: EdgeInsets.only(left: 12.w, bottom: 4.h),
                  child: Text(
                    senderName!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              Container(
                padding: EdgeInsets.symmetric(
                  vertical: 10.h,
                  horizontal: 14.w,
                ),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? LinearGradient(
                          colors: [Colors.blue[600]!, Colors.blue[400]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isMe ? null : Colors.grey[100],
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16.r),
                    topRight: Radius.circular(16.r),
                    bottomLeft: Radius.circular(isMe ? 16.r : 4.r),
                    bottomRight: Radius.circular(isMe ? 4.r : 16.r),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  message.content,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontSize: 14.sp,
                  ),
                ),
              ),
              if (message.isEdited)
                Padding(
                  padding: EdgeInsets.only(top: 2.h),
                  child: Text(
                    'Modifié',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10.sp,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.only(
                  top: 4.h,
                  left: 4.w,
                  right: 4.w,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatMessageTime(message.timestamp),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10.sp,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.isRead ? Icons.done_all : Icons.done,
                        size: 14,
                        color: message.isRead ? Colors.blue : Colors.grey[600],
                      ),
                    ],
                  ],
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
      builder: (context) => SafeArea(
        child: Column(
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
              leading: const Icon(Icons.delete, color: Colors.red),
              title:
                  const Text('Supprimer', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                onDelete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _formatMessageTime(DateTime timestamp) {
  final hour = timestamp.hour.toString().padLeft(2, '0');
  final minute = timestamp.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
