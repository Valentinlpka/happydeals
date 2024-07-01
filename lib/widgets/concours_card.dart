import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:happy/classes/contest.dart';
import 'package:happy/screens/details_page/details_jeuxconcours_page.dart';

class ConcoursCard extends StatelessWidget {
  final Contest contest;
  final String currentUserId;
  const ConcoursCard(
      {super.key,
      required this.contest,
      required this.currentUserId,
      required this.companyLogo,
      required this.companyName});

  final String companyLogo;
  final String companyName;

  @override
  Widget build(BuildContext context) {
    String capitalizeFirstLetter(String text) {
      if (text.isEmpty) {
        return text;
      }
      return text[0].toUpperCase() + text.substring(1);
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
                  builder: (context) => DetailsJeuxConcoursPage(
                    contest: contest,
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
                          Colors.black.withOpacity(0.20), BlendMode.srcOver),
                      alignment: Alignment.center,
                      fit: BoxFit.cover,
                      image: const NetworkImage(
                          "https://store.storeimages.cdn-apple.com/4668/as-images.apple.com/is/airpods-max-select-silver-202011_FMT_WHH?wid=1200&hei=630&fmt=jpeg&qlt=95&.v=1604615276000"),
                    ),
                  ),
                  height: 110,
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
                                    'Jeux Concours',
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
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  height: 150,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                capitalizeFirstLetter(contest.title),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 15,
                              ),
                              Gap(5),
                              Text(
                                "23 Avril 2024 - 23 Mai 2024",
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Color.fromARGB(255, 85, 85, 85)),
                              ),
                            ],
                          ),
                          const Gap(10),
                          Text(
                            contest.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                        ],
                      ),
                      const Row(
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
                                  backgroundImage: NetworkImage(
                                      'https://media.licdn.com/dms/image/C4D0BAQF1LJrX1nhcyA/company-logo_200_200/0/1630523580358/be_happy_services_logo?e=2147483647&v=beta&t=XH4UBtLR0ulhQvd1XKnpRgg-BrU0JrWZhcsAZf7c15I'),
                                ),
                              ),
                              Gap(10),
                              Text(
                                "Be Happy",
                                style: TextStyle(
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
