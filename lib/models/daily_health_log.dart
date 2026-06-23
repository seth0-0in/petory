// Supabase의 daily_health_logs 테이블과 매핑되는 모델.
// 시니어 펫 매일 건강 체크 (식욕/활동량/수면/배변 1~5점, 통증 신호 boolean).
class DailyHealthLog {
  final String id;
  final String petId;
  final DateTime loggedDate;
  final int? appetite;
  final int? activity;
  final int? sleep;
  final int? digestion;
  final bool painSigns;
  final String? memo;

  const DailyHealthLog({
    required this.id,
    required this.petId,
    required this.loggedDate,
    this.appetite,
    this.activity,
    this.sleep,
    this.digestion,
    this.painSigns = false,
    this.memo,
  });

  factory DailyHealthLog.fromMap(Map<String, dynamic> map) {
    int? toInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    return DailyHealthLog(
      id: map['id'] as String,
      petId: map['pet_id'] as String,
      loggedDate: DateTime.parse(map['logged_date'] as String),
      appetite: toInt(map['appetite']),
      activity: toInt(map['activity']),
      sleep: toInt(map['sleep']),
      digestion: toInt(map['digestion']),
      painSigns: (map['pain_signs'] as bool?) ?? false,
      memo: map['memo'] as String?,
    );
  }
}
