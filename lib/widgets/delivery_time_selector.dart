import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:happy/classes/restaurant.dart';
import 'package:intl/intl.dart';

class DeliveryTimeSelector extends StatefulWidget {
  final Restaurant restaurant;
  final DateTime? selectedTime;
  final Function(DateTime?) onTimeSelected;
  final String deliveryType;
  final Function(String) onDeliveryTypeChanged;

  const DeliveryTimeSelector({
    super.key,
    required this.restaurant,
    required this.selectedTime,
    required this.onTimeSelected,
    required this.deliveryType,
    required this.onDeliveryTypeChanged,
  });

  @override
  State<DeliveryTimeSelector> createState() => _DeliveryTimeSelectorState();
}

class _DeliveryTimeSelectorState extends State<DeliveryTimeSelector> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  final List<DateTime> _availableSlots = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _selectedTime = TimeOfDay.now();
    _generateAvailableSlots();
  }

  void _generateAvailableSlots() {
    _availableSlots.clear();
    final now = DateTime.now();
    
    // Générer des créneaux pour les 7 prochains jours
    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final date = DateTime(now.year, now.month, now.day + dayOffset);
      final slots = _getAvailableSlotsForDate(date);
      _availableSlots.addAll(slots);
    }
  }

  List<DateTime> _getAvailableSlotsForDate(DateTime date) {
    final slots = <DateTime>[];
    final dayName = _getDayName(date.weekday);
    final hours = widget.restaurant.openingHours.schedule[dayName];
    
    if (hours == null || hours == 'fermé') {
      return slots;
    }

    // Essayer d'abord le format avec virgules (format standard)
    if (hours.contains(',')) {
      final timeRanges = hours.split(',');
      for (final range in timeRanges) {
        _addSlotsForRange(range.trim(), date, slots);
      }
    } else {
      // Format avec espaces et tirets multiples (ex: "9h 13H30 - 15h15 - 18h00")
      final parts = hours.split(' ');
      final timeRanges = <String>[];
      
      for (int i = 0; i < parts.length - 1; i++) {
        if (parts[i + 1].contains('-')) {
          // Trouver la fin de cette plage
          int endIndex = i + 1;
          while (endIndex < parts.length && parts[endIndex].contains('-')) {
            endIndex++;
          }
          
          // Construire la plage complète
          final range = parts.sublist(i, endIndex).join(' ');
          timeRanges.add(range);
          i = endIndex - 1; // Sauter les parties déjà traitées
        }
      }
      
      // Traiter chaque plage trouvée
      for (final range in timeRanges) {
        _addSlotsForRange(range, date, slots);
      }
    }
    
    return slots;
  }

  void _addSlotsForRange(String range, DateTime date, List<DateTime> slots) {
    final parts = range.trim().split('-');
    if (parts.length == 2) {
      final startTime = _parseTime(parts[0].trim());
      final endTime = _parseTime(parts[1].trim());
      
      if (startTime != null && endTime != null) {
        // Créer des créneaux toutes les 30 minutes
        DateTime currentSlot = DateTime(
          date.year,
          date.month,
          date.day,
          startTime.hour,
          startTime.minute,
        );
        
        final endDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          endTime.hour,
          endTime.minute,
        );
        
        // Ajouter le temps de préparation (minimum 30 minutes)
        final minDeliveryTime = DateTime.now().add(const Duration(minutes: 30));
        
        while (currentSlot.isBefore(endDateTime)) {
          // Vérifier que le créneau est dans le futur et respecte le temps de préparation
          if (currentSlot.isAfter(minDeliveryTime)) {
            slots.add(currentSlot);
          }
          currentSlot = currentSlot.add(const Duration(minutes: 30));
        }
      }
    }
  }

  TimeOfDay? _parseTime(String timeStr) {
    try {
      // Nettoyer et normaliser le format d'heure
      timeStr = _normalizeTimeFormat(timeStr);
      
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    } catch (e) {
      debugPrint('Erreur parsing time: $e pour $timeStr');
    }
    return null;
  }

  String _normalizeTimeFormat(String timeStr) {
    // Supprimer les espaces
    timeStr = timeStr.replaceAll(' ', '');
    
    // Remplacer H et h par :
    timeStr = timeStr.replaceAll('H', ':').replaceAll('h', ':');
    
    // S'assurer qu'il y a bien des deux-points
    if (!timeStr.contains(':')) {
      // Si pas de deux-points, essayer de les ajouter (ex: "1330" -> "13:30")
      if (timeStr.length == 4) {
        timeStr = '${timeStr.substring(0, 2)}:${timeStr.substring(2)}';
      }
    }
    
    return timeStr;
  }

  String _getDayName(int weekday) {
    const days = [
      'monday', 'tuesday', 'wednesday', 'thursday',
      'friday', 'saturday', 'sunday'
    ];
    return days[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Heure de livraison',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          
          SizedBox(height: 16.h),
          
          // Type de livraison
          Row(
            children: [
              Expanded(
                child: _buildDeliveryTypeButton(
                  'asap',
                  'Le plus tôt possible',
                  Icons.flash_on,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildDeliveryTypeButton(
                  'scheduled',
                  'Planifier',
                  Icons.schedule,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16.h),
          
          // Sélection de l'heure si planifié
          if (widget.deliveryType == 'scheduled') ...[
            Text(
              'Choisir une heure',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            
            SizedBox(height: 12.h),
            
            if (_availableSlots.isEmpty)
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange[600],
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Aucun créneau disponible pour les 7 prochains jours',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 200.h,
                child: ListView.builder(
                  itemCount: _availableSlots.length,
                  itemBuilder: (context, index) {
                    final slot = _availableSlots[index];
                    final isSelected = widget.selectedTime != null &&
                        widget.selectedTime!.year == slot.year &&
                        widget.selectedTime!.month == slot.month &&
                        widget.selectedTime!.day == slot.day &&
                        widget.selectedTime!.hour == slot.hour &&
                        widget.selectedTime!.minute == slot.minute;
                    
                    return GestureDetector(
                      onTap: () => widget.onTimeSelected(slot),
                      child: Container(
                        margin: EdgeInsets.only(bottom: 8.h),
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Theme.of(context).primaryColor.withOpacity(0.1)
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: isSelected 
                                ? Theme.of(context).primaryColor
                                : Colors.grey[300]!,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 20.sp,
                              color: isSelected 
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[600],
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('EEEE d MMMM', 'fr_FR').format(slot),
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected 
                                          ? Theme.of(context).primaryColor
                                          : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('HH:mm').format(slot),
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected 
                                          ? Theme.of(context).primaryColor
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: Theme.of(context).primaryColor,
                                size: 20.sp,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ] else ...[
            // Affichage pour livraison ASAP
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.flash_on,
                    color: Colors.green[600],
                    size: 20.sp,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Livraison le plus tôt possible',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                        Text(
                          'Temps de préparation: ${widget.restaurant.preparationTime} min',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.green[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveryTypeButton(
    String type,
    String label,
    IconData icon,
  ) {
    final isSelected = widget.deliveryType == type;
    
    return GestureDetector(
      onTap: () => widget.onDeliveryTypeChanged(type),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).primaryColor
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).primaryColor
                : Colors.grey[300]!,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24.sp,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
} 