// lib/pages/services/service_detail_page.dart
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/service.dart';
import 'package:happy/classes/time_slot.dart';
import 'package:happy/screens/service_payment.dart';
import 'package:happy/services/service_service.dart';

import '../../services/booking_service.dart';

class ServiceDetailPage extends StatefulWidget {
  final String serviceId;

  const ServiceDetailPage({super.key, required this.serviceId});

  @override
  _ServiceDetailPageState createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends State<ServiceDetailPage> {
  final ServiceClientService _serviceService = ServiceClientService();
  final BookingService _bookingService = BookingService();
  DateTime _selectedDate = DateTime.now();
  TimeSlotModel? _selectedTimeSlot;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<ServiceModel>(
        future: _serviceService.getServiceById(widget.serviceId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print(snapshot.error);
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          final service = snapshot.data!;

          return CustomScrollView(
            slivers: [
              _buildAppBar(service),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImageCarousel(service),
                    _buildServiceInfo(service),
                    _buildBookingSection(service),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  FutureBuilder<ServiceModel>(
                    future: _serviceService.getServiceById(widget.serviceId),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      return Text(
                        '${snapshot.data!.price.toStringAsFixed(2)} €',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ElevatedButton(
                onPressed: _selectedTimeSlot == null
                    ? null
                    : () => _showBookingConfirmation(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text('Réserver'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(ServiceModel service) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      title: Text(service.name),
      actions: [
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () {
            // Implémenter le partage
          },
        ),
      ],
    );
  }

  Widget _buildImageCarousel(ServiceModel service) {
    if (service.images.isEmpty) {
      return Container(
        height: 250,
        color: Colors.grey[300],
        child: const Icon(Icons.image_not_supported, size: 50),
      );
    }

    return CarouselSlider(
      options: CarouselOptions(
        height: 250,
        viewportFraction: 1.0,
        enableInfiniteScroll: service.images.length > 1,
        autoPlay: service.images.length > 1,
      ),
      items: service.images.map((imageUrl) {
        return Builder(
          builder: (BuildContext context) {
            return Image.network(
              imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildServiceInfo(ServiceModel service) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            service.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.timer, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                '${service.duration} minutes',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.euro, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                '${service.price.toStringAsFixed(2)} €',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Description',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(service.description),
        ],
      ),
    );
  }

  Widget _buildBookingSection(ServiceModel service) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choisir un créneau',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _buildDatePicker(),
          const SizedBox(height: 16),
          _buildTimeSlots(service),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(30, (index) {
          final date = DateTime.now().add(Duration(days: index));
          final isSelected = _selectedDate.year == date.year &&
              _selectedDate.month == date.month &&
              _selectedDate.day == date.day;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedDate = date;
                  _selectedTimeSlot = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.white,
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300]!,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      [
                        'Dim',
                        'Lun',
                        'Mar',
                        'Mer',
                        'Jeu',
                        'Ven',
                        'Sam'
                      ][date.weekday % 7],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date.day.toString(),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTimeSlots(ServiceModel service) {
    return StreamBuilder<List<TimeSlotModel>>(
      stream: _bookingService.getAvailableTimeSlots(service.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print(snapshot.error);

          return Text('Erreur: ${snapshot.error}');
        }

        final slots = snapshot.data ?? [];
        final filteredSlots = slots.where((slot) {
          return slot.date.year == _selectedDate.year &&
              slot.date.month == _selectedDate.month &&
              slot.date.day == _selectedDate.day;
        }).toList();

        filteredSlots.sort((a, b) => a.startTime.compareTo(b.startTime));

        if (filteredSlots.isEmpty) {
          return const Center(
            child: Text('Aucun créneau disponible pour cette date'),
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filteredSlots.map((slot) {
            final isSelected = _selectedTimeSlot?.id == slot.id;
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedTimeSlot = slot;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.white,
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300]!,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${slot.startTime.hour}:${slot.startTime.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showBookingConfirmation(BuildContext context) async {
    // Récupérer le service actuel
    final service = await _serviceService.getServiceById(widget.serviceId);

    if (!mounted)
      return; // Vérification de sécurité si le widget est toujours monté

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la réservation'),
          content: const Text('Voulez-vous confirmer cette réservation ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Fermer la boîte de dialogue
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ServicePaymentPage(
                      service: service,
                      timeSlot: _selectedTimeSlot!,
                    ),
                  ),
                );
              },
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );
  }
}
