// lib/pages/bookings/client_bookings_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/booking.dart';
import 'package:happy/classes/service.dart';
import 'package:happy/services/service_service.dart';
import 'package:intl/intl.dart';

import '../../services/booking_service.dart';

class ClientBookingsPage extends StatelessWidget {
  const ClientBookingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes réservations'),
      ),
      body: StreamBuilder<List<BookingModel>>(
        stream: BookingService().getUserBookings(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print(snapshot.error);
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookings = snapshot.data!;

          if (bookings.isEmpty) {
            return const Center(
              child: Text('Vous n\'avez pas encore de réservation'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
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

  const _BookingCard({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ServiceModel>(
      future: ServiceClientService().getServiceById(booking.serviceId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print(snapshot.error);
        }
        if (!snapshot.hasData) {
          return const Card(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final service = snapshot.data!;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête avec le statut
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _StatusChip(status: booking.status),
                  ],
                ),
                const SizedBox(height: 16),

                // Informations de la réservation
                _InfoRow(
                  icon: Icons.event,
                  label: 'Date',
                  value: DateFormat('dd/MM/yyyy').format(booking.bookingDate),
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.access_time,
                  label: 'Heure',
                  value: DateFormat('HH:mm').format(booking.bookingDate),
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.timelapse,
                  label: 'Durée',
                  value: '${service.duration} min',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.euro,
                  label: 'Prix',
                  value: '${booking.price.toStringAsFixed(2)} €',
                ),

                // Actions
                const SizedBox(height: 16),
                if (booking.status == 'confirmed') ...[
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _showCancellationDialog(context),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showRescheduleDialog(context),
                        icon: const Icon(Icons.schedule),
                        label: const Text('Reprogrammer'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCancellationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la réservation'),
        content: const Text(
          'Êtes-vous sûr de vouloir annuler cette réservation ? '
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await BookingService().cancelBooking(booking.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Réservation annulée')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
  }

  void _showRescheduleDialog(BuildContext context) {
    // Implémenter la logique de reprogrammation
    // Peut-être naviguer vers une nouvelle page avec un sélecteur de date/heure
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    String label;

    switch (status) {
      case 'confirmed':
        backgroundColor = Colors.green;
        label = 'Confirmé';
        break;
      case 'cancelled':
        backgroundColor = Colors.red;
        label = 'Annulé';
        break;
      case 'completed':
        backgroundColor = Colors.blue;
        label = 'Terminé';
        break;
      default:
        backgroundColor = Colors.grey;
        label = 'En attente';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: backgroundColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: backgroundColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          '$label :',
          style: TextStyle(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
