import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/company.dart';
import 'package:happy/classes/contest.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
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
  int _currentStep = 0;
  bool _acceptedConditions = false;

  Future<void> _participate() async {
    try {
      print("Début de participation");
      final participant = Participant(
        userId: widget.userId,
        participationDate: DateTime.now(),
      );
      print("Participant créé: ${participant.toMap()}");

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        print("Début transaction");
        final contestRef = FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.contest.id);
        print("Contest ID: ${widget.contest.id}");

        final contestDoc = await transaction.get(contestRef);
        print("Doc exists: ${contestDoc.exists}");
        print("Doc data: ${contestDoc.data()}");

        if (!contestDoc.exists) throw 'Concours introuvable';

        final currentParticipants =
            contestDoc.data()?['participantsCount'] ?? 0;
        if (currentParticipants >=
            (widget.contest.maxParticipants > 0
                ? widget.contest.maxParticipants
                : 100)) {
          throw 'Le concours est complet';
        }
        print("Participants actuels: $currentParticipants");
        print("Max participants: ${contestDoc['maxParticipants']}");

        if (currentParticipants >= widget.contest.maxParticipants) {
          throw 'Le concours est complet';
        }

        transaction.set(
          contestRef.collection('participants').doc(),
          participant.toMap(),
        );
        print("Participant ajouté");

        transaction.update(contestRef, {
          'participantsCount': FieldValue.increment(1),
        });
        print("Compteur mis à jour");
      });
    } catch (e, stackTrace) {
      print("Erreur: $e");
      print("Stack trace: $stackTrace");
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 2) {
              setState(() => _currentStep++);
            } else {
              _participate();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.of(context).pop();
            }
          },
          steps: [
            Step(
              title: const Text('Règlement'),
              content: Column(
                children: [
                  Text(widget.contest.conditions),
                  CheckboxListTile(
                    value: _acceptedConditions,
                    onChanged: (value) {
                      setState(() => _acceptedConditions = value!);
                    },
                    title: const Text("J'accepte le règlement"),
                  ),
                ],
              ),
              isActive: _currentStep >= 0,
            ),
            Step(
              title: const Text('Confirmation'),
              content: const Text('Confirmez-vous votre participation ?'),
              isActive: _currentStep >= 1,
            ),
            Step(
              title: const Text('Terminé'),
              content: const Text('Votre participation est enregistrée !'),
              isActive: _currentStep >= 2,
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
    super.key,
    required this.currentUserId,
  });

  @override
  _DetailsJeuxConcoursPageState createState() =>
      _DetailsJeuxConcoursPageState();
}

class _DetailsJeuxConcoursPageState extends State<DetailsJeuxConcoursPage> {
  late Future<Company> companyFuture;

  @override
  void initState() {
    super.initState();
    companyFuture = _fetchCompanyDetails(widget.contest.companyId);
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

    return Scaffold(
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
            border: Border(
                top: BorderSide(
          width: 0.4,
          color: Colors.black26,
        ))),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: ElevatedButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.blue[800]),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => ParticipationDialog(
                  contest: widget.contest,
                  userId: widget.currentUserId,
                ),
              );
            },
            child: const Text('Participer au jeu'),
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
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: Colors.white,
                      size: 16,
                    ),
                    Text(
                      'Jeux concours',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            backgroundColor: Colors.blue,
            shadowColor: Colors.grey,
            leading: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : Colors.white,
                ),
                onPressed: () async {
                  await Provider.of<UserModel>(context, listen: false)
                      .handleLike(widget.contest);
                  setState(() {});
                },
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.share,
                  color: Colors.white,
                ),
              ),
            ],
            expandedHeight: 200,
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                widget.contest.giftPhoto,
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
                      (widget.contest.title),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            color: Colors.blue[800], size: 20),
                        const SizedBox(width: 10),
                        Text(
                          "${formatDate(widget.contest.startDate)} - ${formatDate(widget.contest.endDate)}",
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
                  const Text(
                    'Cadeau(x) mis en jeu',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...widget.contest.gifts.map((gift) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        height: 80,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              spreadRadius: 0,
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Image.network(
                              gift.imageUrl,
                              fit: BoxFit.cover,
                              height: 80,
                              width: 80,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                gift.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 20),
                  const Text(
                    'Description & Explication',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(widget.contest.description),
                  const SizedBox(height: 20),
                  const Text(
                    'Organisateur',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<Company>(
                    future: companyFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return const Text(
                            'Erreur de chargement des données de l\'entreprise');
                      }

                      Company company = snapshot.data!;

                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetailsEntreprise(
                                  entrepriseId: widget.contest.companyId),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.5),
                                spreadRadius: 0,
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundImage: NetworkImage(company.logo),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (company.name),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '(12 avis)',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.message,
                                    color: Colors.blue),
                                onPressed: () {
                                  // Implement messaging functionality
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Comment y participer ?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(widget.contest.howToParticipate),
                  const SizedBox(height: 20),
                  const Text(
                    'Condition de participation',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(widget.contest.conditions),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
