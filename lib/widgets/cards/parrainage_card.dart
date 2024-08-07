import 'package:flutter/material.dart';
import 'package:happy/classes/referral.dart';
// ignore: unused_import
import 'package:happy/screens/details_page/details_evenement_page.dart';
import 'package:happy/screens/details_page/details_parrainage.dart';
import 'package:happy/widgets/capitalize_first_letter.dart';
import 'package:intl/intl.dart';

class ParrainageCard extends StatelessWidget {
  final Referral post;
  final String currentUserId;

  final String companyLogo;
  final String companyName;

  const ParrainageCard(
      {required this.post,
      super.key,
      required this.currentUserId,
      required this.companyLogo,
      required this.companyName});

  @override
  Widget build(BuildContext context) {
    String formatDateTime(DateTime dateTime) {
      return DateFormat('dd/MM/yyyy')
          .format(dateTime); // Format comme "2024-06-13"
    }

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
                  builder: (context) => DetailsParrainagePage(
                    referral: post,
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
                        Colors.black.withOpacity(0.30),
                        BlendMode.hue,
                      ),
                      alignment: Alignment.center,
                      fit: BoxFit.cover,
                      image: NetworkImage(post.image),
                    ),
                  ),
                  height: 80,
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
                              height: 30,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: const Color.fromARGB(115, 0, 0, 0),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10.0, vertical: 5),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Icon(
                                      Icons.calendar_month_outlined,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    Text(
                                      'Parrainage',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          Column(
                            children: [
                              Text(
                                softWrap: true,
                                capitalizeFirstLetter(post.title),
                                overflow: TextOverflow.fade,
                                maxLines: 2,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 5,
                            width: 5,
                          ),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 15),
                              const SizedBox(
                                width: 5,
                              ),
                              Text(
                                "jusqu'au ${formatDateTime(post.dateFinal)}",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color.fromARGB(255, 85, 85, 85),
                                ),
                              )
                            ],
                          ),
                          const SizedBox(
                            height: 5,
                            width: 5,
                          ),
                          Text(
                            post.description,
                            style: const TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Divider(
                        color: Colors.grey[300],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.blue,
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundImage: NetworkImage(companyLogo),
                                ),
                              ),
                              const SizedBox(
                                height: 10,
                                width: 10,
                              ),
                              Text(
                                capitalizeFirstLetter(companyName),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
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
