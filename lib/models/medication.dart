enum MedicationKind {
  medication,
  supplement;

  String get apiValue => name;

  String get label {
    switch (this) {
      case MedicationKind.medication:
        return '약';
      case MedicationKind.supplement:
        return '영양제';
    }
  }

  static MedicationKind fromString(String? raw) {
    if (raw == 'supplement') return MedicationKind.supplement;
    return MedicationKind.medication;
  }
}

class Medication {
  final String id;
  final String name;
  final MedicationKind kind;
  final String? dosage;
  final String? frequency;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? memo;

  final bool reminderEnabled;
  final List<String> times;
  final List<int> weekdays;

  const Medication({
    required this.id,
    required this.name,
    required this.kind,
    this.dosage,
    this.frequency,
    this.startDate,
    this.endDate,
    this.memo,
    this.reminderEnabled = false,
    this.times = const [],
    this.weekdays = const [],
  });

  factory Medication.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(String? raw) =>
        raw == null ? null : DateTime.parse(raw);

    final timesRaw = map['times'] as List?;
    final weekdaysRaw = map['weekdays'] as List?;

    return Medication(
      id: map['id'] as String,
      name: map['name'] as String,
      kind: MedicationKind.fromString(map['kind'] as String?),
      dosage: map['dosage'] as String?,
      frequency: map['frequency'] as String?,
      startDate: parseDate(map['start_date'] as String?),
      endDate: parseDate(map['end_date'] as String?),
      memo: map['memo'] as String?,
      reminderEnabled: map['reminder_enabled'] as bool? ?? false,
      times:
          timesRaw == null
              ? const []
              : timesRaw.map((e) => e.toString()).toList(),
      weekdays:
          weekdaysRaw == null
              ? const []
              : weekdaysRaw.map((e) => (e as num).toInt()).toList(),
    );
  }

  bool isActiveOn(DateTime day) {
    final dayOnly = DateTime(day.year, day.month, day.day);
    if (startDate != null) {
      final start = DateTime(
        startDate!.year,
        startDate!.month,
        startDate!.day,
      );
      if (dayOnly.isBefore(start)) return false;
    }
    final end = endDate;
    if (end == null) return true;
    final endOnly = DateTime(end.year, end.month, end.day);
    return !endOnly.isBefore(dayOnly);
  }
}
