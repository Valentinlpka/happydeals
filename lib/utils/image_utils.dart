import 'package:flutter/material.dart';

class ImageUtils {
  /// Vérifie si une URL d'image est valide
  static bool isValidImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    
    try {
      final uri = Uri.parse(url.trim());
      return uri.hasScheme && 
             (uri.scheme == 'http' || uri.scheme == 'https') && 
             uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Widget sécurisé pour afficher une image réseau
  static Widget safeNetworkImage({
    required String? imageUrl,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? placeholder,
    Widget? errorWidget,
    Color? backgroundColor,
  }) {
    // Si l'URL n'est pas valide, retourner le widget d'erreur
    if (!isValidImageUrl(imageUrl)) {
      return errorWidget ?? _buildDefaultErrorWidget(backgroundColor);
    }

    return Image.network(
      imageUrl!,
      fit: fit,
      width: width,
      height: height,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        
        return placeholder ?? Container(
          width: width,
          height: height,
          color: backgroundColor ?? Colors.grey[100],
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
        return errorWidget ?? _buildDefaultErrorWidget(backgroundColor);
      },
    );
  }

  /// Widget d'erreur par défaut
  static Widget _buildDefaultErrorWidget(Color? backgroundColor) {
    return Container(
      color: backgroundColor ?? Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
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
  }

  /// Obtient la première image valide d'une liste
  static String? getFirstValidImage(List<String>? images) {
    if (images == null || images.isEmpty) return null;
    
    for (final image in images) {
      if (isValidImageUrl(image)) {
        return image;
      }
    }
    
    return null;
  }

  /// Filtre une liste d'images pour ne garder que les valides
  static List<String> filterValidImages(List<String>? images) {
    if (images == null) return [];
    
    return images.where((image) => isValidImageUrl(image)).toList();
  }
}
