import 'package:cloud_firestore/cloud_firestore.dart';

class SampleDataUtils {
  static // Fonction pour créer une fausse association dans Firestore
      Future<String> createSampleAssociation() async {
    final associationData = {
      'name': 'Éco-Futur',
      'description':
          'Éco-Futur est une association engagée dans la protection de l\'environnement et l\'éducation au développement durable. Notre mission est de sensibiliser et d\'agir concrètement pour un avenir plus vert à travers des projets innovants et participatifs.',
      'logo':
          'https://firebasestorage.googleapis.com/v0/b/up-particulier.appspot.com/o/sample%2Flogo.png?alt=media',
      'coverImage':
          'https://firebasestorage.googleapis.com/v0/b/up-particulier.appspot.com/o/sample%2Fcover.jpg?alt=media',
      'category': 'Environnement',
      'location': 'Paris, France',
      'volunteersCount': 234,
      'projectsCount': 15,
      'donorsCount': 567,
      'causes': [
        'Protection de l\'environnement',
        'Éducation',
        'Biodiversité',
        'Développement durable',
        'Économie circulaire'
      ],
      'needs': [
        'Bénévoles pour nos actions de terrain',
        'Compétences en communication digitale',
        'Matériel de jardinage écologique',
        'Animateurs pour ateliers pédagogiques'
      ],
      'contact': {
        'email': 'contact@eco-futur.org',
        'phone': '01 23 45 67 89',
        'address': '123 rue de la Nature, 75001 Paris'
      },
      'team': [
        {
          'name': 'Marie Dubois',
          'role': 'Présidente',
          'photo':
              'https://firebasestorage.googleapis.com/v0/b/up-particulier.appspot.com/o/sample%2Fteam1.jpg?alt=media',
          'description': 'Engagée depuis 10 ans dans l\'écologie'
        },
        {
          'name': 'Thomas Martin',
          'role': 'Responsable Projets',
          'photo':
              'https://firebasestorage.googleapis.com/v0/b/up-particulier.appspot.com/o/sample%2Fteam2.jpg?alt=media',
          'description': 'Expert en gestion de projets environnementaux'
        },
        {
          'name': 'Sophie Laurent',
          'role': 'Coordinatrice Bénévoles',
          'photo':
              'https://firebasestorage.googleapis.com/v0/b/up-particulier.appspot.com/o/sample%2Fteam3.jpg?alt=media',
          'description': 'Spécialiste en engagement communautaire'
        }
      ],
      'projects': [
        {
          'title': 'Jardins Partagés Urbains',
          'description':
              'Création de jardins communautaires dans les quartiers prioritaires',
          'image':
              'https://firebasestorage.googleapis.com/v0/b/up-particulier.appspot.com/o/sample%2Fproject1.jpg?alt=media',
          'status': 'En cours',
          'goal': 25000,
          'progress': 75,
          'deadline': Timestamp.fromDate(DateTime(2024, 6, 30))
        },
        {
          'title': 'Éco-École 2024',
          'description':
              'Programme d\'éducation environnementale dans les écoles primaires',
          'image': 'https://placehold.co/401x300',
          'status': 'À venir',
          'goal': 15000,
          'progress': 30,
          'deadline': Timestamp.fromDate(DateTime(2024, 9, 1))
        }
      ],
      'events': [
        {
          'title': 'Grande Collecte de Printemps',
          'description': 'Nettoyage collectif des berges de la Seine',
          'date': 'Samedi 23 Mars 2024',
          'location': 'Berges de Seine, Paris',
          'image': 'https://placehold.co/402x300'
        },
        {
          'title': 'Atelier Compostage',
          'description': 'Apprenez à créer et gérer votre compost',
          'date': 'Dimanche 7 Avril 2024',
          'location': 'Jardin des Plantes, Paris',
          'image': 'https://placehold.co/403x300'
        }
      ],
      'news': [
        {
          'title': 'Succès de notre campagne de plantation',
          'content': '1000 arbres plantés ce mois-ci grâce à nos bénévoles !',
          'date': Timestamp.fromDate(DateTime(2024, 1, 15)),
          'image': 'https://placehold.co/404x300',
          'category': 'Réalisation'
        },
        {
          'title': 'Nouveau partenariat avec la Mairie',
          'content':
              'La ville s\'engage à nos côtés pour le développement des jardins urbains',
          'date': Timestamp.fromDate(DateTime(2024, 1, 10)),
          'image': 'https://placehold.co/405x300',
          'category': 'Partenariat'
        }
      ],
      'impact': {
        'treesPlanted': 5000,
        'wasteCollected': '12 tonnes',
        'workshopsHeld': 120,
        'peopleReached': 25000
      }
    };

    final docRef = await FirebaseFirestore.instance
        .collection('associations')
        .add(associationData);

    return docRef.id;
  }
}
