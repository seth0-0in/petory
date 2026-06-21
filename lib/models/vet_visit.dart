class VetVisit {
  final String id;
  final DateTime visitedAt;
  final String? hospital;
  final String? reason;
  final String? diagnosis;
  final String? treatment;
  final int? cost;
  final String? memo;

  const VetVisit({
    required this.id,
    required this.visitedAt,
    this.hospital,
    this.reason,
    this.diagnosis,
    this.treatment,
    this.cost,
    this.memo,
  });

  factory VetVisit.fromMap(Map<String, dynamic> map) {
    final costRaw = map['cost'];
    return VetVisit(
      id: map['id'] as String,
      visitedAt: DateTime.parse(map['visited_at'] as String),
      hospital: map['hospital'] as String?,
      reason: map['reason'] as String?,
      diagnosis: map['diagnosis'] as String?,
      treatment: map['treatment'] as String?,
      cost: costRaw == null ? null : (costRaw as num).toInt(),
      memo: map['memo'] as String?,
    );
  }
}
