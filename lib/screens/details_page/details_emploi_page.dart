import 'package:flutter/material.dart';
import 'package:happy/classes/joboffer.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/screens/details_page/details_company_page.dart';
import 'package:happy/widgets/capitalize_first_letter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DetailsEmploiPage extends StatefulWidget {
  final JobOffer post;
  final String companyName;
  final String companyLogo;

  const DetailsEmploiPage({
    super.key,
    required this.post,
    required this.companyName,
    required this.companyLogo,
  });

  @override
  _DetailsEmploiPageState createState() => _DetailsEmploiPageState();
}

class _DetailsEmploiPageState extends State<DetailsEmploiPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
              border: Border(
                  top: BorderSide(
            width: 0.4,
            color: Colors.black26,
          ))),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(Colors.blue[800]),
                ),
                onPressed: () {
                  // Implement apply functionality
                },
                child: const Text('Postuler'),
              ),
            ),
          ),
        ),
        body: CustomScrollView(slivers: [
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
                    Icon(
                      Icons.work_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                    Text(
                      maxLines: 1,
                      "Offre d'emploi",
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
                      .handleLike(widget.post);
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
                widget.companyLogo,
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
                      capitalizeFirstLetter(widget.post.jobTitle),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.business, color: Colors.blue[800], size: 20),
                        const SizedBox(width: 10),
                        Text(
                          capitalizeFirstLetter(widget.companyName),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            color: Colors.blue[800], size: 20),
                        const SizedBox(width: 10),
                        Text(
                          widget.post.city,
                          style: const TextStyle(fontSize: 16),
                        ),
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
                const Text(
                  'Entreprise',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
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
                          backgroundImage: NetworkImage(widget.companyLogo),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              capitalizeFirstLetter(widget.companyName),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(widget.post.jobTitle),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Description du poste',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Text(widget.post.description),
                const SizedBox(height: 20),
                const Text(
                  'Profil recherché',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                Text(widget.post.profile),
                const SizedBox(height: 20),
                const Text(
                  'Compétences requises',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
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
                const SizedBox(height: 10),
                const Text(
                  'Pourquoi nous rejoindre ?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 10,
                  width: 10,
                ),
                Text(
                  widget.post.whyJoin,
                ),
                const SizedBox(
                  height: 20,
                  width: 10,
                ),
                const Text(
                  'Vos avantages',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 10,
                  width: 10,
                ),
                Text(
                  widget.post.benefits,
                ),
                const SizedBox(
                  height: 10,
                  width: 10,
                ),
              ],
            ),
          ))
        ]));
  }
}
