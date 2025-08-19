import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class CartRestaurantService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final Map<String, RestaurantCart> _carts = {};
  bool _isLoading = false;
  String? _error;
  String? _currentUserId;

  Map<String, RestaurantCart> get carts => _carts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  RestaurantCart? getCartForRestaurant(String restaurantId) => _carts[restaurantId];

  int get totalItemCount => _carts.values.fold(0, (sum, cart) => sum + cart.itemCount);

  double get totalAmount => _carts.values.fold(0.0, (sum, cart) => sum + cart.totalAmount);

  Future<void> loadUserCarts(String userId) async {
    if (_currentUserId == userId && _carts.isNotEmpty) return;

    _currentUserId = userId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final querySnapshot = await _firestore
          .collection('cartRestaurant')
          .where('userId', isEqualTo: userId)
          .get();

      _carts.clear();
      for (final doc in querySnapshot.docs) {
        final cart = RestaurantCart.fromFirestore(doc);
        _carts[cart.restaurantId] = cart;
      }

      debugPrint('${_carts.length} paniers chargés');
    } catch (e) {
      _error = 'Erreur lors du chargement des paniers: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addItemToCart({
    required String userId,
    required String restaurantId,
    required String restaurantName,
    required String restaurantLogo,
    required CartItem item,
  }) async {
    try {
      RestaurantCart cart = _carts[restaurantId] ?? RestaurantCart(
        id: '',
        userId: userId,
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        restaurantLogo: restaurantLogo,
        items: [],
        totalAmount: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final existingItemIndex = cart.items.indexWhere((cartItem) => 
        _areItemsIdentical(cartItem, item));

      List<CartItem> updatedItems;
      if (existingItemIndex != -1) {
        updatedItems = List.from(cart.items);
        final existingItem = updatedItems[existingItemIndex];
        updatedItems[existingItemIndex] = existingItem.copyWith(
          quantity: existingItem.quantity + item.quantity,
          totalPrice: existingItem.unitPrice * (existingItem.quantity + item.quantity),
        );
      } else {
        updatedItems = [...cart.items, item];
      }

      final newTotalAmount = updatedItems.fold(0.0, (sum, cartItem) => sum + cartItem.totalPrice);

      final updatedCart = cart.copyWith(
        items: updatedItems,
        totalAmount: newTotalAmount,
        updatedAt: DateTime.now(),
      );

      // Sauvegarder dans Firestore et récupérer le panier avec l'ID correct
      final savedCart = await _saveCartToFirestore(updatedCart);
      _carts[restaurantId] = savedCart;
      notifyListeners();

      debugPrint('Item ajouté au panier');
    } catch (e) {
      _error = 'Erreur lors de l\'ajout au panier: $e';
      debugPrint(_error);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> clearCart(String restaurantId) async {
    try {
      final cart = _carts[restaurantId];
      if (cart == null) return;

      if (cart.id.isNotEmpty) {
        await _firestore.collection('cartRestaurant').doc(cart.id).delete();
      }

      _carts.remove(restaurantId);
      notifyListeners();

      debugPrint('Panier vidé');
    } catch (e) {
      _error = 'Erreur lors de la suppression: $e';
      debugPrint(_error);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> clearAllCarts() async {
    _carts.clear();
    notifyListeners();
  }

  Future<void> updateItemQuantity({
    required String restaurantId,
    required String itemId,
    required int newQuantity,
  }) async {
    try {
      final cart = _carts[restaurantId];
      if (cart == null) return;

      if (newQuantity <= 0) {
        await removeItemFromCart(restaurantId: restaurantId, itemId: itemId);
        return;
      }

      final itemIndex = cart.items.indexWhere((item) => item.id == itemId);
      if (itemIndex == -1) return;

      final updatedItems = List<CartItem>.from(cart.items);
      final item = updatedItems[itemIndex];
      
      updatedItems[itemIndex] = item.copyWith(
        quantity: newQuantity,
        totalPrice: item.unitPrice * newQuantity,
      );

      final newTotalAmount = updatedItems.fold(0.0, (sum, cartItem) => sum + cartItem.totalPrice);

      final updatedCart = cart.copyWith(
        items: updatedItems,
        totalAmount: newTotalAmount,
        updatedAt: DateTime.now(),
      );

      final savedCart = await _saveCartToFirestore(updatedCart);
      _carts[restaurantId] = savedCart;
      notifyListeners();

      debugPrint('Quantité mise à jour: $newQuantity');
    } catch (e) {
      _error = 'Erreur lors de la mise à jour: $e';
      debugPrint(_error);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> removeItemFromCart({
    required String restaurantId,
    required String itemId,
  }) async {
    try {
      final cart = _carts[restaurantId];
      if (cart == null) return;

      final updatedItems = cart.items.where((item) => item.id != itemId).toList();
      
      if (updatedItems.isEmpty) {
        await clearCart(restaurantId);
        return;
      }

      final newTotalAmount = updatedItems.fold(0.0, (sum, cartItem) => sum + cartItem.totalPrice);

      final updatedCart = cart.copyWith(
        items: updatedItems,
        totalAmount: newTotalAmount,
        updatedAt: DateTime.now(),
      );

      final savedCart = await _saveCartToFirestore(updatedCart);
      _carts[restaurantId] = savedCart;
      notifyListeners();

      debugPrint('Article supprimé du panier');
    } catch (e) {
      _error = 'Erreur lors de la suppression: $e';
      debugPrint(_error);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateMenuItem({
    required String restaurantId,
    required String itemId,
    required CartItem updatedItem,
  }) async {
    try {
      final cart = _carts[restaurantId];
      if (cart == null) return;

      final itemIndex = cart.items.indexWhere((item) => item.id == itemId);
      if (itemIndex == -1) return;

      final updatedItems = List<CartItem>.from(cart.items);
      updatedItems[itemIndex] = updatedItem.copyWith(
        id: itemId, // Conserver l'ID original
        addedAt: updatedItems[itemIndex].addedAt, // Conserver la date d'ajout
        updatedAt: DateTime.now(),
      );

      final newTotalAmount = updatedItems.fold(0.0, (sum, cartItem) => sum + cartItem.totalPrice);

      final updatedCart = cart.copyWith(
        items: updatedItems,
        totalAmount: newTotalAmount,
        updatedAt: DateTime.now(),
      );

      final savedCart = await _saveCartToFirestore(updatedCart);
      _carts[restaurantId] = savedCart;
      notifyListeners();

      debugPrint('Article modifié dans le panier');
    } catch (e) {
      _error = 'Erreur lors de la modification: $e';
      debugPrint(_error);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateCustomerMessage({
    required String restaurantId,
    required String message,
  }) async {
    try {
      final cart = _carts[restaurantId];
      if (cart == null) return;

      final updatedCart = cart.copyWith(
        customerMessage: message,
        updatedAt: DateTime.now(),
      );

      final savedCart = await _saveCartToFirestore(updatedCart);
      _carts[restaurantId] = savedCart;
      notifyListeners();

      debugPrint('Message client mis à jour');
    } catch (e) {
      _error = 'Erreur lors de la mise à jour du message: $e';
      debugPrint(_error);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateDeliverySchedule({
    required String restaurantId,
    required DateTime? scheduledTime,
    required String deliveryType,
  }) async {
    try {
      final cart = _carts[restaurantId];
      if (cart == null) return;

      final updatedCart = cart.copyWith(
        scheduledTime: scheduledTime,
        deliveryType: deliveryType,
        updatedAt: DateTime.now(),
      );

      final savedCart = await _saveCartToFirestore(updatedCart);
      _carts[restaurantId] = savedCart;
      notifyListeners();

      debugPrint('Planification de livraison mise à jour');
    } catch (e) {
      _error = 'Erreur lors de la mise à jour de la planification: $e';
      debugPrint(_error);
      notifyListeners();
      rethrow;
    }
  }

  Future<RestaurantCart> _saveCartToFirestore(RestaurantCart cart) async {
    if (cart.id.isEmpty) {
      final docRef = await _firestore.collection('cartRestaurant').add(cart.toMap());
      final newCart = cart.copyWith(id: docRef.id);
      return newCart;
    } else {
      await _firestore.collection('cartRestaurant').doc(cart.id).update(cart.toMap());
      return cart;
    }
  }

  bool _areItemsIdentical(CartItem item1, CartItem item2) {
    // Vérifier le type et l'ID de base
    if (item1.type != item2.type || item1.itemId != item2.itemId) {
      return false;
    }

    // Pour les menus, vérifier aussi les options et l'article principal
    if (item1.type == 'menu') {
      // Comparer l'article principal et ses variantes
      if (!_areMainItemsIdentical(item1.mainItem, item2.mainItem)) {
        return false;
      }
      
      // Comparer les options
      if (!_areOptionsIdentical(item1.options, item2.options)) {
        return false;
      }
    }
    
    // Pour les articles simples, comparer les variantes
    if (item1.type == 'item') {
      if (!_areVariantsIdentical(item1.variants, item2.variants)) {
        return false;
      }
    }

    return true;
  }

  bool _areMainItemsIdentical(CartMainItem? main1, CartMainItem? main2) {
    if (main1 == null && main2 == null) return true;
    if (main1 == null || main2 == null) return false;
    
    return main1.itemId == main2.itemId && 
           _areVariantsIdentical(main1.variants, main2.variants);
  }

  bool _areOptionsIdentical(List<CartOption>? options1, List<CartOption>? options2) {
    if (options1 == null && options2 == null) return true;
    if (options1 == null || options2 == null) return false;
    if (options1.length != options2.length) return false;

    for (int i = 0; i < options1.length; i++) {
      final opt1 = options1[i];
      final opt2 = options2[i];
      
      if (opt1.templateId != opt2.templateId || 
          opt1.item.itemId != opt2.item.itemId ||
          !_areVariantsIdentical(opt1.item.variants, opt2.item.variants)) {
        return false;
      }
    }

    return true;
  }

  bool _areVariantsIdentical(List<CartItemVariant>? variants1, List<CartItemVariant>? variants2) {
    if (variants1 == null && variants2 == null) return true;
    if (variants1 == null || variants2 == null) return false;
    if (variants1.length != variants2.length) return false;

    for (int i = 0; i < variants1.length; i++) {
      final var1 = variants1[i];
      final var2 = variants2[i];
      
      if (var1.variantId != var2.variantId || 
          var1.selectedOption.name != var2.selectedOption.name) {
        return false;
      }
    }

    return true;
  }

  void clear() {
    _carts.clear();
    _currentUserId = null;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}

class RestaurantCart {
  final String id;
  final String userId;
  final String restaurantId;
  final String restaurantName;
  final String restaurantLogo;
  final List<CartItem> items;
  final double totalAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? customerMessage; // Message libre du client
  final DateTime? scheduledTime; // Heure de livraison planifiée
  final String deliveryType; // 'asap' ou 'scheduled'

  RestaurantCart({
    required this.id,
    required this.userId,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantLogo,
    required this.items,
    required this.totalAmount,
    required this.createdAt,
    required this.updatedAt,
    this.customerMessage,
    this.scheduledTime,
    this.deliveryType = 'asap',
  });

  factory RestaurantCart.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return RestaurantCart(
      id: doc.id,
      userId: data['userId']?.toString() ?? '',
      restaurantId: data['restaurantId']?.toString() ?? '',
      restaurantName: data['restaurantName']?.toString() ?? '',
      restaurantLogo: data['restaurantLogo']?.toString() ?? '',
      items: (data['items'] as List? ?? [])
          .map((item) => CartItem.fromMap(item as Map<String, dynamic>))
          .toList(),
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.parse(data['createdAt']?.toString() ?? DateTime.now().toIso8601String()),
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(data['updatedAt']?.toString() ?? DateTime.now().toIso8601String()),
      customerMessage: data['customerMessage']?.toString(),
      scheduledTime: data['scheduledTime'] != null
          ? (data['scheduledTime'] is Timestamp
              ? (data['scheduledTime'] as Timestamp).toDate()
              : DateTime.parse(data['scheduledTime'].toString()))
          : null,
      deliveryType: data['deliveryType']?.toString() ?? 'asap',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'restaurantLogo': restaurantLogo,
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'customerMessage': customerMessage,
      'scheduledTime': scheduledTime != null ? Timestamp.fromDate(scheduledTime!) : null,
      'deliveryType': deliveryType,
    };
  }

  RestaurantCart copyWith({
    String? id,
    String? userId,
    String? restaurantId,
    String? restaurantName,
    String? restaurantLogo,
    List<CartItem>? items,
    double? totalAmount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? customerMessage,
    DateTime? scheduledTime,
    String? deliveryType,
  }) {
    return RestaurantCart(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      restaurantLogo: restaurantLogo ?? this.restaurantLogo,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customerMessage: customerMessage ?? this.customerMessage,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      deliveryType: deliveryType ?? this.deliveryType,
    );
  }

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  // Calculs TVA pour le panier complet
  double get totalAmountHT => items.fold(0.0, (sum, item) => sum + item.totalPriceHT);
  double get totalVatAmount => items.fold(0.0, (sum, item) => sum + item.vatAmount);
  double get totalAmountTTC => totalAmount; // Le montant total est déjà TTC
}

class CartItem {
  final String id;
  final String type;
  final String itemId;
  final String name;
  final String? description;
  final List<String> images;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final double vatRate; // Taux de TVA (ex: 10.0 pour 10%)
  final List<CartItemVariant>? variants;
  final String? menuId;
  final String? menuName;
  final CartMainItem? mainItem;
  final List<CartOption>? options;
  final DateTime addedAt;
  final DateTime? updatedAt;

  CartItem({
    required this.id,
    required this.type,
    required this.itemId,
    required this.name,
    this.description,
    required this.images,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.vatRate = 10.0, // TVA par défaut pour l'alimentation en France
    this.variants,
    this.menuId,
    this.menuName,
    this.mainItem,
    this.options,
    required this.addedAt,
    this.updatedAt,
  });

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? 'item',
      itemId: map['itemId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString(),
      images: List<String>.from(map['images'] ?? []),
      quantity: (map['quantity'] ?? 1) is int ? map['quantity'] : int.tryParse(map['quantity'].toString()) ?? 1,
      unitPrice: (map['unitPrice'] ?? 0.0).toDouble(),
      totalPrice: (map['totalPrice'] ?? 0.0).toDouble(),
      vatRate: (map['vatRate'] ?? 10.0).toDouble(), // TVA par défaut 10% alimentation
      variants: map['variants'] != null 
          ? (map['variants'] as List).map((v) => CartItemVariant.fromMap(v as Map<String, dynamic>)).toList()
          : null,
      menuId: map['menuId']?.toString(),
      menuName: map['menuName']?.toString(),
      mainItem: map['mainItem'] != null 
          ? CartMainItem.fromMap(map['mainItem'] as Map<String, dynamic>)
          : null,
      options: map['options'] != null 
          ? (map['options'] as List).map((o) => CartOption.fromMap(o as Map<String, dynamic>)).toList()
          : null,
      addedAt: map['addedAt'] is Timestamp
          ? (map['addedAt'] as Timestamp).toDate()
          : DateTime.parse(map['addedAt']?.toString() ?? DateTime.now().toIso8601String()),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] is Timestamp
              ? (map['updatedAt'] as Timestamp).toDate()
              : DateTime.parse(map['updatedAt'].toString()))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'itemId': itemId,
      'name': name,
      'description': description,
      'images': images,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'vatRate': vatRate,
      'variants': variants?.map((v) => v.toMap()).toList(),
      'menuId': menuId,
      'menuName': menuName,
      'mainItem': mainItem?.toMap(),
      'options': options?.map((o) => o.toMap()).toList(),
      'addedAt': Timestamp.fromDate(addedAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  CartItem copyWith({
    String? id,
    String? type,
    String? itemId,
    String? name,
    String? description,
    List<String>? images,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
    double? vatRate,
    List<CartItemVariant>? variants,
    String? menuId,
    String? menuName,
    CartMainItem? mainItem,
    List<CartOption>? options,
    DateTime? addedAt,
    DateTime? updatedAt,
  }) {
    return CartItem(
      id: id ?? this.id,
      type: type ?? this.type,
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      description: description ?? this.description,
      images: images ?? this.images,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      vatRate: vatRate ?? this.vatRate,
      variants: variants ?? this.variants,
      menuId: menuId ?? this.menuId,
      menuName: menuName ?? this.menuName,
      mainItem: mainItem ?? this.mainItem,
      options: options ?? this.options,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Méthodes pour calculer la TVA
  double get totalPriceHT => totalPrice / (1 + vatRate / 100);
  double get vatAmount => totalPrice - totalPriceHT;
}

class CartItemVariant {
  final String variantId;
  final String name;
  final CartSelectedOption selectedOption;

  CartItemVariant({
    required this.variantId,
    required this.name,
    required this.selectedOption,
  });

  factory CartItemVariant.fromMap(Map<String, dynamic> map) {
    return CartItemVariant(
      variantId: map['variantId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      selectedOption: CartSelectedOption.fromMap(map['selectedOption'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'variantId': variantId,
      'name': name,
      'selectedOption': selectedOption.toMap(),
    };
  }
}

class CartSelectedOption {
  final String name;
  final double priceModifier;

  CartSelectedOption({
    required this.name,
    required this.priceModifier,
  });

  factory CartSelectedOption.fromMap(Map<String, dynamic> map) {
    return CartSelectedOption(
      name: map['name']?.toString() ?? '',
      priceModifier: (map['priceModifier'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'priceModifier': priceModifier,
    };
  }
}

class CartMainItem {
  final String itemId;
  final String name;
  final List<CartItemVariant>? variants;

  CartMainItem({
    required this.itemId,
    required this.name,
    this.variants,
  });

  factory CartMainItem.fromMap(Map<String, dynamic> map) {
    return CartMainItem(
      itemId: map['itemId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      variants: map['variants'] != null 
          ? (map['variants'] as List).map((v) => CartItemVariant.fromMap(v as Map<String, dynamic>)).toList()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'name': name,
      'variants': variants?.map((v) => v.toMap()).toList(),
    };
  }
}

class CartOption {
  final String templateId;
  final String templateName;
  final CartOptionItem item;

  CartOption({
    required this.templateId,
    required this.templateName,
    required this.item,
  });

  factory CartOption.fromMap(Map<String, dynamic> map) {
    return CartOption(
      templateId: map['templateId']?.toString() ?? '',
      templateName: map['templateName']?.toString() ?? '',
      item: CartOptionItem.fromMap(map['item'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'templateId': templateId,
      'templateName': templateName,
      'item': item.toMap(),
    };
  }
}

class CartOptionItem {
  final String itemId;
  final String name;
  final List<CartItemVariant>? variants;

  CartOptionItem({
    required this.itemId,
    required this.name,
    this.variants,
  });

  factory CartOptionItem.fromMap(Map<String, dynamic> map) {
    return CartOptionItem(
      itemId: map['itemId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      variants: map['variants'] != null 
          ? (map['variants'] as List).map((v) => CartItemVariant.fromMap(v as Map<String, dynamic>)).toList()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'name': name,
      'variants': variants?.map((v) => v.toMap()).toList(),
    };
  }
}