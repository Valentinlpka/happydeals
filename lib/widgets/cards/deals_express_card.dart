import 'package:flutter/material.dart';
import 'package:happy/classes/dealexpress.dart';
import 'package:happy/screens/details_page/details_dealsexpress_page.dart';
import 'package:intl/intl.dart';

class DealsExpressCard extends StatelessWidget {
  final ExpressDeal post;
  final String currentUserId;
  final String companyName;
  final String companyLogo;

  const DealsExpressCard(
      {super.key,
      required this.post,
      required this.companyName,
      required this.companyLogo,
      required this.currentUserId});

  String formatDateTime(DateTime dateTime) {
    final DateTime now = DateTime.now();
    final DateFormat timeFormat = DateFormat('HH:mm');
    final DateFormat dateFormat = DateFormat('dd/MM/yyyy');

    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      // Aujourd'hui
      return 'aujourd\'hui à ${timeFormat.format(dateTime)}';
    } else if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day + 1) {
      // Demain
      return 'demain à ${timeFormat.format(dateTime)}';
    } else {
      // Autre jour
      return 'le ${dateFormat.format(dateTime)} à ${timeFormat.format(dateTime)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(children: [
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
                    builder: (context) => DetailsDealsExpress(
                      post: post,
                      companyLogo: companyLogo,
                      companyName: companyName,
                    ),
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      backgroundBlendMode: BlendMode.darken,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                      image: DecorationImage(
                        colorFilter: ColorFilter.mode(
                            Colors.transparent.withOpacity(0.40),
                            BlendMode.darken),
                        alignment: Alignment.center,
                        fit: BoxFit.cover,
                        image: NetworkImage(companyLogo),
                      ),
                    ),
                    height: 123,
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
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Colors.pink, Colors.blue],
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Icon(
                                      Icons.battery_1_bar,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    Text(
                                      'Deals Express',
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
                          ],
                        ),
                        Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 15.0),
                              child: CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.blueGrey,
                                child: CircleAvatar(
                                  radius: 24,
                                  backgroundImage: NetworkImage(companyLogo),
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (companyName),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18),
                                ),
                                const Text(
                                  "Valenciennes",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    height: 120,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            Row(
                              children: [
                                Text(
                                  (post.title),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  "à récuperer ${formatDateTime(post.pickupTimes[0])}",
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: Color.fromARGB(255, 85, 85, 85)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5),
                                      color: const Color.fromARGB(
                                          255, 231, 231, 231),
                                      child: const Text('50% de réduction',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          )),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          "${(post.price * 2).toString()} €",
                                          style: const TextStyle(
                                              letterSpacing: 1,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color.fromARGB(
                                                  255, 181, 11, 11)),
                                        ),
                                        const SizedBox(
                                          height: 10,
                                          width: 10,
                                        ),
                                        Text(
                                          "${post.price.toString()} €",
                                          style: const TextStyle(
                                            letterSpacing: 1,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (post.availableBaskets <= 0)
            Positioned.fill(
              child: _buildSoldOutOverlay(),
            ),
        ]),
      ],
    );
  }
}

Widget _buildSoldOutOverlay() {
  return Container(
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.6),
      borderRadius: BorderRadius.circular(8.0),
    ),
    child: Center(
      child: Transform.rotate(
        angle: -0.2, // Angle de rotation en radians
        child: const Text(
          'Victime de son succès',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: Colors.black,
                offset: Offset(5.0, 5.0),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
