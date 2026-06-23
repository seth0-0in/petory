// Supabase의 cage_logs / cage_schedules 테이블에서 공통으로 쓰이는 케이지 활동 종류.
enum CageActivityType { cleaning, food, water }

extension CageActivityTypeX on CageActivityType {
  String get apiValue {
    switch (this) {
      case CageActivityType.cleaning:
        return 'cleaning';
      case CageActivityType.food:
        return 'food';
      case CageActivityType.water:
        return 'water';
    }
  }

  String get emoji {
    switch (this) {
      case CageActivityType.cleaning:
        return '🧹';
      case CageActivityType.food:
        return '🍖';
      case CageActivityType.water:
        return '💧';
    }
  }

  String get label {
    switch (this) {
      case CageActivityType.cleaning:
        return '청소';
      case CageActivityType.food:
        return '먹이';
      case CageActivityType.water:
        return '물';
    }
  }

  String get reminderTitle {
    switch (this) {
      case CageActivityType.cleaning:
        return '🧺 케이지 청소할 시간이에요';
      case CageActivityType.food:
        return '🍖 먹이 줄 시간이에요';
      case CageActivityType.water:
        return '💧 물 교체할 시간이에요';
    }
  }

  static CageActivityType? fromApi(String? value) {
    if (value == null) return null;
    for (final t in CageActivityType.values) {
      if (t.apiValue == value) return t;
    }
    return null;
  }
}

class CageLog {
  final String id;
  final String petId;
  final CageActivityType type;
  final DateTime loggedAt;
  final String? memo;

  const CageLog({
    required this.id,
    required this.petId,
    required this.type,
    required this.loggedAt,
    this.memo,
  });

  factory CageLog.fromMap(Map<String, dynamic> map) {
    final type = CageActivityTypeX.fromApi(map['type'] as String?);
    if (type == null) {
      throw FormatException('Unknown cage_log type: ${map['type']}');
    }
    return CageLog(
      id: map['id'] as String,
      petId: map['pet_id'] as String,
      type: type,
      loggedAt: DateTime.parse(map['logged_at'] as String),
      memo: map['memo'] as String?,
    );
  }
}
