import 'package:flutter/material.dart';
import 'package:happy/screens/user_inofrmation.dart';
import '../screens/annuaire_page.dart';
import '../widgets/buttons_categories.dart';
import '../widgets/search_bar_home.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(
                16.0,
              ),
              children: [
                const Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.all(
                        Radius.circular(
                          50,
                        ),
                      ),
                      child: Image(
                        image: NetworkImage(
                            "https://media.licdn.com/dms/image/D4E03AQFMHad2UnXwvQ/profile-displayphoto-shrink_800_800/0/1675073860682?e=2147483647&v=beta&t=BZqJ7LPv-gg9Ehm-fVDmrl4QUi0_Oc2bHVjLuvpdIrc"),
                        height: 54,
                        width: 54,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        right: 12,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Salut Valentin !",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          "Petite phrase différente chaque jour",
                          style: TextStyle(
                            fontSize: 14,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 20.0,
                  ),
                  child: SizedBox(
                    width: size.width,
                    child: const SearchBarHome(),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                SizedBox(
                  height: 50,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const Annuaire(),
                                ),
                              );
                            },
                            child: const ButtonCategories(
                                Icons.people_outlined, 'Annuaire')),
                        const ButtonCategories(Icons.people_outlined, 'Deals'),
                        const ButtonCategories(
                            Icons.people_outlined, 'Action Spéciales'),
                        const ButtonCategories(
                            Icons.people_outlined, 'Brocante'),
                      ],
                    ),
                  ),
                ),
                // const DealsExpressCard(),
                // Divider(
                //   color: Colors.grey[300],
                // ),
                // const Padding(
                //   padding: EdgeInsets.all(5.0),
                //   child: Text(
                //     'Bons Plans à proximité',
                //     style: TextStyle(
                //       fontWeight: FontWeight.bold,
                //       fontSize: 18,
                //     ),
                //   ),
                // ),
                // const EvenementCard(),
                // const ConcoursCard(),
                // const EmploiCard(),
                const UserInformation(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
