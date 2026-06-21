class Milestone {
  final String id;
  final String title;
  final DateTime achievedAt;
  final String? memo;

  const Milestone({
    required this.id,
    required this.title,
    required this.achievedAt,
    this.memo,
  });

  factory Milestone.fromMap(Map<String, dynamic> map) {
    return Milestone(
      id: map['id'] as String,
      title: map['title'] as String,
      achievedAt: DateTime.parse(map['achieved_at'] as String),
      memo: map['memo'] as String?,
    );
  }
}
