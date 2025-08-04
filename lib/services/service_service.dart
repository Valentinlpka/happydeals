import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/service.dart';

class ServiceClientService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Récupérer tous les services actifs
  Stream<List<ServiceModel>> getActiveServices() {
    return _firestore
        .collection('posts')
        .where('type', isEqualTo: 'service')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ServiceModel.fromMap(doc.data()))
            .toList());
  }

  // Récupérer les services d'un professionnel
  Stream<List<ServiceModel>> getServicesByProfessional(String professionalId) {
    return _firestore
        .collection('posts')
        .where('type', isEqualTo: 'service')
        .where('companyId', isEqualTo: professionalId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ServiceModel.fromMap(doc.data()))
            .toList());
  }

  Future<ServiceModel> getServiceByIds(String serviceId) async {
    print('🔍 ServiceClientService.getServiceByIds - serviceId: $serviceId');
    
    try {
      // D'abord essayer dans la collection 'services'
      print('📋 Recherche dans la collection "services"...');
      final serviceDoc = await _firestore.collection('services').doc(serviceId).get();
      
      if (serviceDoc.exists) {
        print('✅ Service trouvé dans la collection "services"');
        print('📋 Service data: ${serviceDoc.data()}');
        return ServiceModel.fromMap(serviceDoc.data()!);
      }
      
      // Si pas trouvé, essayer dans la collection 'posts'
      print('📋 Service non trouvé dans "services", recherche dans "posts"...');
      final postDoc = await _firestore.collection('posts').doc(serviceId).get();
      
      if (postDoc.exists) {
        final data = postDoc.data()!;
        print('✅ Service trouvé dans la collection "posts"');
        print('📋 Post data: $data');
        
        if (data['type'] == 'service') {
          return ServiceModel.fromMap(data);
        } else {
          print('❌ Le document trouvé n\'est pas un service: type = ${data['type']}');
          throw Exception('Le document trouvé n\'est pas un service');
        }
      }
      
      print('❌ Service non trouvé dans les deux collections');
      throw Exception('Service non trouvé');
    } catch (e, stackTrace) {
      print('❌ Erreur dans getServiceByIds: $e');
      print('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Récupérer un service spécifique
  Stream<ServiceModel> getServiceById(String serviceId) {
    return _firestore
        .collection('posts')
        .doc(serviceId)
        .snapshots()
        .map((doc) => ServiceModel.fromMap(doc.data()!));
  }

  // Rechercher des services
  Stream<List<ServiceModel>> searchServices(String query) {
    return _firestore
        .collection('posts')
        .where('type', isEqualTo: 'service')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ServiceModel.fromMap(doc.data()))
            .where((service) =>
                service.name.toLowerCase().contains(query.toLowerCase()) ||
                service.description.toLowerCase().contains(query.toLowerCase()))
            .toList());
  }
}
