// import 'package:flutter/material.dart';
// import 'package:google_places_flutter/google_places_flutter.dart';
// import 'package:google_places_flutter/model/prediction.dart';
// import 'package:happy/providers/home_provider.dart';
// import 'package:provider/provider.dart';

// class LocationPanel extends StatefulWidget {
//   const LocationPanel({super.key});

//   @override
//   _LocationPanelState createState() => _LocationPanelState();
// }

// class _LocationPanelState extends State<LocationPanel> {
//   late TextEditingController _addressController;
//   late HomeProvider _homeProvider;

//   @override
//   void initState() {
//     super.initState();
//     _homeProvider = Provider.of<HomeProvider>(context, listen: false);
//     _addressController =
//         TextEditingController(text: _homeProvider.currentAddress);
//   }



//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           const Text('Choisissez votre localisation',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//           const SizedBox(height: 16),
//           GooglePlaceAutoCompleteTextField(
//             textEditingController: _homeProvider.addressController,
//             googleAPIKey: "AIzaSyCS3N9FwFLGHDRSN7PbCSIhDrTjMPALfLc",
//             inputDecoration: const InputDecoration(
//               hintText: "Entrez une adresse",
//               prefixIcon: Icon(Icons.search),
//               border: OutlineInputBorder(),
//             ),
//             debounceTime: 800,
//             countries: const ["fr"],
//             isLatLngRequired: true,
//             getPlaceDetailWithLatLng: (Prediction prediction) {
//               _homeProvider.updateLocationFromPrediction(prediction);
//             },
//           ),
//           const SizedBox(height: 16),
//           const Text('Rayon de recherche',
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//           Consumer<HomeProvider>(
//             builder: (context, homeProvider, child) {
//               return Slider(
//                 value: homeProvider.selectedRadius,
//                 min: 1,
//                 max: 50,
//                 divisions: 49,
//                 label: "${homeProvider.selectedRadius.round()} km",
//                 onChanged: (value) {
//                   homeProvider.setSelectedRadius(value);
//                 },
//               );
//             },
//           ),
//           ElevatedButton(
//             child: const Text('Appliquer'),
//             onPressed: () {
//               Navigator.pop(context);
//               _homeProvider
//                   .refreshData(); // Ajoutez cette méthode à votre HomeProvider
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _addressController.dispose();
//     super.dispose();
//   }
// }
