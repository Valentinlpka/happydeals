# Gestion des Commandes de Restaurant

Ce dossier contient les pages et services pour gérer les commandes de restaurant dans l'application.

## Fichiers

### `user_restaurant_orders_page.dart`
Page principale pour afficher la liste des commandes de restaurant d'un utilisateur.

**Fonctionnalités :**
- Affichage de toutes les commandes de restaurant de l'utilisateur connecté
- Tri par date (plus récentes en premier)
- Statuts visuels avec codes couleur
- Barre de progression pour les commandes en cours
- Navigation vers la page de détail de chaque commande
- Gestion des états de chargement et d'erreur

**Statuts supportés :**
- `pending` : En attente
- `confirmed` : Confirmée
- `preparing` : En préparation
- `ready` : Prête
- `delivering` : En livraison
- `delivered` : Livrée
- `cancelled` : Annulée

### `restaurant_order_service.dart`
Service pour interagir avec Firestore et gérer les commandes de restaurant.

**Méthodes :**
- `getUserRestaurantOrders(userId)` : Récupère toutes les commandes d'un utilisateur
- `getRestaurantOrder(orderId)` : Récupère une commande spécifique
- `updateOrderStatus(orderId, newStatus)` : Met à jour le statut d'une commande
- `cancelOrder(orderId, reason)` : Annule une commande

## Intégration

### Navigation depuis les paramètres
La page est accessible depuis les paramètres utilisateur via l'élément "Mes commandes restaurant".

### Navigation depuis le checkout
Un bouton d'historique est disponible dans la page de checkout pour accéder directement à la liste des commandes.

## Modèle de données

Les commandes utilisent le modèle `RestaurantOrder` défini dans `lib/models/restaurant_order.dart` qui inclut :

- Informations du restaurant (nom, logo, adresse)
- Articles commandés avec variantes et options
- Frais de livraison et de service
- Codes promo et réductions
- Statut et dates de création/mise à jour
- Distance de livraison

## Utilisation

```dart
// Navigation vers la page
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const UserRestaurantOrdersPage(),
  ),
);

// Utilisation du service
final orderService = RestaurantOrderService();
final ordersStream = orderService.getUserRestaurantOrders(userId);
```

## Design

La page suit le design system de l'application avec :
- Cards avec ombres subtiles
- Codes couleur pour les statuts
- Icônes cohérentes
- Responsive design avec ScreenUtil
- Animations de progression pour les commandes actives 