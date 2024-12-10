// lib/pages/services/service_detail_page.dart
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:happy/classes/availibility_rule.dart';
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

  // Ajouter ces variables pour le cache
  List<DateTime>? _cachedTimeSlots;
  DateTime? _cachedDate;
  String? _cachedServiceId;

  @override
  void dispose() {
    _selectedTimeNotifier.dispose();
    super.dispose();
  }

  // Modifier le getter et setter pour _selectedTime
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
    return StreamBuilder<List<AvailabilityRuleModel>>(
      stream: _bookingService.getServiceAvailabilityRules(service.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data!.isEmpty) {
          return const Text('Aucune disponibilité pour ce service');
        }

        final rule = snapshot.data!.first;

        // Vérifier si le jour sélectionné est travaillé
        if (!rule.workDays.contains(_selectedDate.weekday)) {
          _cachedTimeSlots = null;
          return const Text('Ce jour n\'est pas travaillé');
        }

        // Vérifier si on doit recharger les créneaux
        bool shouldReloadSlots = _cachedTimeSlots == null ||
            _cachedDate != _selectedDate ||
            _cachedServiceId != service.id;

        if (shouldReloadSlots) {
          return FutureBuilder<List<DateTime>>(
            future: _bookingService.getAvailableTimeSlots(
              service.id,
              _selectedDate,
              service.duration,
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
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

              // Mettre en cache les créneaux
              _cachedTimeSlots = snapshot.data;
              _cachedDate = _selectedDate;
              _cachedServiceId = service.id;

              return _buildTimeSlotsGrid(_cachedTimeSlots!);
            },
          );
        }

        // Utiliser les créneaux en cache
        return _buildTimeSlotsGrid(_cachedTimeSlots!);
      },
    );
  }

  Widget _buildTimeSlotsGrid(List<DateTime> timeSlots) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: timeSlots.map((time) {
        return ValueListenableBuilder<DateTime?>(
          valueListenable: _selectedTimeNotifier,
          builder: (context, selectedTime, _) {
            final isSelected = selectedTime?.isAtSameMomentAs(time) ?? false;
            return FilterChip(
              label: Text(DateFormat('HH:mm').format(time)),
              selected: isSelected,
              onSelected: (selected) {
                _selectedTime = selected ? time : null;
              },
              backgroundColor: Colors.white,
              disabledColor: Colors.grey[300],
            );
          },
        );
      }).toList(),
    );
  }
}
