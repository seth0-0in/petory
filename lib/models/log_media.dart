// Supabase의 log_media 테이블과 매핑되는 모델.
// 한 개의 일기(LogEntry)에 여러 장의 사진/동영상을 첨부할 수 있어요.
class LogMedia {
  final String id;
  final String logId;
  final String mediaUrl;
  final String mediaType; // 'image' | 'video'
  final int position;
  final DateTime createdAt;

  const LogMedia({
    required this.id,
    required this.logId,
    required this.mediaUrl,
    required this.mediaType,
    required this.position,
    required this.createdAt,
  });

  bool get isVideo => mediaType == 'video';
  bool get isImage => mediaType == 'image';

  factory LogMedia.fromMap(Map<String, dynamic> map) {
    final createdRaw = map['created_at'] as String?;
    return LogMedia(
      id: map['id'] as String,
      logId: map['log_id'] as String,
      mediaUrl: map['media_url'] as String,
      mediaType: (map['media_type'] as String?) ?? 'image',
      position: (map['position'] as num?)?.toInt() ?? 0,
      createdAt: createdRaw == null
          ? DateTime.now()
          : DateTime.parse(createdRaw),
    );
  }
}
