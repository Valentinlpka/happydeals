// import 'package:flutter/material.dart';
// import 'package:happy/widgets/company_card.dart';
// import 'package:happy/providers/companys.dart';
// import 'package:provider/provider.dart';

// class Abcd extends StatelessWidget {
//   const Abcd({super.key});
//   static String routeName = 'abcd';

//   @override
//   Widget build(BuildContext context) {
//     final Size size = MediaQuery.of(context).size;
//     final Companys companys = context.watch<Companys>();

//     return Scaffold(
//       body: SafeArea(
//         child: SizedBox(
//           height: size.height,
//           child: Column(
//             children: [
//               Expanded(
//                 child: ListView.separated(
//                   separatorBuilder: (context, index) => const Divider(),
//                   itemCount: companys.items.length,
//                   itemBuilder: (BuildContext context, int index) {
//                     return Padding(
//                       padding: const EdgeInsets.all(10),
//                       child: CompanyCard(companys.items[index]),
//                     );
//                   },
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
