import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/ad.dart';
import 'package:happy/providers/ads_provider.dart';
import 'package:happy/providers/conversation_provider.dart';
import 'package:happy/screens/conversation_detail.dart';
import 'package:happy/screens/profile.dart';
import 'package:provider/provider.dart';

class AdDetailPage extends StatefulWidget {
  final Ad ad;
  const AdDetailPage({super.key, required this.ad});

  @override
  State<AdDetailPage> createState() => _AdDetailPageState();
}

class _AdDetailPageState extends State<AdDetailPage> {
  int _currentPhotoIndex = 0;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final conversationService = Provider.of<ConversationService>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (currentUser != null)
            Consumer<SavedAdsProvider>(
              builder: (context, savedAdsProvider, _) {
                final isSaved = savedAdsProvider.isAdSaved(widget.ad.id);
                return IconButton(
                  icon: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: isSaved ? Colors.blue[700] : Colors.grey[800],
                  ),
                  onPressed: () => _handleSaveAd(savedAdsProvider, isSaved),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPhotoCarousel(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildExchangeTypeChip(),
                  const SizedBox(height: 12),
                  Text(
                    widget.ad.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.ad.formattedDate,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildInfoSection('Description', widget.ad.description),
                  const SizedBox(height: 16),
                  _buildInfoSection(
                    'Souhaité en échange',
                    widget.ad.additionalData['wishInReturn'] ?? 'Non spécifié',
                  ),
                  const SizedBox(height: 16),
                  if (widget.ad.additionalData['exchangeType'] ==
                      'Article') ...[
                    _buildArticleDetails(),
                  ] else if (widget.ad.additionalData['exchangeType'] ==
                      'Temps et Compétences') ...[
                    _buildServiceDetails(),
                  ],
                  const SizedBox(height: 24),
                  _buildLocationSection(),
                  const SizedBox(height: 24),
                  _buildUserSection(currentUser, conversationService),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCarousel() {
    return Stack(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 300,
            viewportFraction: 1.0,
            enableInfiniteScroll: false,
            onPageChanged: (index, reason) {
              setState(() => _currentPhotoIndex = index);
            },
          ),
          items: widget.ad.photos.map((url) {
            return Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
            );
          }).toList(),
        ),
        if (widget.ad.photos.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: widget.ad.photos.asMap().entries.map((entry) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPhotoIndex == entry.key
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildExchangeTypeChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        widget.ad.additionalData['exchangeType'] ?? 'Échange',
        style: TextStyle(
          color: Colors.blue[700],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildArticleDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoSection(
            'État', widget.ad.additionalData['condition'] ?? 'Non spécifié'),
        if (widget.ad.additionalData['brand']?.isNotEmpty ?? false) ...[
          const SizedBox(height: 16),
          _buildInfoSection('Marque', widget.ad.additionalData['brand']),
        ],
        const SizedBox(height: 16),
        _buildInfoSection(
          'Préférence de rencontre',
          widget.ad.additionalData['meetingPreference'] ?? 'Non spécifié',
        ),
      ],
    );
  }

  Widget _buildServiceDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoSection(
          'Expérience',
          widget.ad.additionalData['experience'] ?? 'Non spécifié',
        ),
        const SizedBox(height: 16),
        _buildInfoSection(
          'Disponibilité',
          widget.ad.additionalData['availability'] ?? 'Non spécifié',
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.ad.additionalData['location'] ?? 'Non spécifié',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSection(
      User? currentUser, ConversationService conversationService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Proposé par',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Profile(userId: widget.ad.userId),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(widget.ad.userProfilePicture),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.ad.userName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (currentUser != null && currentUser.uid != widget.ad.userId)
                ElevatedButton.icon(
                  onPressed: () =>
                      _startConversation(currentUser, conversationService),
                  icon: const Icon(Icons.message_outlined, size: 20),
                  label: const Text('Contacter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleSaveAd(SavedAdsProvider provider, bool isSaved) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await provider.toggleSaveAd(currentUser.uid, widget.ad.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSaved
                ? 'Annonce retirée des favoris'
                : 'Annonce ajoutée aux favoris',
          ),
          backgroundColor: Colors.blue[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Une erreur est survenue'),
          backgroundColor: Colors.red[400],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _startConversation(User currentUser, ConversationService service) async {
    try {
      final conversationId = await service.getOrCreateConversationForAd(
        currentUser.uid,
        widget.ad.userId,
        widget.ad.id,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConversationDetailScreen(
            conversationId: conversationId,
            otherUserName: widget.ad.userName,
            ad: widget.ad,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de démarrer la conversation'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
