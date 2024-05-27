import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:happy/screens/home_page.dart';

class DealsExpressCard extends StatelessWidget {
  const DealsExpressCard({super.key});

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
                  builder: (context) => const Home(),
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
                          Colors.black.withOpacity(0.80), BlendMode.hue),
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
                                color: Colors.blue,
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
                          const Icon(
                            Icons.favorite,
                            color: Colors.red,
                          )
                        ],
                      ),
                      const Row(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(right: 15.0),
                            child: CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.blueGrey,
                              child: CircleAvatar(
                                radius: 24,
                                backgroundImage: NetworkImage(
                                    'https://media.licdn.com/dms/image/C4D0BAQF1LJrX1nhcyA/company-logo_200_200/0/1630523580358/be_happy_services_logo?e=2147483647&v=beta&t=XH4UBtLR0ulhQvd1XKnpRgg-BrU0JrWZhcsAZf7c15I'),
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Be Happy",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18),
                              ),
                              Text(
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
                      const Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                "Panier Gourmand",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                "à récuperer aujourd'hui 16:00 - 18:00",
                                style: TextStyle(
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
                              const Text(
                                "Beauté",
                                style: TextStyle(
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
                                    child: const Text('50% de réduction',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        )),
                                  ),
                                  const Row(
                                    children: [
                                      Text(
                                        "19,99 €",
                                        style: TextStyle(
                                            letterSpacing: 1,
                                            decoration:
                                                TextDecoration.lineThrough,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Color.fromARGB(
                                                255, 181, 11, 11)),
                                      ),
                                      Gap(10),
                                      Text(
                                        '9,99€',
                                        style: TextStyle(
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
