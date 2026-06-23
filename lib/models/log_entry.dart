import 'log_like.dart';
import 'log_media.dart';

// Supabase의 logs 테이블과 매핑되는 모델 클래스.
class LogEntry {
  final String id;
  final String content;
  final DateTime createdAt;
  // 하위 호환을 위해 남겨둔 단일 사진 URL. 새 기록은 media 사용.
  final String? photoUrl;
  // 새 다중 미디어(사진/동영상). 빈 리스트면 photoUrl 폴백.
  final List<LogMedia> media;
  // 좋아요 목록. fetchLogs select에서 log_likes embed로 채움.
  final List<LogLike> likes;

  const LogEntry({
    required this.id,
    required this.content,
    required this.createdAt,
    this.photoUrl,
    this.media = const [],
    this.likes = const [],
  });

  // 표시용 통합 미디어 리스트. media가 비어 있으면 photoUrl을 단일 이미지로 변환.
  List<LogMedia> get displayMedia {
    if (media.isNotEmpty) return media;
    final url = photoUrl;
    if (url == null) return const [];
    return [
      LogMedia(
        id: 'legacy-$id',
        logId: id,
        mediaUrl: url,
        mediaType: 'image',
        position: 0,
        createdAt: createdAt,
      ),
    ];
  }

  bool get hasMedia => media.isNotEmpty || photoUrl != null;

  int get likeCount => likes.length;

  bool isLikedBy(String? userId) {
    if (userId == null) return false;
    for (final l in likes) {
      if (l.userId == userId) return true;
    }
    return false;
  }

  factory LogEntry.fromMap(Map<String, dynamic> map) {
    final raw = (map['logged_at'] ?? map['created_at']) as String;
    final mediaRaw = map['log_media'];
    final mediaList = <LogMedia>[];
    if (mediaRaw is List) {
      for (final m in mediaRaw) {
        if (m is Map<String, dynamic>) {
          mediaList.add(LogMedia.fromMap(m));
        }
      }
      mediaList.sort((a, b) => a.position.compareTo(b.position));
    }
    final likesRaw = map['log_likes'];
    final likeList = <LogLike>[];
    if (likesRaw is List) {
      for (final l in likesRaw) {
        if (l is Map<String, dynamic>) {
          likeList.add(LogLike.fromMap(l));
        }
      }
    }
    return LogEntry(
      id: map['id'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(raw),
      photoUrl: map['photo_url'] as String?,
      media: mediaList,
      likes: likeList,
    );
  }

  LogEntry copyWith({List<LogMedia>? media, List<LogLike>? likes}) {
    return LogEntry(
      id: id,
      content: content,
      createdAt: createdAt,
      photoUrl: photoUrl,
      media: media ?? this.media,
      likes: likes ?? this.likes,
    );
  }
}
