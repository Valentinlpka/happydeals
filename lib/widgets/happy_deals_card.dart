import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:happy/classes/happydeal.dart';
import 'package:happy/screens/details_page/details_happydeals.dart';
import 'package:happy/widgets/capitalize_first_letter.dart';
import 'package:intl/intl.dart';

class HappyDealsCard extends StatelessWidget {
  final HappyDeal post;
  final String companyName;
  final String companyCategorie;
  final String companyLogo;
  final String currentUserId;

  const HappyDealsCard(
      {super.key,
      required this.post,
      required this.companyName,
      required this.currentUserId,
      required this.companyCategorie,
      required this.companyLogo});

  String formatDateTime(DateTime dateTime) {
    return DateFormat('dd/mm/yyyy')
        .format(dateTime); // Format comme "2024-06-13"
  }

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
                  builder: (context) => DetailsHappyDeals(
                    happydeal: post,
                    currentUserId: currentUserId,
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
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                    image: DecorationImage(
                      colorFilter: ColorFilter.mode(
                          Colors.transparent.withOpacity(0.40),
                          BlendMode.colorBurn),
                      alignment: Alignment.center,
                      fit: BoxFit.cover,
                      image: const NetworkImage(
                          "https://cap.img.pmdstatic.net/fit/https.3A.2F.2Fi.2Epmdstatic.2Enet.2Fcap.2F2023.2F02.2F03.2F2591eacf-2c18-4a13-9091-bf4683c6fd56.2Ejpeg/1200x630/quality/80/le-stade-de-france-pourrait-etre-vendu-par-letat-1462050.jpg"),
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
                                color: Colors.black54,
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
                                    'Happy Deals',
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
                              backgroundColor: Colors.blue,
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
                                companyName,
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
                                    fontWeight: FontWeight.bold),
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
                                capitalizeFirstLetter(post.title),
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
                                "Valable jusqu'au ${formatDateTime(post.endDate)}",
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                height: 25,
                                width: 25,
                                decoration: const BoxDecoration(
                                  color: Colors.blueAccent,
                                ),
                                child: const Icon(
                                  size: 20,
                                  color: Colors.white,
                                  Icons.star,
                                ),
                              ),
                              const Gap(4),
                              const Text(
                                "4,4",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const Gap(4),
                              const Text(
                                "|",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const Gap(4),
                              Text(
                                companyCategorie,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
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
                                    child: Text(
                                        "${post.deals[0].discount} % de réduction",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        )),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        "${post.deals[0].oldPrice} €",
                                        style: const TextStyle(
                                            letterSpacing: 1,
                                            decoration:
                                                TextDecoration.lineThrough,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Color.fromARGB(
                                                255, 181, 11, 11)),
                                      ),
                                      const Gap(10),
                                      Text(
                                        "${post.deals[0].newPrice} €",
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
      ],
    );
  }
}
