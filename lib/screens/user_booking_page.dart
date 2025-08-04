// lib/pages/bookings/client_bookings_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/booking.dart';
import 'package:happy/classes/service.dart';
import 'package:happy/screens/booking_detail_page.dart';
import 'package:happy/services/service_service.dart';
import 'package:happy/widgets/app_bar/custom_app_bar.dart';
import 'package:intl/intl.dart';

import '../../services/booking_service.dart';

class ClientBookingsPage extends StatelessWidget {
  const ClientBookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    print('🔍 ClientBookingsPage - userId: $userId');

    return Scaffold(
      appBar: const CustomAppBar(
        align: Alignment.center,
        title: 'Mes réservations',
      ),
      body: StreamBuilder<List<BookingModel>>(
        stream: BookingService().getUserBookings(userId),
        builder: (context, snapshot) {
          print('🔍 StreamBuilder - connectionState: ${snapshot.connectionState}');
          print('🔍 StreamBuilder - hasError: ${snapshot.hasError}');
          print('🔍 StreamBuilder - hasData: ${snapshot.hasData}');
          
          if (snapshot.hasError) {
            print('❌ Erreur lors de la récupération des réservations: ${snapshot.error}');
            print('❌ Stack trace: ${snapshot.stackTrace}');
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            print('⏳ En attente de la récupération des réservations');
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            print('⚠️ Pas de données dans le snapshot');
            return const Center(child: Text('Aucune donnée disponible'));
          }

          final bookings = snapshot.data!;
          print('✅ Réservations récupérées: ${bookings.length}');
          
          for (int i = 0; i < bookings.length; i++) {
            final booking = bookings[i];
            print('📋 Réservation $i: id=${booking.id}, serviceId=${booking.serviceId}, status=${booking.status}');
          }

          if (bookings.isEmpty) {
            print('📭 Aucune réservation trouvée');
            return const Center(
              child: Text('Vous n\'avez pas encore de réservation'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              print('🏗️ Construction de la carte pour la réservation $index');
              return _BookingCard(booking: bookings[index]);
            },
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingModel booking;

  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    print('🎯 _BookingCard - Construction pour booking.id: ${booking.id}');
    print('🎯 _BookingCard - serviceId: ${booking.serviceId}');
    
    return FutureBuilder<ServiceModel>(
      future: ServiceClientService().getServiceByIds(booking.serviceId),
      builder: (context, snapshot) {
        print('🔍 FutureBuilder Service - connectionState: ${snapshot.connectionState}');
        print('🔍 FutureBuilder Service - hasError: ${snapshot.hasError}');
        print('🔍 FutureBuilder Service - hasData: ${snapshot.hasData}');
        
        if (snapshot.hasError) {
          print('❌ Erreur lors de la récupération du service: ${snapshot.error}');
          print('❌ Stack trace: ${snapshot.stackTrace}');
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red, width: 1),
            ),
            child: Column(
              children: [
                Text('Erreur: ${snapshot.error}'),
                const SizedBox(height: 8),
                Text('Service ID: ${booking.serviceId}'),
                Text('Booking ID: ${booking.id}'),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          print('⏳ En attente de la récupération du service ${booking.serviceId}');
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          print('⚠️ Pas de données de service pour ${booking.serviceId}');
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange, width: 1),
            ),
            child: Column(
              children: [
                const Text('Service non trouvé'),
                Text('Service ID: ${booking.serviceId}'),
                Text('Booking ID: ${booking.id}'),
              ],
            ),
          );
        }

        final service = snapshot.data!;
        print('✅ Service récupéré: ${service.name}');

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.withAlpha(26 * 2),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                print('👆 Tap sur la réservation ${booking.id}');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        BookingDetailPage(bookingId: booking.id),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                service.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('EEEE d MMMM yyyy à HH:mm', 'fr_FR')
                                    .format(booking.bookingDate),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildStatusChip(booking.status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          _buildInfoItem(
                            icon: Icons.timelapse,
                            label: 'Durée',
                            value: '${service.duration} min',
                          ),
                          Container(
                            height: 24,
                            width: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            color: Colors.grey[300],
                          ),
                          _buildInfoItem(
                            icon: Icons.euro,
                            label: 'Prix',
                            value: '${booking.price.toStringAsFixed(2)} €',
                          ),
                          const Spacer(),
                          Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.grey[700],
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    String text;
    IconData icon;

    switch (status) {
      case 'confirmed':
        backgroundColor = Colors.green[50]!;
        textColor = Colors.green[700]!;
        text = 'Confirmé';
        icon = Icons.check_circle_outline;
        break;
      case 'cancelled':
        backgroundColor = Colors.red[50]!;
        textColor = Colors.red[700]!;
        text = 'Annulé';
        icon = Icons.cancel_outlined;
        break;
      case 'completed':
        backgroundColor = Colors.blue[50]!;
        textColor = Colors.blue[700]!;
        text = 'Terminé';
        icon = Icons.task_alt;
        break;
      default:
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[700]!;
        text = 'En attente';
        icon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
