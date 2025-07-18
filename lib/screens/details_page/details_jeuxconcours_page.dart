import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/classes/contest.dart';
import 'package:happy/classes/post.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/widgets/company_info_card.dart';
import 'package:happy/widgets/share_confirmation_dialog.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ParticipationDialog extends StatefulWidget {
  final Contest contest;
  final String userId;

  const ParticipationDialog({
    required this.contest,
    required this.userId,
    super.key,
  });

  @override
  State<ParticipationDialog> createState() => _ParticipationDialogState();
}

class _ParticipationDialogState extends State<ParticipationDialog> {
  bool _acceptedConditions = false;
  bool _isLoading = false;

  Future<void> _participate() async {
    if (!_acceptedConditions) return;

    setState(() => _isLoading = true);

    try {
      // Vérifier si l'utilisateur a déjà participé
      final participantSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.contest.id)
          .collection('participants')
          .where('userId', isEqualTo: widget.userId)
          .get();

      if (participantSnapshot.docs.isNotEmpty) {
        if (!mounted) return;
        // On ferme d'abord le dialog même en cas d'erreur "déjà participé"
        Navigator.of(context).pop(false);
        throw 'Vous avez déjà participé à ce concours';
      }

      final participant = Participant(
        userId: widget.userId,
        participationDate: DateTime.now(),
      );

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final contestRef = FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.contest.id);

        final contestDoc = await transaction.get(contestRef);
        if (!contestDoc.exists) throw 'Concours introuvable';

        final currentParticipants =
            contestDoc.data()?['participantsCount'] ?? 0;
        final totalWinners = widget.contest.rewards.fold<int>(
          0,
          (sum, reward) => sum + reward.winnersCount,
        );
        if (currentParticipants >= totalWinners * 100) {
          throw 'Le concours est complet';
        }

        transaction.set(
          contestRef.collection('participants').doc(),
          participant.toMap(),
        );

        transaction.update(contestRef, {
          'participantsCount': FieldValue.increment(1),
        });
      });

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    } finally {
      setState(() => _isLoading = false);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Participation enregistrée avec succès !'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Règlement du concours',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conditions générales :',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Âge minimum requis : ${widget.contest.conditions.minimumAge} ans\n'
                      '• ${widget.contest.conditions.limitOnePerPerson ? "Une seule participation par personne" : "Participations multiples autorisées"}\n'
                      '${widget.contest.conditions.requirePurchase ? "• Achat minimum requis : ${widget.contest.conditions.minimumPurchaseAmount?.toStringAsFixed(2)}€\n" : ""}'
                      '${widget.contest.conditions.otherConditions != null ? "\nConditions supplémentaires :\n${widget.contest.conditions.otherConditions}" : ""}',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _acceptedConditions,
              onChanged: (value) {
                setState(() => _acceptedConditions = value!);
              },
              title: const Text("J'accepte le règlement"),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed:
                  _acceptedConditions && !_isLoading ? _participate : null,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : const Text('Participer'),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailsJeuxConcoursPage extends StatefulWidget {
  final Contest contest;
  final String currentUserId;

  const DetailsJeuxConcoursPage({
    required this.contest,
    required this.currentUserId,
    super.key,
  });

  @override
  State<DetailsJeuxConcoursPage> createState() =>
      _DetailsJeuxConcoursPageState();
}

class _DetailsJeuxConcoursPageState extends State<DetailsJeuxConcoursPage> {
  late Future<Company> companyFuture;
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = false;

  @override
  void initState() {
    super.initState();
    companyFuture = _fetchCompanyDetails(widget.contest.companyId);
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
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isLiked =
        context.watch<UserModel>().likedPosts.contains(widget.contest.id);
    final isContestOver = widget.contest.winner != null ||
        DateTime.now().isAfter(widget.contest.endDate);
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.grey[50],
            elevation: _showTitle ? 2 : 0,
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
            await context.read<UserModel>().handleLike(widget.contest);
            setState(() {});
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
          onPressed: () {
            _showShareOptions(context);
          },
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
              title: _showTitle
            ? Text(
                widget.contest.title,
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
                    widget.contest.image,
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(70),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildTimelineIndicator(),
                _buildGiftsList(),
                _buildDescriptionSection(),
                _buildOrganizer(),
                _buildParticipationSection(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(isContestOver, theme),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.contest.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.blue[800]),
              const SizedBox(width: 8),
              Text(
                "${formatDate(widget.contest.startDate)} - ${formatDate(widget.contest.endDate)}",
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineIndicator() {
    final now = DateTime.now();
    final total =
        widget.contest.endDate.difference(widget.contest.startDate).inDays;
    final elapsed = now.difference(widget.contest.startDate).inDays;
    final progress = (elapsed / total).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[800]!),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Temps restant: ${widget.contest.endDate.difference(now).inDays} jours',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftsList() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Récompenses',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...widget.contest.rewards.map((reward) => Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                              child: Container(
                                padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                        reward.description,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.euro, size: 16, color: Colors.green[700]),
                          const SizedBox(width: 4),
                Text(
                            'Valeur: ${reward.value.toStringAsFixed(2)}€',
                  style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                  ),
                ),
                          const SizedBox(width: 16),
                          Icon(Icons.people, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 4),
                          Text(
                            '${reward.winnersCount} gagnant${reward.winnersCount > 1 ? 's' : ''}',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
                    ],
                  ),
        ),
              )),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    final totalWinners = widget.contest.rewards.fold<int>(
      0,
      (sum, reward) => sum + reward.winnersCount,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'À propos du concours',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  Icons.people_outline,
                  'Participants',
                  '${widget.contest.participantsCount}',
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  Icons.emoji_events_outlined,
                  'Gagnants',
                  '$totalWinners',
                ),
                const Divider(height: 24),
                Text(
                  widget.contest.description,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue[800]),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: Colors.blue[800],
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
          CompanyInfoCard(
            name: widget.contest.companyName,
            logo: widget.contest.companyLogo,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailsEntreprise(
                        entrepriseId: widget.contest.companyId),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipationSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Conditions de participation',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildConditionItem(
                  'Âge minimum requis',
                  '${widget.contest.conditions.minimumAge} ans',
                  Icons.person_outline,
                ),
                const SizedBox(height: 12),
                _buildConditionItem(
                  'Participation',
                  widget.contest.conditions.limitOnePerPerson
                      ? 'Une seule participation par personne'
                      : 'Participations multiples autorisées',
                  Icons.repeat,
                ),
                if (widget.contest.conditions.requirePurchase) ...[
                  const SizedBox(height: 12),
                  _buildConditionItem(
                    'Achat requis',
                    'Montant minimum: ${widget.contest.conditions.minimumPurchaseAmount?.toStringAsFixed(2)}€',
                    Icons.shopping_cart_outlined,
                ),
                ],
                if (widget.contest.conditions.otherConditions?.isNotEmpty ?? false) ...[
                const SizedBox(height: 16),
                const Text(
                    'Conditions supplémentaires :',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                    widget.contest.conditions.otherConditions!,
                  style: TextStyle(
                      fontSize: 14,
                    height: 1.5,
                      color: Colors.grey[700],
                  ),
                ),
              ],
                if (widget.contest.conditions.rulesUrl?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () {
                      // Ajouter la logique pour ouvrir l'URL
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.description_outlined, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Consulter le règlement complet',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(Icons.open_in_new, size: 16, color: Colors.blue[700]),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: Colors.blue[700]),
        ),
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
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool isContestOver, ThemeData theme) {
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
            backgroundColor: isContestOver ? Colors.grey : theme.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: isContestOver
              ? null
              : () => showDialog(
                    context: context,
                    builder: (context) => ParticipationDialog(
                      contest: widget.contest,
                      userId: widget.currentUserId,
                    ),
                  ),
          child: Text(
            isContestOver ? 'Concours terminé' : 'Participer au jeu',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
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
                        companyName: widget.contest.companyName,
                        companyLogo: widget.contest.companyLogo,
                        id: widget.contest.id,
                        companyId: widget.contest.companyId,
                        timestamp: DateTime.now(),
                        type: 'contest',
                      ),
                      onConfirm: (String comment) async {
                        try {
                          Navigator.of(dialogContext).pop();

                          await FirebaseFirestore.instance
                              .collection('posts')
                              .doc(widget.contest.id)
                              .update({
                            'sharesCount': FieldValue.increment(1),
                          });

                          await users.sharePost(
                            widget.contest.id,
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
                                  companyName: widget.contest.companyName,
                                  companyLogo: widget.contest.companyLogo,
                                  id: widget.contest.id,
                                  companyId: widget.contest.companyId,
                                  timestamp: DateTime.now(),
                                  type: 'contest',
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
