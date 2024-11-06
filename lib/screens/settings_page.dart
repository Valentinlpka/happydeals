import 'package:flutter/material.dart';
import 'package:happy/providers/users.dart';
import 'package:happy/screens/liked_post_page.dart';
import 'package:happy/screens/loyalty_card_page.dart';
import 'package:happy/screens/marketplace/ad_list_page.dart';
import 'package:happy/screens/my_deals_express.dart';
import 'package:happy/screens/post_type_page/companys_page.dart';
import 'package:happy/screens/post_type_page/deal_express_page.dart';
import 'package:happy/screens/post_type_page/happy_deals_page.dart';
import 'package:happy/screens/post_type_page/jeux_concours_page.dart';
import 'package:happy/screens/post_type_page/job_offer_page.dart';
import 'package:happy/screens/post_type_page/parrainage.dart';
import 'package:happy/screens/profile.dart';
import 'package:happy/screens/shop/user_order_page.dart';
import 'package:happy/screens/userApplicationsPage.dart';
import 'package:happy/screens/user_referral_page.dart';
import 'package:happy/services/auth_service.dart';
import 'package:happy/widgets/custom_app_bar.dart';
import 'package:provider/provider.dart';

class ParametrePage extends StatelessWidget {
  const ParametrePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: const CustomAppBar(
        title: 'Mon Profil',
        align: Alignment.center,
      ),
      body: SafeArea(
        child: Consumer<UserModel>(
          builder: (context, userModel, child) {
            if (userModel.userId.isEmpty) {
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
      padding: const EdgeInsets.all(20),
      children: [
        _buildProfileHeader(context, user),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.only(
              left: 5), // Même alignement que "Mon Profil"
          child: _buildSectionTitle('Mes Services'),
        ),
        _buildServiceGrid(context),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.only(left: 5),
          child: _buildSectionTitle('Découvrir'),
        ),
        _buildDiscoverGrid(context),
        _buildLogoutButton(context, AuthService()),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, UserModel user) {
    return InkWell(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => Profile(
                      userId: user.userId,
                    )));
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[600]!, Colors.blue[400]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: CircleAvatar(
                radius: 30,
                backgroundImage: user.profileUrl.isNotEmpty
                    ? NetworkImage(user.profileUrl)
                    : null,
                backgroundColor: Colors.white,
                child: user.profileUrl.isEmpty
                    ? const Icon(Icons.person, size: 35, color: Colors.blue)
                    : null,
              ),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user.firstName} ${user.lastName}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Voir le profil',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceItem(String title, IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 28, color: Colors.blue[600]),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthService authService) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: ElevatedButton(
        onPressed: () => authService.signOut(context),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.red[400],
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          elevation: 2,
        ),
        child: const Text(
          'Déconnexion',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildServiceGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.4, // Ajusté pour accommoder le texte sur 2 lignes
      padding: const EdgeInsets.symmetric(horizontal: 16),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildServiceCard(
          icon: Icons.shopping_bag,
          title: 'Mes deals',
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const UserOrdersPages()));
          },
        ),
        _buildServiceCard(
          icon: Icons.calendar_today,
          title: 'Mes Deals Express',
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ReservationListDealExpress()));
          },
        ),
        _buildServiceCard(
          icon: Icons.people,
          title: 'Mes parrainages',
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const UserReferralsPage()));
          },
        ),
        _buildServiceCard(
          icon: Icons.work,
          title: 'Mes candidatures',
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const UserApplicationsPage()));
          },
        ),
        _buildServiceCard(
          icon: Icons.card_membership,
          title: 'Mes cartes de fidélité',
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => LoyaltyCardsPage()));
          },
        ),
        _buildServiceCard(
          icon: Icons.store,
          title: 'Marketplace',
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => const AdListPage()));
          },
        ),
        _buildServiceCard(
          icon: Icons.favorite,
          title: "Mes Likes",
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const LikedPostsPage()));
          },
        ),
      ],
    );
  }

  Widget _buildServiceCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: Colors.blue[600],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoverGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2,
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
}
