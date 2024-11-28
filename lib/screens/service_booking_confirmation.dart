// lib/pages/services/booking_confirmation_page.dart
import 'package:flutter/material.dart';
import 'package:happy/classes/service.dart';
import 'package:happy/classes/time_slot.dart';
import 'package:intl/intl.dart';

class ServiceBookingConfirmationPage extends StatelessWidget {
  final ServiceModel service;
  final TimeSlotModel timeSlot;

  const ServiceBookingConfirmationPage({
    super.key,
    required this.service,
    required this.timeSlot,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 100,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              Text(
                'Réservation confirmée !',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Votre réservation pour ${service.name} a été confirmée.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _buildDetailsCard(context),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // Naviguer vers la liste des réservations
                  Navigator.pushReplacementNamed(context, '/bookings');
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text('Voir mes réservations'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // Retourner à l'accueil
                  Navigator.pushReplacementNamed(context, '/home');
                },
                child: const Text('Retour à l\'accueil'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDetailRow(
              context,
              'Date',
              DateFormat('dd/MM/yyyy').format(timeSlot.date),
              Icons.calendar_today,
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              context,
              'Heure',
              DateFormat('HH:mm').format(timeSlot.startTime),
              Icons.access_time,
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              context,
              'Durée',
              '${service.duration} minutes',
              Icons.timer,
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              context,
              'Prix',
              '${service.price.toStringAsFixed(2)} €',
              Icons.euro,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          '$label :',
          style: const TextStyle(
            color: Colors.grey,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
