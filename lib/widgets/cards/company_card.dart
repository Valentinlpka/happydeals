import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/providers/company_provider.dart';
import 'package:happy/widgets/average_rating.dart';
import 'package:provider/provider.dart';

import '../../classes/company.dart';
import '../../screens/details_page/details_company_page.dart';

class CompanyCard extends StatelessWidget {
  final Company company;

  const CompanyCard(this.company, {super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          CompanyLikeService(FirebaseAuth.instance.currentUser!.uid),
      child: Builder(builder: (context) {
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailsEntreprise(
                  entrepriseId: company.id,
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
                _buildCoverImage(context),
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                ),
                _buildCompanyInfo(context),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCoverImage(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        left: 10,
        bottom: 10,
      ),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
        image: DecorationImage(
          colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.30), BlendMode.darken),
          alignment: Alignment.center,
          fit: BoxFit.cover,
          image: NetworkImage(company.cover),
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
                  _buildLocationTag(),
                  _buildLikeButton(context),
                ],
              ),
            ],
          ),
          _buildCompanyLogo(),
        ],
      ),
    );
  }

  Widget _buildLocationTag() {
    return Container(
      padding: const EdgeInsets.only(top: 3, bottom: 3, right: 7, left: 5),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.pink, Colors.blue],
        ),
        borderRadius: BorderRadius.all(Radius.circular(5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 18,
            color: Colors.white,
          ),
          Text(
            company.adress.ville,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikeButton(BuildContext context) {
    return Consumer<CompanyLikeService>(
      builder: (context, companyLikeService, child) {
        final isLiked = companyLikeService.isCompanyLiked(company.id);
        return IconButton(
          onPressed: () async {
            companyLikeService.handleLike(company);
            // Vous pouvez ajouter ici une logique pour mettre à jour l'état global si nécessaire
          },
          icon: isLiked
              ? const Icon(Icons.favorite)
              : const Icon(Icons.favorite_border),
          color: isLiked ? Colors.red : Colors.white,
        );
      },
    );
  }

  Widget _buildCompanyLogo() {
    return Positioned(
      bottom: -40,
      child: Padding(
        padding: const EdgeInsets.only(right: 15.0),
        child: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.blue,
          child: CircleAvatar(
            radius: 25,
            backgroundImage: NetworkImage(company.logo),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        left: 10,
        right: 10,
        bottom: 10,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            overflow: TextOverflow.ellipsis,
            (company.name),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              buildAverageRating(company.averageRating),
              const SizedBox(
                height: 5,
                width: 5,
              ),
              Text(
                '(${company.numberOfReviews} avis)',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          Text(
            (company.categorie),
            style: const TextStyle(
                fontSize: 14, color: Color.fromARGB(255, 85, 85, 85)),
          ),
          Row(
            children: [
              Text(
                company.like.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(
                height: 5,
                width: 5,
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
              const SizedBox(
                height: 5,
                width: 5,
              ),
              Text(company.phone)
            ],
          )
        ],
      ),
    );
  }
}
