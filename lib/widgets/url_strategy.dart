// lib/widgets/url_strategy.dart

import 'package:flutter/foundation.dart';

void initializeUrlStrategy() {
  if (kIsWeb) {
    // Cette fonction sera vide pour iOS
    _initializeForWeb();
  }
}

// On isole le code web dans une fonction séparée
// qui ne sera jamais appelée sur mobile
void _initializeForWeb() {
  if (kIsWeb) {
    try {
      Uri.base;
    } catch (e) {
      debugPrint('Error initializing URL strategy: $e');
    }
  }
}
