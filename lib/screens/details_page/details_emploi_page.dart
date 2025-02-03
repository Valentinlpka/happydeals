import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/bottom_sheet_emploi.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DetailsEmploiPage extends StatefulWidget {
  final JobOffer post;
  final String individualName;
  final String individualPhoto;

  const DetailsEmploiPage({
    super.key,
    required this.post,
    required this.individualName,
    required this.individualPhoto,
  });

  @override
  State<DetailsEmploiPage> createState() => _DetailsEmploiPageState();
}

class _DetailsEmploiPageState extends State<DetailsEmploiPage> {
  void _showApplicationBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return ApplicationBottomSheet(
          jobOfferId: widget.post.id,
          companyId: widget.post.companyId,
          jobTitle: widget.post.title,
          companyName: widget.individualName,
          companyLogo: widget.individualPhoto,
          onApplicationSubmitted: _createApplication,
        );
      },
    );
  }

  Future<void> _createApplication() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance.collection('applications').add({
        'applicantId': userId,
        'companyId': widget.post.companyId,
        'jobOfferId': widget.post.id,
        'jobTitle': widget.post.title,
        'companyName': widget.individualName,
        'companyLogo': widget.individualPhoto,
        'status': 'Envoyé',
        'appliedAt': Timestamp.now(),
        'lastUpdate': Timestamp.now(),
        'messages': [],
        'hasUnreadMessages': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Candidature envoyée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'envoi de la candidature: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isLiked =
        context.watch<UserModel>().likedPosts.contains(widget.post.id);

    return Scaffold(
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(width: 0.4, color: Colors.black26)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.blue[800]),
              ),
              onPressed: _showApplicationBottomSheet,
              child: const Text('Contacter'),
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            elevation: 11,
            centerTitle: true,
            titleSpacing: 50,
            title: Container(
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color.fromARGB(115, 0, 0, 0),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.work_outline, color: Colors.white, size: 16),
                    Text(
                      "Offre de service",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
            backgroundColor: Colors.blue,
            shadowColor: Colors.grey,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : Colors.white,
                ),
                onPressed: () async {
                  await Provider.of<UserModel>(context, listen: false)
                      .handleLike(widget.post);
                  setState(() {});
                },
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.share, color: Colors.white),
              ),
            ],
            expandedHeight: 200,
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                widget.individualPhoto,
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.30),
                colorBlendMode: BlendMode.darken,
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.post.title,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.blue[800], size: 20),
                        const SizedBox(width: 10),
                        Text(widget.individualName,
                            style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            color: Colors.blue[800], size: 20),
                        const SizedBox(width: 10),
                        Text(widget.post.city,
                            style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            color: Colors.blue[800], size: 20),
                        const SizedBox(width: 10),
                        Text(
                          "Publié le ${formatDate(widget.post.timestamp)}",
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(color: Colors.grey[300]),
            ]),
          ),
          SliverFillRemaining(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Prestataire',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailsEntreprise(
                              entrepriseId: widget.post.companyId),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 27,
                          backgroundColor: Colors.blue[700],
                          child: CircleAvatar(
                            radius: 25,
                            backgroundImage:
                                NetworkImage(widget.individualPhoto),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.individualName,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Description du poste',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 10),
                  Text(widget.post.description),
                  const SizedBox(height: 20),
                  const Text('Missions',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 10),
                  Text(widget.post.missions),
                  const SizedBox(height: 20),
                  const Text('Profil recherché',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 10),
                  Text(widget.post.profile),
                  const SizedBox(height: 20),
                  const Text('Compétences',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.post.keywords
                        .map((keyword) => Chip(
                              label: Text(keyword),
                              backgroundColor: Colors.blue.withOpacity(0.1),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text('Avantages',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(widget.post.benefits),
                  const SizedBox(height: 20),
                  const Text('Pourquoi nous rejoindre',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(widget.post.whyJoin),
                  if (widget.post.salary != null) ...[
                    const SizedBox(height: 20),
                    const Text('Rémunération',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(widget.post.salary!),
                  ],
                  const SizedBox(height: 20),
                  const Text('Catégorie de service',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(widget.post.industrySector),
                  if (widget.post.contractType != null &&
                      widget.post.contractType!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Types de contrat',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(widget.post.contractType!),
                  ],
                  if (widget.post.workingHours != null) ...[
                    const SizedBox(height: 20),
                    const Text('Horaires de travail',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(widget.post.workingHours!),
                  ],
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
