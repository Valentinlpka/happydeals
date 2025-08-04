import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy/widgets/app_bar/custom_app_bar_back.dart';
import 'package:intl/intl.dart';

class LoyaltyPointsPage extends StatefulWidget {
  const LoyaltyPointsPage({super.key});

  @override
  State<LoyaltyPointsPage> createState() => _LoyaltyPointsPageState();
}

class _LoyaltyPointsPageState extends State<LoyaltyPointsPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _counterController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _counterController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.4, 1.0, curve: Curves.elasticOut),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _counterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBodyBehindAppBar: true,
      appBar: const CustomAppBarBack(
        title: 'Ma Cagnotte Up!',
      ),
      body: StreamBuilder<LoyaltyData>(
        stream: _getLoyaltyData(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          final loyaltyData = snapshot.data ?? LoyaltyData.empty();

          return AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: SizedBox(height: MediaQuery.of(context).padding.top + 10),
                      ),
                      SliverToBoxAdapter(
                        child: _buildEnhancedPointsSummary(context, loyaltyData),
                      ),
                      SliverToBoxAdapter(
                        child: _buildQuickStats(context, loyaltyData),
                      ),
                      SliverToBoxAdapter(
                        child: _buildEnhancedRewardsSection(context, loyaltyData),
                      ),
                      SliverToBoxAdapter(
                        child: _buildSectionHeader(
                          context,
                          'Mes codes promo',
                          Icons.local_offer_rounded,
                          Colors.orange,
                        ),
                      ),
                      _buildEnhancedPromoCodesList(loyaltyData.promoCodes),
                      SliverToBoxAdapter(
                        child: _buildSectionHeader(
                          context,
                          'Historique des gains',
                          Icons.timeline_rounded,
                          Colors.blue,
                        ),
                      ),
                      _buildEnhancedPointsHistory(loyaltyData.history),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 100),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Chargement de votre cagnotte...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Problème de connexion',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vérifiez votre connexion internet\net réessayez',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Forcer le rebuild du StreamBuilder
                  setState(() {});
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667EEA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedPointsSummary(BuildContext context, LoyaltyData data) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF667EEA),
                Color(0xFF764BA2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667EEA).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.stars_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mes points Up!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Votre solde de fidélité',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: data.currentPoints),
                duration: const Duration(milliseconds: 2000),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Text(
                    '$value',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      height: 1.0,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'POINTS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildProgressIndicator(data.currentPoints),
              const SizedBox(height: 16),
              Text(
                _getNextRewardText(data.currentPoints),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(int currentPoints) {
    final progress = _getProgressToNextReward(currentPoints);
    
    return Column(
      children: [
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              _getNextRewardLevel(currentPoints),
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStats(BuildContext context, LoyaltyData data) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Ce mois-ci',
              '${data.monthSavings.toStringAsFixed(2)}€',
              Icons.trending_up_rounded,
              const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              'Codes actifs',
              '${data.promoCodes.where((p) => !p.isUsed && !p.expiryDate.isBefore(DateTime.now())).length}',
              Icons.local_offer_rounded,
              const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedRewardsSection(BuildContext context, LoyaltyData data) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Récompenses disponibles',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
            padding: EdgeInsets.zero,
            children: [
              _buildSimpleRewardCard(
                context,
                points: 100,
                amount: 1,
                isEnabled: data.currentPoints >= 100,
                onClaim: () => _claimReward(context, 100, 1),
                color: const Color(0xFF10B981),
              ),
              _buildSimpleRewardCard(
                context,
                points: 300,
                amount: 6,
                isEnabled: data.currentPoints >= 300,
                onClaim: () => _claimReward(context, 300, 6),
                color: const Color(0xFF3B82F6),
              ),
              _buildSimpleRewardCard(
                context,
                points: 500,
                amount: 12.50,
                isEnabled: data.currentPoints >= 500,
                onClaim: () => _claimReward(context, 500, 12.50),
                color: const Color(0xFF8B5CF6),
              ),
              _buildSimpleRewardCard(
                context,
                points: 700,
                amount: 21,
                isEnabled: data.currentPoints >= 700,
                onClaim: () => _claimReward(context, 700, 21),
                color: const Color(0xFFEC4899),
              ),
            ],
          ),
        
        ],
      ),
    );
  }

  Widget _buildSimpleRewardCard(
    BuildContext context, {
    required int points,
    required double amount,
    required bool isEnabled,
    required VoidCallback onClaim,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEnabled ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onClaim : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$points',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isEnabled ? color : Colors.grey[400],
                  ),
                ),
                Text(
                  'points',
                  style: TextStyle(
                    fontSize: 11,
                    color: isEnabled ? Colors.grey[600] : Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${amount.toStringAsFixed(amount == amount.toInt() ? 0 : 2)}€',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isEnabled ? const Color(0xFF1F2937) : Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: isEnabled
                      ? ElevatedButton(
                          onPressed: onClaim,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.zero,
                            elevation: 0,
                          ),
                          child: const Text(
                            'Échanger',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Indisponible',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                            ),
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

  Widget _buildEnhancedPromoCodesList(List<PromoCode> promoCodes) {
    if (promoCodes.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_offer_outlined,
                  size: 48,
                  color: Colors.orange[600],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Aucun code promo disponible',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Échangez vos points contre des codes promo',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final promoCode = promoCodes[index];
            return _buildEnhancedPromoCodeCard(context, promoCode, index);
          },
          childCount: promoCodes.length,
        ),
      ),
    );
  }

  Widget _buildEnhancedPromoCodeCard(BuildContext context, PromoCode promoCode, int index) {
    final isExpired = promoCode.expiryDate.isBefore(DateTime.now());
    final remainingDays = promoCode.expiryDate.difference(DateTime.now()).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: promoCode.isUsed
              ? Colors.grey.withOpacity(0.3)
              : isExpired
                  ? Colors.red.withOpacity(0.3)
                  : const Color(0xFF10B981).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: promoCode.isUsed
                        ? Colors.grey.withOpacity(0.1)
                        : isExpired
                            ? Colors.red.withOpacity(0.1)
                            : const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.local_offer_rounded,
                    color: promoCode.isUsed
                        ? Colors.grey[500]
                        : isExpired
                            ? Colors.red
                            : const Color(0xFF10B981),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${promoCode.amount.toStringAsFixed(2)}€',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        'Code promo',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildEnhancedStatusChip(promoCode),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      promoCode.code,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: promoCode.code));
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Code copié !'),
                            backgroundColor: const Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: isExpired ? Colors.red : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  isExpired
                      ? 'Expiré le ${DateFormat('dd/MM/yyyy').format(promoCode.expiryDate)}'
                      : remainingDays == 0
                          ? 'Expire aujourd\'hui'
                          : 'Expire dans $remainingDays jour${remainingDays > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: isExpired ? Colors.red : Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedStatusChip(PromoCode promoCode) {
    final isExpired = promoCode.expiryDate.isBefore(DateTime.now());

    Color backgroundColor;
    Color textColor;
    String text;
    IconData icon;

    if (promoCode.isUsed) {
      backgroundColor = Colors.grey[100]!;
      textColor = Colors.grey[600]!;
      text = 'Utilisé';
      icon = Icons.check_circle_rounded;
    } else if (isExpired) {
      backgroundColor = Colors.red[50]!;
      textColor = Colors.red;
      text = 'Expiré';
      icon = Icons.schedule_rounded;
    } else {
      backgroundColor = const Color(0xFF10B981).withOpacity(0.1);
      textColor = const Color(0xFF10B981);
      text = 'Disponible';
      icon = Icons.check_circle_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedPointsHistory(List<PointsHistory> history) {
    if (history.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.timeline_rounded,
                  size: 48,
                  color: Colors.blue[600],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Aucun historique disponible',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vos gains de points apparaîtront ici',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = history[index];
            return _buildEnhancedHistoryCard(item, index);
          },
          childCount: history.length,
        ),
      ),
    );
  }

  Widget _buildEnhancedHistoryCard(PointsHistory item, int index) {
    String typeLabel;
    IconData typeIcon;
    Color typeColor;

    switch (item.type) {
      case 'order':
        typeLabel = 'Commande';
        typeIcon = Icons.shopping_bag_rounded;
        typeColor = const Color(0xFF8B5CF6);
        break;
      case 'express_deal':
        typeLabel = 'Deal Express';
        typeIcon = Icons.flash_on_rounded;
        typeColor = const Color(0xFFF59E0B);
        break;
           case 'referral':
        typeLabel = 'Parrainage';
        typeIcon = Icons.person_add_alt_1_rounded;
        typeColor = const Color(0xFF10B981);
        break;
      case 'service':
        typeLabel = 'Réservation';
        typeIcon = Icons.calendar_today_rounded;
        typeColor = const Color(0xFF3B82F6);
        break;
      default:
        typeLabel = 'Transaction';
        typeIcon = Icons.paid_rounded;
        typeColor = const Color(0xFF10B981);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(typeIcon, color: typeColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    typeLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(item.date),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+${item.points} points',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.amount.toStringAsFixed(2)}€',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Validé',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Méthodes utilitaires
  Future<void> _initializeLoyaltyData(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'loyaltyPoints': 0,
      });
    } catch (e) {
      print('Erreur lors de l\'initialisation des données de fidélité: $e');
    }
  }

  Stream<LoyaltyData> _getLoyaltyData(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((userDoc) async {
      try {
        if (!userDoc.exists) {
          return LoyaltyData.empty();
        }

        final data = userDoc.data()!;
        
        // Initialiser les données de fidélité si elles n'existent pas
        if (!data.containsKey('loyaltyPoints')) {
          await _initializeLoyaltyData(userId);
        }
        
        final points = data['loyaltyPoints'] ?? 0;

        // Récupérer l'historique des points avec gestion d'erreur
        List<PointsHistory> history = [];
        try {
          final historyQuery = await FirebaseFirestore.instance
              .collection('pointsHistory')
              .where('userId', isEqualTo: userId)
              .orderBy('date', descending: true)
              .limit(50)
              .get();

          history = historyQuery.docs.map((doc) {
            final docData = doc.data();
            return PointsHistory(
              type: docData['type'] ?? 'transaction',
              date: docData['date'] != null 
                  ? (docData['date'] as Timestamp).toDate() 
                  : DateTime.now(),
              points: docData['points'] ?? 0,
              amount: (docData['amount'] as num?)?.toDouble() ?? 0.0,
              referenceId: docData['referenceId'] ?? '',
              status: docData['status'] ?? 'completed',
            );
          }).toList();
        } catch (e) {
          print('Erreur lors de la récupération de l\'historique: $e');
          // Continue avec une liste vide si l'historique ne peut pas être chargé
        }

        // Calculer les statistiques
        double totalEarned = 0;
        double monthEarned = 0;
        final now = DateTime.now();

        for (var item in history) {
          totalEarned += item.amount;
          if (item.date.month == now.month && item.date.year == now.year) {
            monthEarned += item.amount;
          }
        }

        // Récupérer les codes promo avec gestion d'erreur
        List<PromoCode> promoCodes = [];
        try {
          final promoCodesQuery = await FirebaseFirestore.instance
              .collection('promo_codes')
              .where('customerId', isEqualTo: userId)
              .where('companyId', isEqualTo: 'UP')
              .get(); // Suppression de orderBy qui peut causer des erreurs d'index

          promoCodes = promoCodesQuery.docs.map((doc) {
            final docData = doc.data();
            return PromoCode(
              code: docData['code'] ?? '',
              amount: (docData['discountValue'] as num?)?.toDouble() ?? 0.0,
              expiryDate: docData['expiresAt'] != null 
                  ? (docData['expiresAt'] as Timestamp).toDate()
                  : DateTime.now().add(const Duration(days: 30)),
              isUsed: (docData['currentUses'] ?? 0) > 0,
            );
          }).toList();

          // Trier localement par date de création si le champ existe
          promoCodes.sort((a, b) {
            // Tri par date d'expiration décroissante comme approximation
            return b.expiryDate.compareTo(a.expiryDate);
          });
        } catch (e) {
          print('Erreur lors de la récupération des codes promo: $e');
          // Continue avec une liste vide si les codes promo ne peuvent pas être chargés
        }

        return LoyaltyData(
          currentPoints: points,
          monthSavings: monthEarned,
          totalSavings: totalEarned,
          averageSavings: history.isEmpty ? 0 : totalEarned / history.length,
          promoCodes: promoCodes,
          history: history,
        );
      } catch (e) {
        print('Erreur générale dans _getLoyaltyData: $e');
        // En cas d'erreur générale, retourner des données vides
        return LoyaltyData.empty();
      }
    });
  }

  double _getProgressToNextReward(int currentPoints) {
    if (currentPoints >= 700) return 1.0;
    if (currentPoints >= 500) return (currentPoints - 500) / 200;
    if (currentPoints >= 300) return (currentPoints - 300) / 200;
    if (currentPoints >= 100) return (currentPoints - 100) / 200;
    return currentPoints / 100;
  }

  String _getNextRewardText(int currentPoints) {
    if (currentPoints >= 700) return 'Félicitations ! Niveau maximum atteint 🎉';
    if (currentPoints >= 500) return '${700 - currentPoints} points pour débloquer 21€';
    if (currentPoints >= 300) return '${500 - currentPoints} points pour débloquer 12,50€';
    if (currentPoints >= 100) return '${300 - currentPoints} points pour débloquer 6€';
    return '${100 - currentPoints} points pour votre première récompense';
  }

  String _getNextRewardLevel(int currentPoints) {
    if (currentPoints >= 700) return 'Niveau Max';
    if (currentPoints >= 500) return 'Niveau 4';
    if (currentPoints >= 300) return 'Niveau 3';
    if (currentPoints >= 100) return 'Niveau 2';
    return 'Niveau 1';
  }

  Future<void> _claimReward(BuildContext context, int points, double amount) async {
    // Afficher une animation de chargement
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Génération du code promo...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
      final promoCodesCollection = FirebaseFirestore.instance.collection('promo_codes');

      // Générer un code promo unique
      final promoCode = 'UP${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();
      final expiryDate = now.add(const Duration(days: 30));

      // Créer le code promo dans la collection promo_codes
      await promoCodesCollection.doc(promoCode).set({
        'code': promoCode,
        'companyId': 'UP',
        'createdAt': Timestamp.fromDate(now),
        'currentUses': 0,
        'customerId': userId,
        'discountType': 'amount',
        'discountValue': amount,
        'expiresAt': Timestamp.fromDate(expiryDate),
        'isPercentage': false,
        'isPublic': false,
        'maxUses': '1',
        'isActive': true,
      });

      // Mettre à jour les points de l'utilisateur
      await userDoc.update({
        'loyaltyPoints': FieldValue.increment(-points),
      });

      Navigator.of(context).pop(); // Fermer le dialog de chargement

      // Afficher une confirmation avec animation
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 48,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Félicitations !',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Votre code promo de ${amount.toStringAsFixed(2)}€ a été généré avec succès !',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Super !',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // Haptic feedback
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      Navigator.of(context).pop(); // Fermer le dialog de chargement
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Erreur lors de la génération du code promo'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }
}

// Classes de données (inchangées)
class LoyaltyData {
  final int currentPoints;
  final double totalSavings;
  final double monthSavings;
  final double averageSavings;
  final List<PromoCode> promoCodes;
  final List<PointsHistory> history;

  const LoyaltyData({
    required this.currentPoints,
    required this.totalSavings,
    required this.monthSavings,
    required this.averageSavings,
    required this.promoCodes,
    required this.history,
  });

  factory LoyaltyData.empty() {
    return const LoyaltyData(
      currentPoints: 0,
      totalSavings: 0,
      monthSavings: 0,
      averageSavings: 0,
      promoCodes: [],
      history: [],
    );
  }
}

class PromoCode {
  final String code;
  final double amount;
  final DateTime expiryDate;
  final bool isUsed;

  const PromoCode({
    required this.code,
    required this.amount,
    required this.expiryDate,
    this.isUsed = false,
  });
}

class PointsHistory {
  final String type;
  final DateTime date;
  final int points;
  final double amount;
  final String referenceId;
  final String status;

  const PointsHistory({
    required this.type,
    required this.date,
    required this.points,
    required this.amount,
    required this.referenceId,
    required this.status,
  });
}

