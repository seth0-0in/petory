// Supabase의 log_likes 테이블과 매핑되는 모델.
//
// 가정한 스키마:
//   id         uuid primary key default gen_random_uuid()
//   log_id     uuid references logs(id) on delete cascade
//   user_id    uuid references auth.users(id) on delete cascade
//   created_at timestamptz not null default now()
//   unique(log_id, user_id)
class LogLike {
  final String id;
  final String logId;
  final String userId;
  final DateTime createdAt;

  const LogLike({
    required this.id,
    required this.logId,
    required this.userId,
    required this.createdAt,
  });

  factory LogLike.fromMap(Map<String, dynamic> map) {
    final createdRaw = map['created_at'] as String?;
    return LogLike(
      id: map['id'] as String,
      logId: map['log_id'] as String,
      userId: map['user_id'] as String,
      createdAt:
          createdRaw == null ? DateTime.now() : DateTime.parse(createdRaw),
    );
  }
}
