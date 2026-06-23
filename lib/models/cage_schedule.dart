import 'cage_log.dart';

// Supabase의 cage_schedules 테이블 매핑. 펫+활동종류 1:1 (UNIQUE(pet_id, type)).
class CageSchedule {
  final String id;
  final String petId;
  final CageActivityType type;
  final int intervalHours; // "N시간마다" 표시·다음 예정 시각 계산용
  final List<String> reminderTimes; // HH:mm
  final bool enabled;

  const CageSchedule({
    required this.id,
    required this.petId,
    required this.type,
    required this.intervalHours,
    this.reminderTimes = const [],
    this.enabled = true,
  });

  factory CageSchedule.fromMap(Map<String, dynamic> map) {
    final type = CageActivityTypeX.fromApi(map['type'] as String?);
    if (type == null) {
      throw FormatException('Unknown cage_schedule type: ${map['type']}');
    }
    final rawTimes = (map['reminder_times'] as List?) ?? const [];
    return CageSchedule(
      id: map['id'] as String,
      petId: map['pet_id'] as String,
      type: type,
      intervalHours: (map['interval_hours'] as num?)?.toInt() ?? 0,
      reminderTimes: rawTimes.map((e) => e.toString()).toList(),
      enabled: (map['enabled'] as bool?) ?? true,
    );
  }
}
