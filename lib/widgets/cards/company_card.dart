import 'package:custom_rating_bar/custom_rating_bar.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:happy/widgets/capitalize_first_letter.dart';
import 'package:provider/provider.dart';

import '../../classes/company.dart';
import '../../providers/users.dart';
import '../../screens/details_page/details_company_page.dart';

class CompanyCard extends StatelessWidget {
  final Company company;

  const CompanyCard(this.company, {super.key});

  @override
  Widget build(BuildContext context) {
    final bool isLiked =
        context.watch<UserModel>().likeList.contains(company.id);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DetailsCompany(
              companyId: 'E8ivG6AyXg8W8mrBZksa',
            ),
          ),
        );
      },
      child: Card(
        shadowColor: Colors.grey,
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
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
              height: 100,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.only(
                                top: 3, bottom: 3, right: 7, left: 5),
                            decoration: BoxDecoration(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(5),
                                ),
                                color: Colors.black38,
                                border:
                                    Border.all(color: Colors.white, width: 2)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                Text(
                                  company.ville,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              if (isLiked) {
                                await context
                                    .read<UserModel>()
                                    .unlikePost(company.id);
                              } else {
                                await context
                                    .read<UserModel>()
                                    .likePost(company.id);
                              }
                            },
                            icon: isLiked
                                ? const Icon(Icons.favorite)
                                : const Icon(Icons.favorite_border),
                            color: isLiked ? Colors.red : Colors.white,
                          )
                        ],
                      ),
                    ],
                  ),
                  const Positioned(
                    bottom: -40,
                    child: Padding(
                      padding: EdgeInsets.only(right: 15.0),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.blue,
                        child: CircleAvatar(
                          radius: 25,
                          backgroundImage: NetworkImage(
                              'https://media.licdn.com/dms/image/C4D0BAQF1LJrX1nhcyA/company-logo_200_200/0/1630523580358/be_happy_services_logo?e=2147483647&v=beta&t=XH4UBtLR0ulhQvd1XKnpRgg-BrU0JrWZhcsAZf7c15I'),
                        ),
                      ),
                    ),
                  ), // 'https://media.licdn.com/dms/image/C4D0BAQF1LJrX1nhcyA/company-logo_200_200/0/1630523580358/be_happy_services_logo?e=2147483647&v=beta&t=XH4UBtLR0ulhQvd1XKnpRgg-BrU0JrWZhcsAZf7c15I'
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 30),
            ),
            Container(
              padding: const EdgeInsets.only(
                left: 10,
                right: 10,
                bottom: 10,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            overflow: TextOverflow.ellipsis,
                            capitalizeFirstLetter(company.name),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 3),
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(5)),
                          color: Colors.blue,
                        ),
                        child: Text(
                          company.open ? 'Ouvert' : 'Fermé',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      RatingBar(
                        filledIcon: Icons.star,
                        size: 16,
                        filledColor: Colors.blue,
                        emptyIcon: Icons.star_border,
                        onRatingChanged: (_) => {},
                        initialRating: company.rating,
                        maxRating: 5,
                      ),
                      const Text(
                        '(45 avis)',
                        style: TextStyle(fontSize: 12),
                      ),
                      // Text(DateFormat('EEEE', 'FR_fr').format(DateTime.now()))
                    ],
                  ),
                  Text(
                    company.categorie,
                    style: const TextStyle(
                        fontSize: 14, color: Color.fromARGB(255, 85, 85, 85)),
                  ),
                  Row(
                    children: [
                      Text(
                        company.like.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text("J'aime")
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.phone,
                        size: 20,
                      ),
                      const Gap(5),
                      Text(company.phone)
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
