// Supabase의 logs 테이블과 매핑되는 모델 클래스.
class LogEntry {
  final String id;
  final String content;
  final DateTime createdAt;
  final String? photoUrl;

  const LogEntry({
    required this.id,
    required this.content,
    required this.createdAt,
    this.photoUrl,
  });

  factory LogEntry.fromMap(Map<String, dynamic> map) {
    final raw = (map['logged_at'] ?? map['created_at']) as String;
    return LogEntry(
      id: map['id'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(raw),
      photoUrl: map['photo_url'] as String?,
    );
  }
}
