import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:happy/classes/restaurant.dart';
import 'package:happy/screens/restaurants/restaurant_detail_page.dart';
import 'package:happy/widgets/cards/restaurant_card.dart';

class RestaurantTestPage extends StatelessWidget {
  const RestaurantTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Restaurants (Demo)'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        itemCount: _getDemoRestaurants().length,
        itemBuilder: (context, index) {
          final restaurant = _getDemoRestaurants()[index];
          return RestaurantCard(
            restaurant: restaurant,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RestaurantDetailPage(restaurant: restaurant),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Restaurant> _getDemoRestaurants() {
    return [
      Restaurant(
        id: 'demo_1',
        companyId: 'company_1',
        createdAt: DateTime.now(),
        name: 'Pizza Roma',
        description: 'Authentique pizzeria italienne avec des ingrédients frais',
        email: 'contact@pizzaroma.fr',
        phone: '01 23 45 67 89',
        website: 'https://pizzaroma.fr',
        address: RestaurantAddress(
          address: '123 Rue de la Paix',
          codePostal: '75001',
          ville: 'Paris',
          pays: 'France',
          latitude: 48.8566,
          longitude: 2.3522,
        ),
        logo: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ca4b?w=200&h=200&fit=crop',
        cover: 'https://images.unsplash.com/photo-1571997478779-2adcbbe9ab2f?w=800&h=400&fit=crop',
        gallery: [
          'https://images.unsplash.com/photo-1571997478779-2adcbbe9ab2f?w=400&h=300&fit=crop',
          'https://images.unsplash.com/photo-1565299624946-b28f40a0ca4b?w=400&h=300&fit=crop',
        ],
        openingHours: OpeningHours(
          schedule: {
            'monday': '11:30-14:30,18:30-22:30',
            'tuesday': '11:30-14:30,18:30-22:30',
            'wednesday': '11:30-14:30,18:30-22:30',
            'thursday': '11:30-14:30,18:30-22:30',
            'friday': '11:30-14:30,18:30-23:00',
            'saturday': '11:30-14:30,18:30-23:00',
            'sunday': '18:30-22:30',
          },
        ),
        socialMedia: SocialMedia(
          facebook: 'pizzaroma.paris',
          instagram: '@pizzaroma_paris',
        ),
        tags: ['Italien', 'Pizza', 'Livraison'],
        rating: 4.5,
        numberOfReviews: 127,
        category: 'Italien',
        subCategory: 'Pizza',
        deliveryRange: 5.0,
        averageOrderValue: 18.50,
        preparationTime: 25,
        distance: 1.2,
      ),
      Restaurant(
        id: 'demo_2',
        companyId: 'company_2',
        createdAt: DateTime.now(),
        name: 'Sushi Master',
        description: 'Sushi frais préparé par nos chefs japonais',
        email: 'contact@sushimaster.fr',
        phone: '01 34 56 78 90',
        website: 'https://sushimaster.fr',
        address: RestaurantAddress(
          address: '456 Avenue des Champs',
          codePostal: '75008',
          ville: 'Paris',
          pays: 'France',
          latitude: 48.8738,
          longitude: 2.2950,
        ),
        logo: 'https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=200&h=200&fit=crop',
        cover: 'https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=800&h=400&fit=crop',
        gallery: [
          'https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=400&h=300&fit=crop',
        ],
        openingHours: OpeningHours(
          schedule: {
            'monday': 'fermé',
            'tuesday': '12:00-14:30,19:00-22:30',
            'wednesday': '12:00-14:30,19:00-22:30',
            'thursday': '12:00-14:30,19:00-22:30',
            'friday': '12:00-14:30,19:00-23:00',
            'saturday': '12:00-14:30,19:00-23:00',
            'sunday': '19:00-22:30',
          },
        ),
        socialMedia: SocialMedia(
          instagram: '@sushimaster_paris',
        ),
        tags: ['Japonais', 'Sushi', 'Poisson frais'],
        rating: 4.8,
        numberOfReviews: 89,
        category: 'Japonais',
        subCategory: 'Sushi',
        deliveryRange: 3.0,
        averageOrderValue: 35.00,
        preparationTime: 20,
        distance: 0.8,
      ),
      Restaurant(
        id: 'demo_3',
        companyId: 'company_3',
        createdAt: DateTime.now(),
        name: 'Burger Street',
        description: 'Burgers artisanaux avec viande locale',
        email: 'hello@burgerstreet.fr',
        phone: '01 45 67 89 01',
        website: 'https://burgerstreet.fr',
        address: RestaurantAddress(
          address: '789 Boulevard Saint-Germain',
          codePostal: '75006',
          ville: 'Paris',
          pays: 'France',
          latitude: 48.8534,
          longitude: 2.3488,
        ),
        logo: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=200&h=200&fit=crop',
        cover: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800&h=400&fit=crop',
        gallery: [
          'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&h=300&fit=crop',
        ],
        openingHours: OpeningHours(
          schedule: {
            'monday': '11:30-15:00,18:00-22:00',
            'tuesday': '11:30-15:00,18:00-22:00',
            'wednesday': '11:30-15:00,18:00-22:00',
            'thursday': '11:30-15:00,18:00-22:00',
            'friday': '11:30-15:00,18:00-23:00',
            'saturday': '11:30-23:00',
            'sunday': '12:00-22:00',
          },
        ),
        socialMedia: SocialMedia(
          facebook: 'burgerstreet.paris',
          instagram: '@burgerstreet_paris',
        ),
        tags: ['Américain', 'Burger', 'Fait maison'],
        rating: 4.2,
        numberOfReviews: 203,
        category: 'Américain',
        subCategory: 'Burger',
        deliveryRange: 4.0,
        averageOrderValue: 22.00,
        preparationTime: 15,
        distance: 2.1,
      ),
    ];
  }
} 