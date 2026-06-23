// Supabase의 grooming_records 테이블과 매핑되는 모델.
//
// 시술 항목(services)은 JSONB 문자열 배열로 저장되며,
// 아래 키들 중 다중 선택 가능 (UI는 이모지+라벨로 표시).
enum GroomingService { bath, cut, nail, ear, anal, teeth, other }

extension GroomingServiceX on GroomingService {
  String get apiValue {
    switch (this) {
      case GroomingService.bath:
        return 'bath';
      case GroomingService.cut:
        return 'cut';
      case GroomingService.nail:
        return 'nail';
      case GroomingService.ear:
        return 'ear';
      case GroomingService.anal:
        return 'anal';
      case GroomingService.teeth:
        return 'teeth';
      case GroomingService.other:
        return 'other';
    }
  }

  String get emoji {
    switch (this) {
      case GroomingService.bath:
        return '🛁';
      case GroomingService.cut:
        return '✂️';
      case GroomingService.nail:
        return '💅';
      case GroomingService.ear:
        return '👂';
      case GroomingService.anal:
        return '💨';
      case GroomingService.teeth:
        return '🦷';
      case GroomingService.other:
        return '✨';
    }
  }

  String get label {
    switch (this) {
      case GroomingService.bath:
        return '목욕';
      case GroomingService.cut:
        return '미용(컷)';
      case GroomingService.nail:
        return '발톱';
      case GroomingService.ear:
        return '귀청소';
      case GroomingService.anal:
        return '항문낭';
      case GroomingService.teeth:
        return '양치';
      case GroomingService.other:
        return '기타';
    }
  }

  static GroomingService? fromApi(String? value) {
    if (value == null) return null;
    for (final s in GroomingService.values) {
      if (s.apiValue == value) return s;
    }
    return null;
  }
}

class GroomingRecord {
  final String id;
  final String petId;
  final DateTime groomedAt;
  final String? salonName;
  final List<GroomingService> services;
  final int? cost;
  final DateTime? nextDueAt;
  final String? memo;

  const GroomingRecord({
    required this.id,
    required this.petId,
    required this.groomedAt,
    this.salonName,
    this.services = const [],
    this.cost,
    this.nextDueAt,
    this.memo,
  });

  factory GroomingRecord.fromMap(Map<String, dynamic> map) {
    final rawServices = (map['services'] as List?) ?? const [];
    final services = <GroomingService>[];
    for (final raw in rawServices) {
      final parsed = GroomingServiceX.fromApi(raw?.toString());
      if (parsed != null) services.add(parsed);
    }
    final costRaw = map['cost'];
    final nextRaw = map['next_due_at'] as String?;
    return GroomingRecord(
      id: map['id'] as String,
      petId: map['pet_id'] as String,
      groomedAt: DateTime.parse(map['groomed_at'] as String),
      salonName: map['salon_name'] as String?,
      services: services,
      cost: costRaw == null ? null : (costRaw as num).toInt(),
      nextDueAt: nextRaw == null ? null : DateTime.parse(nextRaw),
      memo: map['memo'] as String?,
    );
  }
}
