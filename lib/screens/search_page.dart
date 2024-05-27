import 'package:flutter/material.dart';
import 'package:happy/widgets/concours_card.dart';
import 'package:happy/widgets/deals_express_card.dart';
import 'package:happy/widgets/emploi_card.dart';
import 'package:happy/widgets/evenement_card.dart';

class Search extends StatelessWidget {
  const Search({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Center(
              child: Text('Rechercher'),
            ),
            EvenementCard(),
            EmploiCard(),
            ConcoursCard(),
            DealsExpressCard(),
          ],
        ),
      ),
    );
  }
}
