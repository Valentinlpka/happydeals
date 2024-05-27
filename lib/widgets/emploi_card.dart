import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:happy/screens/details_page/details_emploi_page.dart';

class EmploiCard extends StatelessWidget {
  const EmploiCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          shadowColor: Colors.grey,
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DetailsEmploiPage(),
                ),
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ClipRRect(
                            borderRadius:
                                const BorderRadius.all(Radius.circular(15)),
                            child: Container(
                              padding: const EdgeInsets.only(
                                  top: 3, bottom: 3, right: 7, left: 5),
                              decoration: const BoxDecoration(
                                color: Color.fromARGB(70, 0, 0, 0),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(
                                    Icons.event_note_outlined,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  Gap(5),
                                  Text(
                                    "Offre d'emploi",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.favorite,
                            color: Colors.red,
                          )
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  height: 160,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          const Row(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor: Colors.blue,
                                    child: CircleAvatar(
                                      radius: 28,
                                      backgroundImage: NetworkImage(
                                          'https://media.licdn.com/dms/image/C4D0BAQF1LJrX1nhcyA/company-logo_200_200/0/1630523580358/be_happy_services_logo?e=2147483647&v=beta&t=XH4UBtLR0ulhQvd1XKnpRgg-BrU0JrWZhcsAZf7c15I'),
                                    ),
                                  ),
                                  Gap(20),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Développeur Full Stack',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text('Be Happy - Douai')
                                    ],
                                  )
                                ],
                              )
                            ],
                          ),
                          const Gap(10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  color: Colors.blue[600],
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 15.0, vertical: 6),
                                  child: Text(
                                    'Front-End',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  color: Colors.blue[600],
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 15.0, vertical: 6),
                                  child: Text(
                                    'Javascript',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  color: Colors.blue[600],
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 15.0, vertical: 6),
                                  child: Text(
                                    'HTML CSS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Gap(5),
                        ],
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('il y a 2 heures'),
                          Text('1500€ / mois')
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.favorite_outline),
                  Gap(5),
                  Text('123'),
                  Gap(20),
                  Icon(Icons.comment_outlined),
                  Gap(5),
                  Text('12')
                ],
              ),
              Icon(Icons.share_outlined)
            ],
          ),
        )
      ],
    );
  }
}
