import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:happy/providers/companys.dart';
import 'package:happy/widgets/buttons_categories.dart';
import 'package:happy/widgets/search_bar_home.dart';
import 'package:provider/provider.dart';

class Annuaire extends StatelessWidget {
  const Annuaire({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        title: const Text(
          'Annuaire',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        shadowColor: Colors.grey,
      ),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SearchBarHome(),
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(50)),
                        child: Icon(
                          Icons.settings_outlined,
                          color: Colors.grey[600],
                        ),
                      )
                    ],
                  ),
                ),
                const Row(
                  children: [
                    ButtonCategories(Icons.cookie, 'Entreprise'),
                    ButtonCategories(Icons.cookie, 'Associations'),
                  ],
                ),
                const Gap(10),
                Text(
                  '2 résultats',
                  style: TextStyle(
                      color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
                const Gap(10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
