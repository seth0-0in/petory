class Vaccination {
  final String id;
  final String name;
  final DateTime? administeredAt;
  final DateTime? nextDueAt;
  final String? memo;

  const Vaccination({
    required this.id,
    required this.name,
    this.administeredAt,
    this.nextDueAt,
    this.memo,
  });

  factory Vaccination.fromMap(Map<String, dynamic> map) {
    final adminRaw = map['administered_at'] as String?;
    final nextDueRaw = map['next_due_at'] as String?;
    return Vaccination(
      id: map['id'] as String,
      name: map['name'] as String,
      administeredAt: adminRaw == null ? null : DateTime.parse(adminRaw),
      nextDueAt: nextDueRaw == null ? null : DateTime.parse(nextDueRaw),
      memo: map['memo'] as String?,
    );
  }

  bool get isCompleted => administeredAt != null;
  bool get isScheduled => administeredAt == null && nextDueAt != null;
  DateTime? get eventDate => administeredAt ?? nextDueAt;
}
