// Supabase의 water_logs 테이블과 매핑되는 모델.
class WaterLog {
  final String id;
  final String petId;
  final DateTime loggedAt;
  final int volumeMl;
  final String? memo;

  const WaterLog({
    required this.id,
    required this.petId,
    required this.loggedAt,
    required this.volumeMl,
    this.memo,
  });

  factory WaterLog.fromMap(Map<String, dynamic> map) {
    final raw = map['volume_ml'];
    final volume = raw is int
        ? raw
        : raw is num
            ? raw.toInt()
            : int.parse(raw.toString());
    return WaterLog(
      id: map['id'] as String,
      petId: map['pet_id'] as String,
      loggedAt: DateTime.parse(map['logged_at'] as String),
      volumeMl: volume,
      memo: map['memo'] as String?,
    );
  }
}
