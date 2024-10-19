// import 'package:flutter/material.dart';
// import 'package:happy/classes/ad.dart';
// import 'package:happy/screens/marketplace/custom_widget.dart';
// import 'package:happy/screens/marketplace/photo_section.dart';

// class PropertyForm extends StatefulWidget {
//   final GlobalKey<PropertyFormState> formKey = GlobalKey<PropertyFormState>();

//   PropertyForm({super.key, Ad? existingAd});

//   @override
//   PropertyFormState createState() => PropertyFormState();
//   Map<String, dynamic> getFormData() {
//     final state = formKey.currentState;
//     if (state != null) {
//       return state.getFormData();
//     }
//     return {};
//   }
// }

// class PropertyFormState extends State<PropertyForm> {
//   final GlobalKey<PhotoSectionState> _photoSectionKey =
//       GlobalKey<PhotoSectionState>();

//   String? _selectedSaleType;
//   String? _selectedPropertyType;
//   String? _selectedExterior;
//   String? _selectedParkingType;
//   String? _selectedHeatingType;

//   final TextEditingController _roomsController = TextEditingController();
//   final TextEditingController _livingAreaController = TextEditingController();
//   final TextEditingController _priceController = TextEditingController();
//   final TextEditingController _addressController = TextEditingController();
//   final TextEditingController _exteriorAreaController = TextEditingController();
//   final TextEditingController _descriptionController = TextEditingController();
//   final TextEditingController _energyConsumptionController =
//       TextEditingController();

//   @override
//   void dispose() {
//     _roomsController.dispose();
//     _livingAreaController.dispose();
//     _priceController.dispose();
//     _addressController.dispose();
//     _exteriorAreaController.dispose();
//     _descriptionController.dispose();
//     _energyConsumptionController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Form(
//       key: widget.formKey,
//       child: Column(
//         children: [
//           PhotoSection(key: _photoSectionKey),
//           const SizedBox(height: 16),
//           Row(
//             children: [
//               Expanded(
//                 child: buildDropdown(
//                   'À vendre ou à louer',
//                   _selectedSaleType,
//                   ['À vendre', 'À louer'],
//                   (value) => setState(() => _selectedSaleType = value),
//                 ),
//               ),
//               const SizedBox(width: 16),
//               Expanded(
//                 child: buildDropdown(
//                   'Type de propriété',
//                   _selectedPropertyType,
//                   [
//                     'Maison',
//                     'Appartement',
//                     'Studio',
//                     'Terrain',
//                     'Local commercial',
//                     'Autre'
//                   ],
//                   (value) => setState(() => _selectedPropertyType = value),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           Row(
//             children: [
//               Expanded(
//                   child: buildTextField('Nombre de pièces', _roomsController)),
//               const SizedBox(width: 16),
//               Expanded(
//                   child: buildTextField(
//                       'Superficie habitable (m²)', _livingAreaController)),
//             ],
//           ),
//           const SizedBox(height: 16),
//           Row(
//             children: [
//               Expanded(child: buildTextField('Prix', _priceController)),
//               const SizedBox(width: 16),
//               Expanded(
//                   child: buildTextField('Adresse du bien', _addressController)),
//             ],
//           ),
//           const SizedBox(height: 16),
//           Row(
//             children: [
//               Expanded(
//                 child: buildDropdown(
//                   'Extérieur',
//                   _selectedExterior,
//                   ['Balcon', 'Terrasse', 'Jardin', 'Pas d\'extérieur'],
//                   (value) => setState(() => _selectedExterior = value),
//                 ),
//               ),
//               const SizedBox(width: 16),
//               Expanded(
//                   child: buildTextField(
//                       'Superficie extérieure (m²)', _exteriorAreaController)),
//             ],
//           ),
//           const SizedBox(height: 16),
//           buildTextField('Description', _descriptionController, maxLines: 3),
//           const SizedBox(height: 16),
//           buildTextField(
//               'Consommation énergétique', _energyConsumptionController),
//           const SizedBox(height: 16),
//           Row(
//             children: [
//               Expanded(
//                 child: buildDropdown(
//                   'Type de parking',
//                   _selectedParkingType,
//                   ['Garage', 'Place de parking', 'Pas de parking'],
//                   (value) => setState(() => _selectedParkingType = value),
//                 ),
//               ),
//               const SizedBox(width: 16),
//               Expanded(
//                 child: buildDropdown(
//                   'Type de chauffage',
//                   _selectedHeatingType,
//                   [
//                     'Électrique',
//                     'Gaz',
//                     'Fioul',
//                     'Bois',
//                     'Pompe à chaleur',
//                     'Autre'
//                   ],
//                   (value) => setState(() => _selectedHeatingType = value),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Map<String, dynamic> getFormData() {
//     return {
//       'saleType': _selectedSaleType ?? '',
//       'propertyType': _selectedPropertyType ?? '',
//       'rooms': _roomsController.text,
//       'livingArea': _livingAreaController.text,
//       'price': _priceController.text,
//       'address': _addressController.text,
//       'exterior': _selectedExterior ?? '',
//       'exteriorArea': _exteriorAreaController.text,
//       'description': _descriptionController.text,
//       'energyConsumption': _energyConsumptionController.text,
//       'parkingType': _selectedParkingType ?? '',
//       'heatingType': _selectedHeatingType ?? '',
//       'photos': _photoSectionKey.currentState?.getPhotos() ?? [],
//     };
//   }
// }
