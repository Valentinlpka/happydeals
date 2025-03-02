// lib/pages/services/service_detail_page.dart
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/service.dart';
import 'package:happy/screens/service_payment.dart';
import 'package:happy/services/service_service.dart';
import 'package:intl/intl.dart';

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
  final ValueNotifier<DateTime?> _selectedTimeNotifier =
      ValueNotifier<DateTime?>(null);
  String? _businessId;

  @override
  void initState() {
    super.initState();
    _loadBusinessId();
  }

  Future<void> _loadBusinessId() async {
    final service =
        await _serviceService.getServiceById(widget.serviceId).first;
    setState(() {
      _businessId = service.professionalId;
    });
  }

  @override
  void dispose() {
    _selectedTimeNotifier.dispose();
    super.dispose();
  }

  DateTime? get _selectedTime => _selectedTimeNotifier.value;
  set _selectedTime(DateTime? value) {
    _selectedTimeNotifier.value = value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<ServiceModel>(
        stream: _serviceService.getServiceById(widget.serviceId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
                    if (service.hasActivePromotion)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red[100]!),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Offre Spéciale !',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Économisez ${service.discount!['value']}${service.discount!['type'] == 'percentage' ? '%' : '€'} sur ce service',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Valable jusqu\'au ${DateFormat('dd/MM/yyyy').format((service.discount!['endDate'] as Timestamp).toDate())}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    _buildServiceInfo(service),
                    _buildAvailabilitySection(service),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomBar(),
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

  Widget _buildBottomBar() {
    return StreamBuilder<ServiceModel>(
      stream: _serviceService.getServiceById(widget.serviceId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final service = snapshot.data!;

        return ValueListenableBuilder<DateTime?>(
          valueListenable: _selectedTimeNotifier,
          builder: (context, selectedTime, _) {
            return Container(
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
                        const Text('Total',
                            style: TextStyle(color: Colors.grey)),
                        if (service.hasActivePromotion) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${service.finalPrice.toStringAsFixed(2)} €',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '${service.price.toStringAsFixed(2)} €',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else
                          Text(
                            '${service.price.toStringAsFixed(2)} €',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: selectedTime == null
                          ? null
                          : () => _proceedToPayment(service),
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
            );
          },
        );
      },
    );
  }

  void _proceedToPayment(ServiceModel service) {
    // Naviguer vers la page de paiement avec la date/heure sélectionnée
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServicePaymentPage(
          service: service,
          bookingDateTime: _selectedTime!,
        ),
      ),
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
              if (service.hasActivePromotion) ...[
                Text(
                  '${service.price.toStringAsFixed(2)} €',
                  style: const TextStyle(
                    color: Colors.grey,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${service.finalPrice.toStringAsFixed(2)} €',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '-${service.discount!['value']}${service.discount!['type'] == 'percentage' ? '%' : '€'}',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ] else
                Text(
                  '${service.price.toStringAsFixed(2)} €',
                  style: const TextStyle(color: Colors.grey),
                ),
            ],
          ),
          if (service.hasActivePromotion) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Promotion valable jusqu\'au ${DateFormat('dd/MM/yyyy').format((service.discount!['endDate'] as Timestamp).toDate())}',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                  _selectedTime = null;
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

  Widget _buildAvailabilitySection(ServiceModel service) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choisir une date',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _buildDatePicker(),
          const SizedBox(height: 24),
          Text(
            'Horaires disponibles',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _buildTimeSlots(service),
        ],
      ),
    );
  }

  Widget _buildTimeSlots(ServiceModel service) {
    if (_businessId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<Map<DateTime, int>>(
      future: _bookingService.getAvailableTimeSlots(
        _businessId!,
        service.id,
        _selectedDate,
        service.duration,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 8),
                Text('Chargement des créneaux...'),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Aucun créneau disponible pour cette date',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        final slots = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Créneaux disponibles (${slots.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: slots.entries.map((entry) {
                final time = entry.key;
                final availableCount = entry.value;
                return ValueListenableBuilder<DateTime?>(
                  valueListenable: _selectedTimeNotifier,
                  builder: (context, selectedTime, _) {
                    final isSelected =
                        selectedTime?.isAtSameMomentAs(time) ?? false;
                    return FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(DateFormat('HH:mm').format(time)),
                          if (availableCount > 1) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$availableCount places',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[900],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        _selectedTime = selected ? time : null;
                      },
                      backgroundColor: Colors.white,
                      selectedColor: Colors.blue[100],
                      checkmarkColor: Colors.blue[700],
                      showCheckmark: false,
                    );
                  },
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}
