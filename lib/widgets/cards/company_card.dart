import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/providers/company_provider.dart';
import 'package:provider/provider.dart';

import '../../classes/company.dart';
import '../../screens/details_page/details_company_page.dart';

class CompanyCard extends StatelessWidget {
  final Company company;

  const CompanyCard(this.company, {super.key});

  String _getNextOpenTime() {
    final now = DateTime.now();
    final currentDay = now.weekday;
    final currentTime = now.hour * 60 + now.minute;

    // Vérifier d'abord les heures du jour actuel
    final dayName = _getDayName(currentDay);
    final dayHours = company.openingHours.hours[dayName] ?? "fermé";

    if (dayHours != "fermé") {
      // Gérer les horaires multiples
      final timeSlots = dayHours.split(' / ');
      for (var slot in timeSlots) {
        try {
          final [openTime, closeTime] =
              slot.split('-').map((e) => e.trim()).toList();
          final [openHour, openMinute] =
              openTime.split(':').map(int.parse).toList();
          final [closeHour, closeMinute] =
              closeTime.split(':').map(int.parse).toList();

          final openTimeMinutes = openHour * 60 + openMinute;
          final closeTimeMinutes = closeHour * 60 + closeMinute;

          // Si on est avant l'heure d'ouverture aujourd'hui
          if (currentTime < openTimeMinutes) {
            return '$openTime - $closeTime';
          }
          // Si on est après l'heure de fermeture aujourd'hui
          if (currentTime > closeTimeMinutes) {
            // Chercher le prochain jour d'ouverture
            for (int i = 1; i < 7; i++) {
              final nextDay = (currentDay + i) % 7;
              final nextDayName = _getDayName(nextDay);
              final nextDayHours =
                  company.openingHours.hours[nextDayName] ?? "fermé";

              if (nextDayHours != "fermé") {
                final nextTimeSlots = nextDayHours.split(' / ');
                final [nextOpenTime, nextCloseTime] = nextTimeSlots.first
                    .split('-')
                    .map((e) => e.trim())
                    .toList();
                return '$nextOpenTime - $nextCloseTime';
              }
            }
          }
        } catch (e) {
          debugPrint('Erreur lors du parsing des horaires: $e');
          continue;
        }
      }
    } else {
      // Si le jour est marqué comme "Fermé", chercher le prochain jour d'ouverture
      for (int i = 1; i < 7; i++) {
        final nextDay = (currentDay + i) % 7;
        final nextDayName = _getDayName(nextDay);
        final nextDayHours = company.openingHours.hours[nextDayName] ?? "fermé";

        if (nextDayHours != "fermé") {
          final nextTimeSlots = nextDayHours.split(' / ');
          final [nextOpenTime, nextCloseTime] =
              nextTimeSlots.first.split('-').map((e) => e.trim()).toList();
          return '$nextOpenTime - $nextCloseTime';
        }
      }
    }

    return '';
  }

  String _getDayName(int day) {
    switch (day) {
      case 1:
        return 'monday';
      case 2:
        return 'tuesday';
      case 3:
        return 'wednesday';
      case 4:
        return 'thursday';
      case 5:
        return 'friday';
      case 6:
        return 'saturday';
      case 7:
        return 'sunday';
      default:
        return '';
    }
  }

  bool _isOpen() {
    return company.openingHours.isOpenNow();
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = _isOpen();
    final nextOpenTime = _getNextOpenTime();
    final currentDay = DateTime.now().weekday;
    final dayName = _getDayName(currentDay);
    final dayHours = company.openingHours.hours[dayName] ?? "fermé";
    final isClosedToday = dayHours == "fermé";

    return ChangeNotifierProvider(
      create: (context) =>
          CompanyLikeService(FirebaseAuth.instance.currentUser!.uid),
      child: Builder(builder: (context) {
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailsEntreprise(
                  entrepriseId: company.id,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(20),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          company.logo,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[100],
                              child: const Icon(Icons.business, size: 24),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            company.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            company.categorie,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOpen ? Colors.green[50] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOpen ? Icons.check_circle : Icons.access_time,
                            size: 14,
                            color:
                                isOpen ? Colors.green[700] : Colors.grey[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isClosedToday
                                ? 'Fermé'
                                : isOpen
                                    ? 'Ouvert'
                                    : nextOpenTime.isNotEmpty
                                        ? nextOpenTime
                                        : 'Fermé',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color:
                                  isOpen ? Colors.green[700] : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 16, color: Colors.grey[700]),
                          const SizedBox(width: 4),
                          Text(
                            company.adress.ville,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (company.numberOfReviews != null &&
                        company.numberOfReviews! > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.amber[200]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded,
                                size: 16, color: Colors.amber[700]),
                            const SizedBox(width: 4),
                            Text(
                              company.averageRating?.toStringAsFixed(1) ??
                                  '0.0',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber[700],
                              ),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '(${company.numberOfReviews})',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.amber[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
