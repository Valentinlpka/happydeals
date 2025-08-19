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
  final List<DateTime> _availableSlots = [];

  @override
  void initState() {
    super.initState();
    _generateAvailableSlots();
  }

  void _generateAvailableSlots() {
    debugPrint('🕐 DeliveryTimeSelector - DÉBUT génération des créneaux disponibles');
    _availableSlots.clear();
    final now = DateTime.now();
    
    // Générer des créneaux SEULEMENT pour aujourd'hui
    final today = DateTime(now.year, now.month, now.day);
    debugPrint('🕐 DeliveryTimeSelector - Traitement d\'aujourd\'hui uniquement: ${today.day}/${today.month}/${today.year}');
    debugPrint('🕐 DeliveryTimeSelector - Heure actuelle: ${now.hour}h${now.minute.toString().padLeft(2, '0')}');
    
    final slots = _getAvailableSlotsForDate(today, currentTime: now);
    _availableSlots.addAll(slots);
    
    debugPrint('🕐 DeliveryTimeSelector - FIN génération: ${_availableSlots.length} créneaux au total');
  }

  List<DateTime> _getAvailableSlotsForDate(DateTime date, {DateTime? currentTime}) {
    final slots = <DateTime>[];
    final dayName = _getDayName(date.weekday);
    final hours = widget.restaurant.openingHours.schedule[dayName];
    final now = currentTime ?? DateTime.now();
    
    debugPrint('🕐 DeliveryTimeSelector - Jour: $dayName, Horaires: "$hours"');
    
    if (hours == null || hours == 'fermé') {
      debugPrint('🕐 DeliveryTimeSelector - Restaurant fermé le $dayName');
      return slots;
    }

    // Format avec "/" pour séparer les plages (ex: "09:00 - 13:30 / 14:00 - 18:00")
    if (hours.contains('/')) {
      debugPrint('🕐 DeliveryTimeSelector - Format avec "/" détecté');
      final timeRanges = hours.split('/');
      for (final range in timeRanges) {
        final trimmedRange = range.trim();
        debugPrint('🕐 DeliveryTimeSelector - Évaluation de la plage: "$trimmedRange"');
        
        // Vérifier si cette plage est la plage actuelle
        if (_isCurrentTimeRange(trimmedRange, now)) {
          debugPrint('🕐 DeliveryTimeSelector - ✅ Plage actuelle trouvée: "$trimmedRange"');
          _addSlotsForRange(trimmedRange, date, slots, currentTime: now);
          break; // Ne traiter que la plage actuelle
        } else {
          debugPrint('🕐 DeliveryTimeSelector - ❌ Plage non actuelle: "$trimmedRange"');
        }
      }
    }
    // Format avec virgules (format alternatif)
    else if (hours.contains(',')) {
      debugPrint('🕐 DeliveryTimeSelector - Format avec "," détecté');
      final timeRanges = hours.split(',');
      for (final range in timeRanges) {
        final trimmedRange = range.trim();
        debugPrint('🕐 DeliveryTimeSelector - Évaluation de la plage: "$trimmedRange"');
        
        if (_isCurrentTimeRange(trimmedRange, now)) {
          debugPrint('🕐 DeliveryTimeSelector - ✅ Plage actuelle trouvée: "$trimmedRange"');
          _addSlotsForRange(trimmedRange, date, slots, currentTime: now);
          break;
        } else {
          debugPrint('🕐 DeliveryTimeSelector - ❌ Plage non actuelle: "$trimmedRange"');
        }
      }
    }
    // Format simple avec un seul tiret (ex: "09:00 - 18:00")
    else if (hours.contains('-')) {
      debugPrint('🕐 DeliveryTimeSelector - Format simple avec "-" détecté');
      _addSlotsForRange(hours.trim(), date, slots, currentTime: now);
    }
    else {
      debugPrint('🕐 DeliveryTimeSelector - ⚠️ Format d\'horaires non reconnu: "$hours"');
    }
    
    debugPrint('🕐 DeliveryTimeSelector - ${slots.length} créneaux générés pour le $dayName');
    return slots;
  }

  /// Vérifie si l'heure actuelle est dans la plage horaire donnée
  bool _isCurrentTimeRange(String range, DateTime now) {
    final parts = range.trim().split('-');
    if (parts.length != 2) {
      debugPrint('🕐 DeliveryTimeSelector - _isCurrentTimeRange: Format invalide "$range"');
      return false;
    }
    
    final startTime = _parseTime(parts[0].trim());
    final endTime = _parseTime(parts[1].trim());
    
    if (startTime == null || endTime == null) {
      debugPrint('🕐 DeliveryTimeSelector - _isCurrentTimeRange: Erreur parsing "$range"');
      return false;
    }
    
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    
    final isInRange = currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    
    debugPrint('🕐 DeliveryTimeSelector - _isCurrentTimeRange: ${now.hour}h${now.minute.toString().padLeft(2, '0')} dans "$range" = $isInRange');
    debugPrint('🕐 DeliveryTimeSelector - Détail: $currentMinutes min >= $startMinutes min && <= $endMinutes min');
    
    return isInRange;
  }

  void _addSlotsForRange(String range, DateTime date, List<DateTime> slots, {DateTime? currentTime}) {
    debugPrint('🕐 DeliveryTimeSelector - _addSlotsForRange: "$range"');
    
    final parts = range.trim().split('-');
    if (parts.length != 2) {
      debugPrint('🕐 DeliveryTimeSelector - ⚠️ Format de plage invalide: "$range" (${parts.length} parties)');
      return;
    }
    
    final startTime = _parseTime(parts[0].trim());
    final endTime = _parseTime(parts[1].trim());
    
    debugPrint('🕐 DeliveryTimeSelector - Heure début: ${parts[0].trim()} -> $startTime');
    debugPrint('🕐 DeliveryTimeSelector - Heure fin: ${parts[1].trim()} -> $endTime');
    
    if (startTime == null || endTime == null) {
      debugPrint('🕐 DeliveryTimeSelector - ⚠️ Erreur parsing des heures pour "$range"');
      return;
    }
    
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
    final now = currentTime ?? DateTime.now();
    final minDeliveryTime = now.add(const Duration(minutes: 30));
    
    debugPrint('🕐 DeliveryTimeSelector - Génération créneaux de $currentSlot à $endDateTime');
    debugPrint('🕐 DeliveryTimeSelector - Temps minimum de livraison: $minDeliveryTime');
    
    int slotsAdded = 0;
    while (currentSlot.isBefore(endDateTime)) {
      // Vérifier que le créneau est dans le futur et respecte le temps de préparation
      if (currentSlot.isAfter(minDeliveryTime)) {
        slots.add(currentSlot);
        slotsAdded++;
      }
      currentSlot = currentSlot.add(const Duration(minutes: 30));
    }
    
    debugPrint('🕐 DeliveryTimeSelector - $slotsAdded créneaux ajoutés pour la plage "$range"');
  }

  TimeOfDay? _parseTime(String timeStr) {
    final originalTimeStr = timeStr;
    try {
      // Nettoyer et normaliser le format d'heure
      timeStr = _normalizeTimeFormat(timeStr);
      debugPrint('🕐 DeliveryTimeSelector - _parseTime: "$originalTimeStr" -> "$timeStr"');
      
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        debugPrint('🕐 DeliveryTimeSelector - Parsed: ${hour}h${minute.toString().padLeft(2, '0')}');
        return TimeOfDay(hour: hour, minute: minute);
      } else {
        debugPrint('🕐 DeliveryTimeSelector - ⚠️ Format invalide après normalisation: "$timeStr" (${parts.length} parties)');
      }
    } catch (e) {
      debugPrint('🕐 DeliveryTimeSelector - ⚠️ Erreur parsing time: $e pour "$originalTimeStr" -> "$timeStr"');
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
            'Heure de retrait',
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