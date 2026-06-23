// Supabase의 poop_logs 테이블과 매핑되는 모델.
enum PoopShape { normal, soft, diarrhea, hard, blood, none }

enum PoopColor { brown, yellow, black, red, green, white }

extension PoopShapeX on PoopShape {
  String get apiValue {
    switch (this) {
      case PoopShape.normal:
        return 'normal';
      case PoopShape.soft:
        return 'soft';
      case PoopShape.diarrhea:
        return 'diarrhea';
      case PoopShape.hard:
        return 'hard';
      case PoopShape.blood:
        return 'blood';
      case PoopShape.none:
        return 'none';
    }
  }

  String get emoji {
    switch (this) {
      case PoopShape.normal:
        return '💩';
      case PoopShape.soft:
        return '😰';
      case PoopShape.diarrhea:
        return '🌊';
      case PoopShape.hard:
        return '🪨';
      case PoopShape.blood:
        return '🔴';
      case PoopShape.none:
        return '❌';
    }
  }

  String get label {
    switch (this) {
      case PoopShape.normal:
        return '정상';
      case PoopShape.soft:
        return '무름';
      case PoopShape.diarrhea:
        return '설사';
      case PoopShape.hard:
        return '딱딱함';
      case PoopShape.blood:
        return '혈변';
      case PoopShape.none:
        return '없음';
    }
  }

  static PoopShape? fromApi(String? value) {
    if (value == null) return null;
    for (final s in PoopShape.values) {
      if (s.apiValue == value) return s;
    }
    return null;
  }
}

extension PoopColorX on PoopColor {
  String get apiValue {
    switch (this) {
      case PoopColor.brown:
        return 'brown';
      case PoopColor.yellow:
        return 'yellow';
      case PoopColor.black:
        return 'black';
      case PoopColor.red:
        return 'red';
      case PoopColor.green:
        return 'green';
      case PoopColor.white:
        return 'white';
    }
  }

  String get label {
    switch (this) {
      case PoopColor.brown:
        return '갈색';
      case PoopColor.yellow:
        return '노란색';
      case PoopColor.black:
        return '검정';
      case PoopColor.red:
        return '빨간색';
      case PoopColor.green:
        return '초록색';
      case PoopColor.white:
        return '흰색';
    }
  }

  // 색 칩 표시용 16진수.
  int get swatch {
    switch (this) {
      case PoopColor.brown:
        return 0xFF8B5A2B;
      case PoopColor.yellow:
        return 0xFFE3B748;
      case PoopColor.black:
        return 0xFF2A2A2A;
      case PoopColor.red:
        return 0xFFC53030;
      case PoopColor.green:
        return 0xFF4E8B3A;
      case PoopColor.white:
        return 0xFFF2F0EA;
    }
  }

  static PoopColor? fromApi(String? value) {
    if (value == null) return null;
    for (final c in PoopColor.values) {
      if (c.apiValue == value) return c;
    }
    return null;
  }
}

class PoopLog {
  final String id;
  final String petId;
  final DateTime loggedAt;
  final PoopShape? shape;
  final PoopColor? color;
  final String? memo;

  const PoopLog({
    required this.id,
    required this.petId,
    required this.loggedAt,
    this.shape,
    this.color,
    this.memo,
  });

  factory PoopLog.fromMap(Map<String, dynamic> map) {
    return PoopLog(
      id: map['id'] as String,
      petId: map['pet_id'] as String,
      loggedAt: DateTime.parse(map['logged_at'] as String),
      shape: PoopShapeX.fromApi(map['shape'] as String?),
      color: PoopColorX.fromApi(map['color'] as String?),
      memo: map['memo'] as String?,
    );
  }
}
