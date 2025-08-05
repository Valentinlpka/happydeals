import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:happy/classes/menu_item.dart';

class RestaurantMenuProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<RestaurantMenuCategory> _categories = [];
  List<MenuItem> _menuItems = [];
  List<RestaurantMenu> _menus = [];
  List<RestaurantPromotion> _promotions = [];
  
  bool _isLoading = false;
  String? _error;
  String? _currentRestaurantId;

  // Getters
  List<RestaurantMenuCategory> get categories => _categories;
  List<MenuItem> get menuItems => _menuItems;
  List<RestaurantMenu> get menus => _menus;
  List<RestaurantPromotion> get promotions => _promotions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Getters filtrés
  List<MenuItem> getItemsByCategory(String categoryId) {
    return _menuItems
        .where((item) => 
            item.categoryId == categoryId && 
            item.isActive && 
            item.isAvailable &&
            item.availability.canBeSoldAlone)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  List<RestaurantMenu> getMenusByCategory(String categoryId) {
    return _menus
        .where((menu) => 
            menu.categoryId == categoryId && 
            menu.isActive && 
            menu.isAvailable)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  List<RestaurantPromotion> getActivePromotions() {
    return _promotions
        .where((promo) => promo.isValidNow())
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
  }

  List<RestaurantPromotion> getPromotionsForItem(String itemId) {
    return getActivePromotions()
        .where((promo) => 
            promo.conditions?.applicableItemIds?.contains(itemId) ?? false)
        .toList();
  }

  List<RestaurantPromotion> getPromotionsForCategory(String categoryId) {
    return getActivePromotions()
        .where((promo) => 
            promo.conditions?.applicableCategoryIds?.contains(categoryId) ?? false)
        .toList();
  }

  // Chargement des données
  Future<void> loadRestaurantMenu(String restaurantId) async {
    if (_currentRestaurantId == restaurantId && _categories.isNotEmpty) {
      return; // Déjà chargé
    }

    _currentRestaurantId = restaurantId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadCategories(restaurantId),
        _loadMenuItems(restaurantId),
        _loadMenus(restaurantId),
        _loadPromotions(restaurantId),
      ]);

      _error = null;
    } catch (e) {
      _error = 'Erreur lors du chargement du menu: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCategories(String restaurantId) async {
    try {
      final querySnapshot = await _firestore
          .collection('menuCategories')
          .where('companyId', isEqualTo: restaurantId)
          .orderBy('order')
          .get();

      _categories = querySnapshot.docs
          .map((doc) => RestaurantMenuCategory.fromFirestore(doc))
          .toList();
      
      debugPrint('${_categories.length} catégories chargées');
    } catch (e) {
      debugPrint('Erreur lors du chargement des catégories: $e');
      throw Exception('Impossible de charger les catégories');
    }
  }

  Future<void> _loadMenuItems(String restaurantId) async {
    try {
      final querySnapshot = await _firestore
          .collection('menuItems')
          .where('companyId', isEqualTo: restaurantId)
          .where('isActive', isEqualTo: true)
          .orderBy('sortOrder')
          .get();

      _menuItems = querySnapshot.docs
          .map((doc) => MenuItem.fromFirestore(doc))
          .toList();
      
      debugPrint('${_menuItems.length} articles chargés');
    } catch (e) {
      debugPrint('Erreur lors du chargement des articles: $e');
      throw Exception('Impossible de charger les articles');
    }
  }

  Future<void> _loadMenus(String restaurantId) async {
    try {
      final querySnapshot = await _firestore
          .collection('menus')
          .where('companyId', isEqualTo: restaurantId)
          .where('isActive', isEqualTo: true)
          .orderBy('sortOrder')
          .get();

      _menus = querySnapshot.docs
          .map((doc) => RestaurantMenu.fromFirestore(doc))
          .toList();
      
      debugPrint('${_menus.length} menus chargés');
    } catch (e) {
      debugPrint('Erreur lors du chargement des menus: $e');
      throw Exception('Impossible de charger les menus');
    }
  }

  Future<void> _loadPromotions(String restaurantId) async {
    try {
      final querySnapshot = await _firestore
          .collection('promotions')
          .where('companyId', isEqualTo: restaurantId)
          .where('active', isEqualTo: true)
          .orderBy('sortOrder')
          .get();

      _promotions = querySnapshot.docs
          .map((doc) => RestaurantPromotion.fromFirestore(doc))
          .toList();
      
      debugPrint('${_promotions.length} promotions chargées');
    } catch (e) {
      debugPrint('Erreur lors du chargement des promotions: $e');
      // Les promotions ne sont pas critiques, on continue sans elles
      _promotions = [];
    }
  }

  // Charger un template depuis Firebase
  Future<Template?> getTemplate(String templateId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('menuTemplates')
          .doc(templateId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      final type = data['type']?.toString() ?? '';

      if (type == 'menu') {
        return MenuTemplate.fromFirestore(doc);
      } else if (type == 'variant') {
        return VariantTemplate.fromFirestore(doc);
      }

      return Template.fromFirestore(doc);
    } catch (e) {
      print('Erreur lors du chargement du template $templateId: $e');
      return null;
    }
  }

  // Charger le template de menu et tous ses templates de variantes
  Future<Map<String, dynamic>?> loadMenuTemplates(String menuTemplateId) async {
    try {
      final menuTemplate = await getTemplate(menuTemplateId);
      if (menuTemplate == null || !isMenuTemplate(menuTemplate)) {
        return null;
      }

      final menuTemplateTyped = menuTemplate as MenuTemplate;
      final Map<String, VariantTemplate> variantTemplates = {};

      // Charger tous les templates de variantes
      for (final includedTemplate in menuTemplateTyped.includedVariantTemplates) {
        final variantTemplate = await getTemplate(includedTemplate.templateId);
        if (variantTemplate != null && isVariantTemplate(variantTemplate)) {
          variantTemplates[includedTemplate.templateId] = variantTemplate as VariantTemplate;
        }
      }

      return {
        'menuTemplate': menuTemplateTyped,
        'variantTemplates': variantTemplates,
      };
    } catch (e) {
      print('Erreur lors du chargement des templates pour le menu $menuTemplateId: $e');
      return null;
    }
  }

  // Actualisation
  Future<void> refresh() async {
    if (_currentRestaurantId != null) {
      _categories.clear();
      _menuItems.clear();
      _menus.clear();
      _promotions.clear();
      await loadRestaurantMenu(_currentRestaurantId!);
    }
  }

  // Recherche
  List<MenuItem> searchItems(String query) {
    if (query.isEmpty) return [];
    
    final lowerQuery = query.toLowerCase();
    return _menuItems
        .where((item) => 
            item.isActive && 
            item.isAvailable &&
            item.availability.canBeSoldAlone &&
            (item.name.toLowerCase().contains(lowerQuery) ||
             item.description.toLowerCase().contains(lowerQuery) ||
             item.tags.any((tag) => tag.toLowerCase().contains(lowerQuery))))
        .toList();
  }

  List<RestaurantMenu> searchMenus(String query) {
    if (query.isEmpty) return [];
    
    final lowerQuery = query.toLowerCase();
    return _menus
        .where((menu) => 
            menu.isActive && 
            menu.isAvailable &&
            (menu.name.toLowerCase().contains(lowerQuery) ||
             menu.description.toLowerCase().contains(lowerQuery) ||
             menu.tags.any((tag) => tag.toLowerCase().contains(lowerQuery))))
        .toList();
  }

  // Calcul du prix avec promotions
  double calculateItemPrice(MenuItem item) {
    double price = item.basePrice;
    
    final itemPromotions = getPromotionsForItem(item.id);
    final categoryPromotions = getPromotionsForCategory(item.categoryId);
    
    // Appliquer les promotions (stackables en premier par priorité)
    final allPromotions = [...itemPromotions, ...categoryPromotions]
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final promo in allPromotions) {
      final discount = promo.calculateDiscount(price);
      price = (price - discount).clamp(0.0, double.infinity);
      
      if (!promo.stackable) break; // Arrêter si la promotion n'est pas cumulable
    }

    return price;
  }

  double calculateMenuPrice(RestaurantMenu menu) {
    double price = menu.basePrice;
    
    // Appliquer les promotions pour les menus si applicables
    final menuPromotions = getActivePromotions()
        .where((promo) => promo.conditions?.applicableMenuIds?.contains(menu.id) ?? false)
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final promo in menuPromotions) {
      final discount = promo.calculateDiscount(price);
      price = (price - discount).clamp(0.0, double.infinity);
      
      if (!promo.stackable) break;
    }

    return price;
  }

  // Vérifier si un item a des promotions actives
  bool itemHasActivePromotion(String itemId, String categoryId) {
    return getPromotionsForItem(itemId).isNotEmpty ||
           getPromotionsForCategory(categoryId).isNotEmpty;
  }

  bool menuHasActivePromotion(String menuId) {
    return getActivePromotions()
        .any((promo) => promo.conditions?.applicableMenuIds?.contains(menuId) ?? false);
  }

  // Obtenir un article par ID
  MenuItem? getItemById(String itemId) {
    try {
      return _menuItems.firstWhere((item) => item.id == itemId);
    } catch (e) {
      return null;
    }
  }

  // Obtenir un menu par ID  
  RestaurantMenu? getMenuById(String menuId) {
    try {
      return _menus.firstWhere((menu) => menu.id == menuId);
    } catch (e) {
      return null;
    }
  }

  // Obtenir une catégorie par ID
  RestaurantMenuCategory? getCategoryById(String categoryId) {
    try {
      return _categories.firstWhere((category) => category.id == categoryId);
    } catch (e) {
      return null;
    }
  }

  // Nettoyer les données
  void clear() {
    _categories.clear();
    _menuItems.clear();
    _menus.clear();
    _promotions.clear();
    _currentRestaurantId = null;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
} 