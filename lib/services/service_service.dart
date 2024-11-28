import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:happy/classes/service.dart';

class ServiceClientService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Récupérer tous les services actifs
  Stream<List<ServiceModel>> getActiveServices() {
    return _firestore
        .collection('services')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ServiceModel.fromMap(doc.data()))
            .toList());
  }

  // Récupérer les services d'un professionnel
  Stream<List<ServiceModel>> getServicesByProfessional(String professionalId) {
    return _firestore
        .collection('services')
        .where('professionalId', isEqualTo: professionalId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ServiceModel.fromMap(doc.data()))
            .toList());
  }

  // Récupérer un service spécifique
  Future<ServiceModel> getServiceById(String serviceId) async {
    final doc = await _firestore.collection('services').doc(serviceId).get();
    if (!doc.exists) {
      throw Exception('Service non trouvé');
    }
    return ServiceModel.fromMap(doc.data()!);
  }

  // Rechercher des services
  Stream<List<ServiceModel>> searchServices(String query) {
    return _firestore
        .collection('services')
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
