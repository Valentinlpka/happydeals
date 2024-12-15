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
    // Ceci ne sera exécuté que sur le web
    dynamic web;
    try {
      web = Uri.base;
    } catch (e) {
      print('Error initializing URL strategy: $e');
    }
  }
}
