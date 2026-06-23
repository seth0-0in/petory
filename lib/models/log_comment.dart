// Supabase의 log_comments 테이블과 매핑되는 모델.
//
// 가정한 스키마:
//   id         uuid primary key default gen_random_uuid()
//   log_id     uuid references logs(id) on delete cascade
//   user_id    uuid references auth.users(id) on delete set null
//   content    text not null
//   created_at timestamptz not null default now()
class LogComment {
  final String id;
  final String logId;
  final String? userId;
  final String content;
  final DateTime createdAt;

  const LogComment({
    required this.id,
    required this.logId,
    required this.userId,
    required this.content,
    required this.createdAt,
  });

  factory LogComment.fromMap(Map<String, dynamic> map) {
    final createdRaw = map['created_at'] as String?;
    return LogComment(
      id: map['id'] as String,
      logId: map['log_id'] as String,
      userId: map['user_id'] as String?,
      content: (map['content'] as String?) ?? '',
      createdAt:
          createdRaw == null ? DateTime.now() : DateTime.parse(createdRaw),
    );
  }
}

// 이메일 주소에서 '@' 앞부분만 추출. 표시용 짧은 이름.
// "sejin@example.com" → "sejin"
// null/빈 문자열이면 fallback 반환.
String displayNameFromEmail(String? email, {String fallback = '익명'}) {
  if (email == null || email.isEmpty) return fallback;
  final at = email.indexOf('@');
  if (at <= 0) return email;
  return email.substring(0, at);
}

// 상대 시간 표시. "방금" / "3분 전" / "5시간 전" / "2일 전" / "2024.05.21"
String formatRelativeKo(DateTime time, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = n.difference(time);
  if (diff.inSeconds < 60) return '방금';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  final y = time.year.toString().padLeft(4, '0');
  final m = time.month.toString().padLeft(2, '0');
  final d = time.day.toString().padLeft(2, '0');
  return '$y.$m.$d';
}
