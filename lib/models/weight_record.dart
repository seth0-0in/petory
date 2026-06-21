class WeightRecord {
  final String id;
  final double weightKg;
  final DateTime measuredAt;

  const WeightRecord({
    required this.id,
    required this.weightKg,
    required this.measuredAt,
  });

  factory WeightRecord.fromMap(Map<String, dynamic> map) {
    return WeightRecord(
      id: map['id'] as String,
      weightKg: (map['weight_kg'] as num).toDouble(),
      measuredAt: DateTime.parse(map['measured_at'] as String),
    );
  }
}
