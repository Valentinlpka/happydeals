import 'package:flutter/material.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/screens/post_type_page/companys_page.dart';
import 'package:happy/screens/post_type_page/deal_express_page.dart';
import 'package:happy/screens/post_type_page/happy_deals_page.dart';
import 'package:happy/screens/post_type_page/jeux_concours_page.dart';
import 'package:happy/screens/post_type_page/job_offer_page.dart';
import 'package:happy/screens/post_type_page/parrainage.dart';
import 'package:happy/screens/profile.dart';
import 'package:happy/screens/reservation_list_deal_express.dart';
import 'package:happy/screens/shop/user_order_page.dart';
import 'package:happy/screens/userApplicationsPage.dart';
import 'package:happy/screens/user_referral_page.dart';
import 'package:happy/services/auth_service.dart';
import 'package:provider/provider.dart';

class ParametrePage extends StatelessWidget {
  const ParametrePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<UserModel>(
          builder: (context, userModel, child) {
            if (userModel.userId.isEmpty) {
              // L'utilisateur n'est pas connecté ou les données ne sont pas encore chargées
              return const Center(child: CircularProgressIndicator());
            }
            return _buildContent(context, userModel);
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, UserModel user) {
    return ListView(
      children: [
        _buildProfileHeader(context, user),
        _buildServiceGrid(context),
        const Padding(
          padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
          child: Text('Découvrir',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        _buildDiscoverGrid(context),
        _buildLogoutButton(context, AuthService()),
      ],
    );
  }

  Widget _buildProfileHeader(BuildContext context, UserModel user) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Profile(userId: user.userId),
          ),
        );
      },
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(5)),
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.1),
              blurRadius: 3,
              spreadRadius: 0,
              offset: Offset(
                0,
                1,
              ),
            ),
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.06),
              blurRadius: 2,
              spreadRadius: 0,
              offset: Offset(
                0,
                1,
              ),
            ),
          ],
          color: Colors.white,
        ),
        height: 60,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: user.profileUrl.isNotEmpty
                  ? NetworkImage(user.profileUrl)
                  : null,
              backgroundColor: Colors.grey,
              child: user.profileUrl.isEmpty
                  ? const Icon(Icons.person, size: 30, color: Colors.white)
                  : null,
            ),
            const SizedBox(
              height: 10,
              width: 10,
            ),
            Text(
              '${user.firstName} ${user.lastName}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.5,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildServiceItem('Mes achats', Icons.shopping_bag, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const UserOrdersPages()));
        }),
        _buildServiceItem('Mes réservations', Icons.calendar_today, () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ReservationListDealExpress()));
        }),
        _buildServiceItem('Mes parrainages', Icons.people, () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const UserReferralsPage()));
        }),
        _buildServiceItem('Mes candidatures', Icons.work, () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const UserApplicationsPage()));
        }),
      ],
    );
  }

  Widget _buildDiscoverGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.5,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildServiceItem('Annuaire', Icons.book, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const CompaniesPage()));
        }),
        _buildServiceItem('Offres d\'emploi', Icons.work, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const JobOffersPage()));
        }),
        _buildServiceItem('Happy Deals', Icons.local_offer, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const HappyDealsPage()));
        }),
        _buildServiceItem('Deals Express', Icons.flash_on, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const DealExpressPage()));
        }),
        _buildServiceItem('Jeux concours', Icons.emoji_events, () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const JeuxConcoursPage()));
        }),
        _buildServiceItem('Offres de parrainage', Icons.card_giftcard, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const ParraiangePage()));
        }),
      ],
    );
  }

  Widget _buildServiceItem(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: Colors.grey[600]),
            const SizedBox(height: 4),
            Text(title,
                style: TextStyle(fontSize: 12, color: Colors.grey[800])),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthService authService) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: () => authService.signOut(context),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: Colors.grey[300],
          minimumSize: const Size(double.infinity, 50),
        ),
        child: const Text('Déconnexion'),
      ),
    );
  }
}
