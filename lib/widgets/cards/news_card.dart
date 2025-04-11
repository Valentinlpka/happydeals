import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:happy/classes/news.dart';
import 'package:happy/widgets/custom_image_viewer.dart';
import 'package:happy/widgets/video_player_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class NewsCard extends StatelessWidget {
  final News news;
  final String companyLogo;
  final String companyName;

  const NewsCard({
    super.key,
    required this.news,
    required this.companyLogo,
    required this.companyName,
  });

  Widget _buildMediaGallery(BuildContext context) {
    final List<String> allMedia = [...news.photos, ...news.videos];

    if (allMedia.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: allMedia.length,
              itemBuilder: (context, index) {
                final String mediaUrl = allMedia[index];
                final bool isVideo = news.videos.contains(mediaUrl);

                return GestureDetector(
                  onTap: () {
                    if (isVideo) {
                      _showVideoPlayer(context, mediaUrl);
                    } else {
                      _showImageViewer(context, index, news.photos);
                    }
                  },
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index != allMedia.length - 1 ? 8 : 0,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: isVideo
                          ? _buildVideoThumbnail(mediaUrl)
                          : _buildImageThumbnail(mediaUrl),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoThumbnail(String videoUrl) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 200,
          height: 200,
          color: Colors.black,
        ),
        const Icon(
          Icons.play_circle_fill,
          color: Colors.white,
          size: 48,
        ),
      ],
    );
  }

  Widget _buildImageThumbnail(String imageUrl) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: 200,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: 200,
          height: 200,
          color: Colors.grey[100],
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: 200,
          height: 200,
          color: Colors.grey[100],
          child: const Center(
            child: Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 32,
            ),
          ),
        );
      },
    );
  }

  void _showVideoPlayer(BuildContext context, String videoUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(videoUrl: videoUrl),
      ),
    );
  }

  void _showImageViewer(BuildContext context, int index, List<String> images) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (BuildContext context, _, __) {
          return CustomImageViewer(
            imageUrl: images[index],
            allImages: images,
            currentIndex: index,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = 0.0;
          const end = 1.0;
          var curve = Curves.easeInOut;
          var fadeTween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildArticlePreview() {
    if (news.articleUrl == null || news.articleUrl!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey[50],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: GestureDetector(
        onTap: () => _launchURL(news.articleUrl!),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (news.articlePreview?.image != null)
              Stack(
                children: [
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: kIsWeb
                        ? _buildWebImage(news.articlePreview!.image!)
                        : Image.network(
                            news.articlePreview!.image!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                  ),
                  // Overlay gradient
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withAlpha(20),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Source badge
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(90),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.article_outlined,
                            size: 16,
                            color: Colors.grey[800],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            Uri.parse(news.articleUrl!)
                                .host
                                .replaceAll('www.', ''),
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (news.articlePreview?.title != null)
                    Text(
                      news.articlePreview!.title!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (news.articlePreview?.description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      news.articlePreview!.description!,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.open_in_new,
                        size: 16,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Lire l\'article',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebImage(String url, {BoxFit fit = BoxFit.cover}) {
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey[100],
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Erreur de chargement de l\'image: $error');
        return Container(
          color: Colors.grey[100],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 40,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  'Image non disponible',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _launchURL(String url) async {
    try {
      Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'ouverture du lien: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Contenu de l'actualité
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre
                Text(
                  news.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                // Contenu
                Text(
                  news.content,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.grey[800],
                  ),
                ),

                _buildArticlePreview(),

                _buildMediaGallery(context),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
