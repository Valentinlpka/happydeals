import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/classes/event.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/widgets/company_info_card.dart';
import 'package:happy/widgets/share_confirmation_dialog.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DetailsEvenementPage extends StatefulWidget {
  final Event event;
  final String currentUserId;

  const DetailsEvenementPage({
    required this.event,
    required this.currentUserId,
    super.key,
  });

  @override
  State<DetailsEvenementPage> createState() => _DetailsEvenementPageState();
}

class _DetailsEvenementPageState extends State<DetailsEvenementPage> {
  late Future<Company> companyFuture;
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = false;

  @override
  void initState() {
    super.initState();
    companyFuture = _fetchCompanyDetails(widget.event.companyId);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 140 && !_showTitle) {
      setState(() => _showTitle = true);
    } else if (_scrollController.offset <= 140 && _showTitle) {
      setState(() => _showTitle = false);
    }
  }

  Future<Company> _fetchCompanyDetails(String companyId) async {
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('companys')
        .doc(companyId)
        .get();
    return Company.fromDocument(doc);
  }

  String formatDate(DateTime date) {
    return DateFormat('dd MMMM yyyy à HH:mm', 'fr_FR').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isLiked =
        context.watch<UserModel>().likedPosts.contains(widget.event.id);
    final isEventPassed = DateTime.now().isAfter(widget.event.eventEndDate);

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildAppBar(isLiked, _showTitle),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildTimelineIndicator(),
                _buildEventDetails(),
                _buildDescriptionSection(),
                _buildOrganizer(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(isEventPassed),
    );
  }

  Widget _buildAppBar(bool isLiked, bool showTitle) {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.grey[50],
      elevation: showTitle ? 2 : 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.red : Colors.black,
            ),
          ),
          onPressed: () async {
            try {
              await context.read<UserModel>().handleLike(widget.event);
              if (mounted) setState(() {});
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur lors du like: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.share, color: Colors.black),
          ),
          onPressed: () => _showShareOptions(context),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: showTitle
            ? Text(
                widget.event.title,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              widget.event.photo,
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.event.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Text(
              widget.event.category,
              style: TextStyle(
                color: Colors.orange[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineIndicator() {
    final now = DateTime.now();
    final isEventPassed = now.isAfter(widget.event.eventEndDate);
    final daysRemaining = widget.event.eventDate.difference(now).inDays;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isEventPassed ? Colors.red[50] : Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEventPassed ? Colors.red[200]! : Colors.blue[200]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time,
              color: isEventPassed ? Colors.red[700] : Colors.blue[700],
            ),
            const SizedBox(width: 8),
            Text(
              isEventPassed
                  ? 'Événement terminé'
                  : now.isAfter(widget.event.eventDate)
                      ? 'Événement en cours'
                      : 'Dans $daysRemaining jours',
              style: TextStyle(
                color: isEventPassed ? Colors.red[700] : Colors.blue[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventDetails() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          children: [
            _buildInfoRow(
              Icons.calendar_today,
              'Début',
              formatDate(widget.event.eventDate),
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.calendar_today,
              'Fin',
              formatDate(widget.event.eventEndDate),
            ),
            const Divider(height: 24),
            _buildLocationInfoRow(
              Icons.location_on,
              'Lieu',
              widget.event.address,
              widget.event.city,
            ),
            if (widget.event.maxAttendees > 0) ...[
              const Divider(height: 24),
              _buildInfoRow(
                Icons.people,
                'Participants',
                '${widget.event.attendeeCount}/${widget.event.maxAttendees}',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue[800]),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationInfoRow(
      IconData icon, String label, String address, String city) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blue[800]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                city,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.event.description,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizer() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Organisateur',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<Company>(
            future: companyFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return CompanyInfoCard(
                company: snapshot.data!,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailsEntreprise(
                      entrepriseId: widget.event.companyId,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isEventPassed) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isEventPassed ? Colors.grey : Colors.blue[800],
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: isEventPassed ? null : () => _showParticipationDialog(),
          child: Text(
            isEventPassed ? 'Événement terminé' : 'Je participe',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _showParticipationDialog() {
    // Implémenter la logique de participation
  }

  void _showShareOptions(BuildContext context) {
    final users = Provider.of<UserModel>(context, listen: false);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Partager sur mon profil'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return ShareConfirmationDialog(
                      post: Post(
                        id: widget.event.id,
                        companyId: widget.event.companyId,
                        timestamp: DateTime.now(),
                        type: 'event',
                      ),
                      onConfirm: (String comment) async {
                        try {
                          Navigator.of(dialogContext).pop();

                          await FirebaseFirestore.instance
                              .collection('posts')
                              .doc(widget.event.id)
                              .update({
                            'sharesCount': FieldValue.increment(1),
                          });

                          await users.sharePost(
                            widget.event.id,
                            users.userId,
                            comment: comment,
                          );

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Publication partagée avec succès!'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur lors du partage: $e'),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                    );
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.message_outlined),
              title: const Text('Envoyer en message'),
              onTap: () {
                Navigator.pop(context);
                _showConversationsList(context, users);
              },
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  void _showConversationsList(BuildContext context, UserModel users) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    'Envoyer à...',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where(FieldPath.documentId,
                            whereIn: users.followedUsers)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                            child: Text('Une erreur est survenue'));
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final users = snapshot.data!.docs;

                      if (users.isEmpty) {
                        return const Center(
                          child: Text('Vous ne suivez aucun utilisateur'),
                        );
                      }

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final userData =
                              users[index].data() as Map<String, dynamic>;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage:
                                  NetworkImage(userData['image_profile'] ?? ''),
                            ),
                            title: Text(
                                '${userData['firstName']} ${userData['lastName']}'),
                            onTap: () async {
                              try {
                                final post = Post(
                                  id: widget.event.id,
                                  companyId: widget.event.companyId,
                                  timestamp: DateTime.now(),
                                  type: 'event',
                                );

                                await Provider.of<ConversationService>(context,
                                        listen: false)
                                    .sharePostInConversation(
                                  senderId: Provider.of<UserModel>(context,
                                          listen: false)
                                      .userId,
                                  receiverId: users[index].id,
                                  post: post,
                                );

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Message envoyé avec succès!'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Erreur lors de l\'envoi: $e'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
