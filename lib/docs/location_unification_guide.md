# Guide d'utilisation du système de localisation unifié

## Vue d'ensemble

Ce système unifie la gestion de la localisation dans toutes les pages de votre application. Au lieu d'avoir une logique de localisation dupliquée dans chaque page, vous utilisez maintenant un `LocationProvider` centralisé qui gère :

- La localisation de l'utilisateur (depuis son profil ou GPS)
- Le géocodage d'adresses
- Le calcul de distances
- Le filtrage par rayon de recherche
- La synchronisation avec Firestore

## Composants principaux

### 1. LocationProvider (`lib/providers/location_provider.dart`)

Le provider central qui gère toute la logique de localisation.

**Propriétés principales :**
- `latitude`, `longitude` : Coordonnées actuelles
- `address` : Adresse formatée
- `radius` : Rayon de recherche en km
- `isLoading` : État de chargement
- `error` : Messages d'erreur
- `hasLocation` : Si une localisation est disponible
- `hasError` : Si une erreur est présente

**Méthodes principales :**
- `initializeLocation(UserModel)` : Initialise la localisation depuis le profil utilisateur
- `updateLocation()` : Met à jour la localisation
- `geocodeAddress(String)` : Géocode une adresse
- `isWithinRadius()` : Vérifie si un point est dans le rayon
- `calculateDistance()` : Calcule la distance entre deux points

### 2. UnifiedLocationFilter (`lib/widgets/unified_location_filter.dart`)

Widget de sélection de localisation unifié utilisé dans toutes les pages.

**Fonctionnalités :**
- Recherche de villes françaises
- Utilisation de la position GPS actuelle
- Sélection du rayon de recherche
- Interface utilisateur cohérente

## Comment utiliser le système

### 1. Ajouter le provider dans votre app

Dans votre `main.dart` ou là où vous configurez vos providers :

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => UserModel()),
    ChangeNotifierProvider(create: (_) => LocationProvider()),
    // autres providers...
  ],
  child: MyApp(),
)
```

### 2. Utiliser dans une page

```dart
class MyPage extends StatefulWidget {
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    final userModel = Provider.of<UserModel>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    await locationProvider.initializeLocation(userModel);
  }

  void _showLocationFilter() async {
    await UnifiedLocationFilter.show(
      context: context,
      onLocationChanged: () {
        setState(() {
          // La localisation a été mise à jour
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocationProvider>(
      builder: (context, locationProvider, child) {
        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                icon: Icon(
                  Icons.location_on,
                  color: locationProvider.hasLocation 
                      ? Colors.blue 
                      : null,
                ),
                onPressed: _showLocationFilter,
              ),
            ],
          ),
          body: _buildContent(locationProvider),
        );
      },
    );
  }

  Widget _buildContent(LocationProvider locationProvider) {
    if (locationProvider.isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (locationProvider.hasError) {
      return Center(
        child: Column(
          children: [
            Text('Erreur: ${locationProvider.error}'),
            ElevatedButton(
              onPressed: _initializeLocation,
              child: Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('your_collection').snapshots(),
      builder: (context, snapshot) {
        final items = snapshot.data?.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return YourModel.fromJson(data);
        }).toList() ?? [];

        // Filtrer par localisation
        final filteredItems = locationProvider.hasLocation
            ? items.where((item) {
                if (item.latitude == null || item.longitude == null) return false;
                return locationProvider.isWithinRadius(
                  item.latitude!,
                  item.longitude!,
                );
              }).toList()
            : items;

        return ListView.builder(
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            return YourItemWidget(item);
          },
        );
      },
    );
  }
}
```

### 3. Migration d'une page existante

Pour migrer une page existante vers le nouveau système :

1. **Remplacer les imports :**
```dart
// Avant
import 'package:happy/widgets/location_filter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// Après
import 'package:happy/providers/location_provider.dart';
import 'package:happy/widgets/unified_location_filter.dart';
```

2. **Supprimer les variables de localisation locales :**
```dart
// Supprimer ces variables
double? _selectedLat;
double? _selectedLng;
String _selectedAddress = '';
double _selectedRadius = 15.0;
```

3. **Remplacer la logique d'initialisation :**
```dart
// Avant
Future<void> _initializeLocation() async {
  // Logique complexe de localisation...
}

// Après
Future<void> _initializeLocation() async {
  final userModel = Provider.of<UserModel>(context, listen: false);
  final locationProvider = Provider.of<LocationProvider>(context, listen: false);
  
  await locationProvider.initializeLocation(userModel);
}
```

4. **Remplacer le filtre de localisation :**
```dart
// Avant
void _showLocationFilterBottomSheet() async {
  await LocationFilterBottomSheet.show(
    context: context,
    onLocationSelected: (lat, lng, radius, address) {
      setState(() {
        _selectedLat = lat;
        _selectedLng = lng;
        _selectedRadius = radius;
        _selectedAddress = address;
      });
    },
    currentLat: _selectedLat,
    currentLng: _selectedLng,
    currentRadius: _selectedRadius,
    currentAddress: _selectedAddress,
  );
}

// Après
void _showLocationFilterBottomSheet() async {
  await UnifiedLocationFilter.show(
    context: context,
    onLocationChanged: () {
      setState(() {
        // La localisation a été mise à jour via le provider
      });
    },
  );
}
```

5. **Utiliser le Consumer pour accéder à la localisation :**
```dart
@override
Widget build(BuildContext context) {
  return Consumer<LocationProvider>(
    builder: (context, locationProvider, child) {
      return Scaffold(
        // Utiliser locationProvider.latitude, locationProvider.longitude, etc.
      );
    },
  );
}
```

## Avantages du système unifié

1. **Cohérence** : Toutes les pages utilisent la même logique de localisation
2. **Maintenance** : Une seule source de vérité pour la localisation
3. **Performance** : Pas de duplication de code
4. **Synchronisation** : Changements de localisation répercutés partout
5. **Gestion d'erreurs** : Centralisée et cohérente
6. **Tests** : Plus facile à tester avec un provider centralisé

## Gestion des erreurs

Le système gère automatiquement :
- Services de localisation désactivés
- Permissions refusées
- Erreurs de géocodage
- Erreurs réseau

Les erreurs sont affichées de manière cohérente dans toutes les pages.

## Personnalisation

Vous pouvez personnaliser :
- Le rayon de recherche par défaut
- Les messages d'erreur
- L'interface du filtre de localisation
- La logique de géocodage

## Migration complète

Pour migrer complètement votre application :

1. Créer le `LocationProvider`
2. Ajouter le provider dans votre configuration
3. Migrer chaque page une par une
4. Tester chaque page après migration
5. Supprimer l'ancien `LocationFilterBottomSheet` une fois toutes les pages migrées

## Exemple de page migrée

Voir `lib/screens/post_type_page/companys_page_unified.dart` pour un exemple complet d'une page utilisant le nouveau système. 