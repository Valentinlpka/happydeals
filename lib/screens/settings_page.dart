import 'package:flutter/material.dart';
import 'package:happy/providers/users_provider.dart';
import 'package:happy/screens/liked_post_page.dart';
import 'package:happy/screens/loyalty_card_page.dart';
import 'package:happy/screens/loyalty_points_page.dart';
import 'package:happy/screens/marketplace/ad_list_page.dart';
import 'package:happy/screens/match_market/match_market_intro_page.dart';
import 'package:happy/screens/mes_evenements.dart';
import 'package:happy/screens/my_contests_page.dart';
import 'package:happy/screens/my_deals_express.dart';
import 'package:happy/screens/profile.dart';
import 'package:happy/screens/savings_page.dart';
import 'package:happy/screens/shop/user_order_page.dart';
import 'package:happy/screens/user_applications_page.dart';
import 'package:happy/screens/user_booking_page.dart';
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
      body: Consumer<UserModel>(
        builder: (context, userModel, child) {
          if (userModel.userId.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return _SettingsContent(user: userModel);
        },
      ),
    );
  }
}

class _Category {
  final String title;
  final List<_ServiceItem> items;

  const _Category({
    required this.title,
    required this.items,
  });
}

final List<_Category> _categories = [
  _Category(
    title: 'Économies',
    items: [
      _ServiceItem(
        icon: Icons.account_balance_wallet,
        title: 'Mes économies',
        onTap: (context, _) => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SavingsPage()),
        ),
      ),
      _ServiceItem(
        icon: Icons.loyalty,
        title: 'Mes cartes de fidélité',
        onTap: (context, _) => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => LoyaltyCardsPage()),
        ),
      ),
      _ServiceItem(
        icon: Icons.currency_exchange,
        title: 'Cagnotte Up!',
        onTap: (context, _) => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoyaltyPointsPage()),
        ),
      ),
    ],
  ),
  _Category(
    title: 'Mes services',
    items: [
      _ServiceItem(
        icon: Icons.local_offer,
        title: 'Mes deals',
        onTap: (context, _) => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserOrdersPages()),
        ),
      ),
      _ServiceItem(
        icon: Icons.bolt,
        title: 'Mes Deals Express',
        onTap: (context, _) => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const ReservationListDealExpress()),
        ),
      ),
      _ServiceItem(
        icon: Icons.event_available,
        title: 'Mes Réservations',
        onTap: (context, _) => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ClientBookingsPage()),
        ),
      ),
      _ServiceItem(
        icon: Icons.handshake,
        title: 'Mes parrainages',
        onTap: (context, _) => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserReferralsPage()),
        ),
      ),
      _ServiceItem(
        icon: Icons.work_outline,
        title: 'Mes candidatures',
        onTap: (context, _) => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const UserApplicationsPage()),
        ),
      ),
      _ServiceItem(
        icon: Icons.storefront,
        title: 'Marketplace',
        onTap: (context, _) => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdListPage()),
        ),
      ),
      _ServiceItem(
        icon: Icons.favorite_outline,
        title: 'Mes Likes',
        onTap: (context, _) => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LikedPostsPage()),
        ),
      ),
      _ServiceItem(
        icon: Icons.celebration,
        title: 'Mes Evènements',
        onTap: (context, userId) => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MyEventsPage(userId: userId)),
        ),
      ),
      _ServiceItem(
        icon: Icons.thumb_up_outlined,
        title: 'Match Market',
        onTap: (context, _) => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MatchMarketIntroPage()),
        ),
      ),
      _ServiceItem(
        icon: Icons.emoji_events_outlined,
        title: 'Mes jeux concours',
        onTap: (context, userId) => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => MyContestsPage(userId: userId)),
        ),
      ),
    ],
  ),
];

class _SettingsContent extends StatelessWidget {
  final UserModel user;

  const _SettingsContent({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildProfileCard(context),
        const SizedBox(height: 32),
        _buildServicesSection(context),
        const SizedBox(height: 32),
        _buildLogoutButton(context),
      ],
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => Profile(userId: user.userId)),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[700]!, Colors.blue[500]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            _buildProfileAvatar(),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
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
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Modifier le profil',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: CircleAvatar(
        radius: 35,
        backgroundImage:
            user.profileUrl.isNotEmpty ? NetworkImage(user.profileUrl) : null,
        backgroundColor: Colors.white,
        child: user.profileUrl.isEmpty
            ? Icon(Icons.person, size: 40, color: Colors.blue[700])
            : null,
      ),
    );
  }

  Widget _buildServicesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final category in _categories) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Text(
              category.title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: category.items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = category.items[index];
              return _ServiceCard(
                icon: item.icon,
                title: item.title,
                onTap: () => item.onTap(context, user.userId),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => AuthService().signOut(context),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.red[400],
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        icon: const Icon(Icons.logout),
        label: const Text(
          'Déconnexion',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: Colors.blue[700],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceItem {
  final IconData icon;
  final String title;
  final Function(BuildContext, String) onTap;

  const _ServiceItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });
}
