// Supabase의 heat_cycles 테이블과 매핑되는 모델.
// symptoms는 JSONB 문자열 배열로 저장.
enum HeatSymptom { bleeding, swelling, behavior, appetite, vocal, other }

extension HeatSymptomX on HeatSymptom {
  String get apiValue {
    switch (this) {
      case HeatSymptom.bleeding:
        return 'bleeding';
      case HeatSymptom.swelling:
        return 'swelling';
      case HeatSymptom.behavior:
        return 'behavior';
      case HeatSymptom.appetite:
        return 'appetite';
      case HeatSymptom.vocal:
        return 'vocal';
      case HeatSymptom.other:
        return 'other';
    }
  }

  String get emoji {
    switch (this) {
      case HeatSymptom.bleeding:
        return '🩸';
      case HeatSymptom.swelling:
        return '🫧';
      case HeatSymptom.behavior:
        return '😾';
      case HeatSymptom.appetite:
        return '🍽️';
      case HeatSymptom.vocal:
        return '😿';
      case HeatSymptom.other:
        return '✨';
    }
  }

  String get label {
    switch (this) {
      case HeatSymptom.bleeding:
        return '출혈';
      case HeatSymptom.swelling:
        return '부종';
      case HeatSymptom.behavior:
        return '행동변화';
      case HeatSymptom.appetite:
        return '식욕변화';
      case HeatSymptom.vocal:
        return '울음증가';
      case HeatSymptom.other:
        return '기타';
    }
  }

  static HeatSymptom? fromApi(String? value) {
    if (value == null) return null;
    for (final s in HeatSymptom.values) {
      if (s.apiValue == value) return s;
    }
    return null;
  }
}

class HeatCycle {
  final String id;
  final String petId;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? nextExpected;
  final List<HeatSymptom> symptoms;
  final String? memo;

  const HeatCycle({
    required this.id,
    required this.petId,
    required this.startDate,
    this.endDate,
    this.nextExpected,
    this.symptoms = const [],
    this.memo,
  });

  bool get isOngoing => endDate == null;

  int? get durationDays {
    final end = endDate;
    if (end == null) return null;
    final s = DateTime(startDate.year, startDate.month, startDate.day);
    final e = DateTime(end.year, end.month, end.day);
    return e.difference(s).inDays + 1;
  }

  factory HeatCycle.fromMap(Map<String, dynamic> map) {
    final rawSymptoms = (map['symptoms'] as List?) ?? const [];
    final symptoms = <HeatSymptom>[];
    for (final raw in rawSymptoms) {
      final parsed = HeatSymptomX.fromApi(raw?.toString());
      if (parsed != null) symptoms.add(parsed);
    }
    final endRaw = map['end_date'] as String?;
    final nextRaw = map['next_expected'] as String?;
    return HeatCycle(
      id: map['id'] as String,
      petId: map['pet_id'] as String,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: endRaw == null ? null : DateTime.parse(endRaw),
      nextExpected: nextRaw == null ? null : DateTime.parse(nextRaw),
      symptoms: symptoms,
      memo: map['memo'] as String?,
    );
  }
}
