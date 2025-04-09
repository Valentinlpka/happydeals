// Composants de l'interface
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/screens/reservation_screen.dart';
import 'package:happy/widgets/app_bar/custom_app_bar.dart';
import 'package:happy/widgets/company_info_card.dart';
import 'package:happy/widgets/share_confirmation_dialog.dart';
import 'package:intl/intl.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:provider/provider.dart';

import '../../providers/users_provider.dart';

class DetailsDealsExpress extends StatefulWidget {
  final ExpressDeal post;

  const DetailsDealsExpress({
    super.key,
    required this.post,
  });

  @override
  State<DetailsDealsExpress> createState() => _DetailsDealsExpressState();
}

class _DetailsDealsExpressState extends State<DetailsDealsExpress> {
  DateTime? selectedPickupTime;
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = false;
  late Future<Company> companyFuture;

  @override
  void initState() {
    super.initState();
    selectedPickupTime =
        widget.post.pickupTimes.isNotEmpty ? widget.post.pickupTimes[0] : null;
    _scrollController.addListener(_onScroll);
    companyFuture = _loadCompanyData();
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

  Future<Company> _loadCompanyData() async {
    final doc = await FirebaseFirestore.instance
        .collection('companys')
        .doc(widget.post.companyId)
        .get();
    return Company.fromDocument(doc);
  }

  String formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('dd/MM/yyyy');

    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      return 'Aujourd\'hui à ${timeFormat.format(dateTime)}';
    } else if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day + 1) {
      return 'Demain à ${timeFormat.format(dateTime)}';
    } else {
      return 'Le ${dateFormat.format(dateTime)} à ${timeFormat.format(dateTime)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLiked =
        context.watch<UserModel>().likedPosts.contains(widget.post.id);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Deal Express',
        align: Alignment.center,
        actions: [
          IconButton(
            icon: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? Colors.red : Colors.black,
            ),
            onPressed: () async {
              await context.read<UserModel>().handleLike(widget.post);
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _showShareOptions(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildPriceAndSavings(),
            _buildPickupTimeSelector(),
            _buildCompanySection(),
            _buildBasketContentSection(),
            _buildFAQSection(),
            _buildLocationSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(theme),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.post.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (widget.post.pickupTimes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.blue[800]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.post.pickupTimes.length == 1
                        ? "À récupérer ${formatDateTime(widget.post.pickupTimes[0])}"
                        : "${widget.post.pickupTimes.length} créneaux disponibles",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceAndSavings() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              const Text(
                'Prix',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.post.price}€',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          Column(
            children: [
              const Text(
                'Économie',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '-${(widget.post.price / 2).toStringAsFixed(2)}€',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPickupTimeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Créneaux de retrait disponibles:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 8),
          ...widget.post.pickupTimes.map((time) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: RadioListTile<DateTime>(
                  title: Text(formatDateTime(time)),
                  value: time,
                  groupValue: selectedPickupTime,
                  onChanged: (value) =>
                      setState(() => selectedPickupTime = value),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildCompanySection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Entreprise',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
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
                      entrepriseId: widget.post.companyId,
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

  Widget _buildBasketContentSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Que contient ce panier ?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Text(
              widget.post.content,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Questions fréquentes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildFAQItem(
            'Que contient un panier surprise',
            'Sur Happy Deals, les produits sont proposés à bas prix, mais en contrepartie… Surprise ! Les commerçants peuvent indiquer certains produits que vous pouvez retrouver dans votre panier mais sans certitude car ils ne peuvent pas prévoir leurs invendus.',
          ),
          const SizedBox(height: 8),
          _buildFAQItem(
            'Mon panier peut-il contenir des produits périmés ?',
            "Il faut distinguer la DLC et la DDM. La DLC est une date ferme, après cette date, le produit n'est plus consommable contrairement à la DDM qui elle, est une date indicative non contraignante, on peut donc vendre ces produits après la date.",
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Localisation',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  '63 Rue jules mousseron 59282 Douchy les mines',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => MapsLauncher.launchQuery(
                      '63 Rue jules mousseron 59282 Douchy les mines'),
                  icon: const Icon(Icons.navigation),
                  label: const Text('S\'y rendre'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.blue[600],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prix total',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${widget.post.price}€',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: selectedPickupTime == null
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReservationScreen(
                              deal: widget.post,
                              selectedPickupTime: selectedPickupTime!,
                            ),
                          ),
                        ),
                child: const Text(
                  'Réserver',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
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
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const ListTile(
                title: Text(
                  "Partager",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Partager sur mon profil'),
                onTap: () {
                  Navigator.pop(context);
                  final scaffoldContext = context;
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return ShareConfirmationDialog(
                        post: widget.post,
                        onConfirm: (String comment) async {
                          try {
                            Navigator.of(dialogContext).pop();

                            await FirebaseFirestore.instance
                                .collection('posts')
                                .doc(widget.post.id)
                                .update({
                              'sharesCount': FieldValue.increment(1),
                            });

                            await users.sharePost(
                              widget.post.id,
                              users.userId,
                              comment: comment,
                            );

                            if (scaffoldContext.mounted) {
                              ScaffoldMessenger.of(scaffoldContext)
                                  .showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Publication partagée avec succès!'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          } catch (e) {
                            if (scaffoldContext.mounted) {
                              ScaffoldMessenger.of(scaffoldContext)
                                  .showSnackBar(
                                SnackBar(
                                  content: Text('Erreur lors du partage: $e'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.red,
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
          ),
        );
      },
    );
  }

  void _showConversationsList(BuildContext context, UserModel users) {
    final conversationService =
        Provider.of<ConversationService>(context, listen: false);

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
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "Envoyer à...",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: StreamBuilder<List<String>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(users.userId)
                        .snapshots()
                        .map((doc) => List<String>.from(
                            doc.data()?['followedUsers'] ?? [])),
                    builder: (context, followedSnapshot) {
                      if (!followedSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final followedUsers = followedSnapshot.data!;

                      return FutureBuilder<List<DocumentSnapshot>>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .where(FieldPath.documentId, whereIn: followedUsers)
                            .get()
                            .then((query) => query.docs),
                        builder: (context, usersSnapshot) {
                          if (!usersSnapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          final usersList = usersSnapshot.data!;

                          return ListView.builder(
                            controller: scrollController,
                            itemCount: usersList.length,
                            itemBuilder: (context, index) {
                              final userData = usersList[index].data()
                                  as Map<String, dynamic>;
                              final userId = usersList[index].id;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: userData['image_profile'] !=
                                          null
                                      ? NetworkImage(userData['image_profile'])
                                      : null,
                                  child: userData['image_profile'] == null
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                title: Text(
                                    '${userData['firstName']} ${userData['lastName']}'),
                                onTap: () async {
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('posts')
                                        .doc(widget.post.id)
                                        .update({
                                      'sharesCount': FieldValue.increment(1),
                                    });

                                    await conversationService
                                        .sharePostInConversation(
                                      senderId: users.userId,
                                      receiverId: userId,
                                      post: widget.post,
                                    );
                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Post partagé avec succès')),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Erreur lors du partage: $e')),
                                    );
                                  }
                                },
                              );
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
