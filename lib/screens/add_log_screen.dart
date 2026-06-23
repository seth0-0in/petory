import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../models/log_entry.dart';
import '../models/log_media.dart';
import '../services/supabase_service.dart';

const int _kMaxMedia = 10;

class AddLogScreen extends StatefulWidget {
  final String petId;
  final LogEntry? existing;

  const AddLogScreen({super.key, required this.petId, this.existing});

  @override
  State<AddLogScreen> createState() => _AddLogScreenState();
}

// 미디어 선택 항목: 기존(서버) 또는 새로 첨부한 로컬 파일.
class _MediaItem {
  // 기존 미디어이면 not null. 새 미디어이면 null.
  final LogMedia? existing;
  // 새로 첨부한 로컬 바이트(서버 업로드 전).
  final Uint8List? localBytes;
  final String? localMimeType;
  final String? localExtension;
  // 'image' | 'video'
  final String mediaType;

  _MediaItem.existing(LogMedia media)
      : existing = media,
        localBytes = null,
        localMimeType = null,
        localExtension = null,
        mediaType = media.mediaType;

  const _MediaItem.local({
    required Uint8List bytes,
    required String mimeType,
    required String extension,
    required this.mediaType,
  })  : existing = null,
        localBytes = bytes,
        localMimeType = mimeType,
        localExtension = extension;

  bool get isLocal => localBytes != null;
  bool get isVideo => mediaType == 'video';
}

class _AddLogScreenState extends State<AddLogScreen> {
  final SupabaseService _service = SupabaseService();
  final ImagePicker _picker = ImagePicker();
  late final TextEditingController _controller;

  final List<_MediaItem> _items = [];
  bool _saving = false;

  bool get _isEdit => widget.existing != null;
  bool get _atMax => _items.length >= _kMaxMedia;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _controller = TextEditingController(text: existing?.content ?? '');

    if (existing != null) {
      for (final m in existing.displayMedia) {
        _items.add(_MediaItem.existing(m));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showMaxReached() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('미디어는 최대 $_kMaxMedia개까지 첨부할 수 있어요.')),
    );
  }

  Future<void> _pickImages() async {
    if (_atMax) {
      _showMaxReached();
      return;
    }
    final remaining = _kMaxMedia - _items.length;
    final picked = await _picker.pickMultiImage(limit: remaining);
    if (picked.isEmpty) return;

    final selected = picked.take(remaining).toList();
    for (final file in selected) {
      final bytes = await file.readAsBytes();
      _items.add(
        _MediaItem.local(
          bytes: bytes,
          mimeType: file.mimeType ?? 'image/jpeg',
          extension: _extFromName(file.name) ?? 'jpg',
          mediaType: 'image',
        ),
      );
    }
    if (!mounted) return;
    setState(() {});
    if (picked.length > remaining) {
      _showMaxReached();
    }
  }

  Future<void> _pickVideo() async {
    if (_atMax) {
      _showMaxReached();
      return;
    }
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    _items.add(
      _MediaItem.local(
        bytes: bytes,
        mimeType: picked.mimeType ?? 'video/mp4',
        extension: _extFromName(picked.name) ?? 'mp4',
        mediaType: 'video',
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  String? _extFromName(String name) {
    final i = name.lastIndexOf('.');
    if (i < 0 || i == name.length - 1) return null;
    return name.substring(i + 1).toLowerCase();
  }

  void _removeAt(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용을 입력해 주세요.')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final LogEntry savedEntry;
      if (_isEdit) {
        final existing = widget.existing!;
        // 레거시 photo_url이 _items에 없으면 제거된 것으로 간주.
        final keptLegacyId = existing.photoUrl == null
            ? null
            : 'legacy-${existing.id}';
        final legacyKept = keptLegacyId != null &&
            _items.any((it) =>
                it.existing != null && it.existing!.id == keptLegacyId);
        savedEntry = await _service.updateLog(
          existing.id,
          text,
          photoUrl: legacyKept ? existing.photoUrl : null,
        );

        final keptIds = <String>{
          for (final item in _items)
            if (item.existing != null) item.existing!.id,
        };
        for (final m in existing.media) {
          if (!keptIds.contains(m.id)) {
            try {
              await _service.deleteMedia(m.id);
            } catch (_) {}
          }
        }
      } else {
        savedEntry = await _service.addLog(widget.petId, text);
      }

      final List<LogMedia> finalMedia = [];
      for (var i = 0; i < _items.length; i++) {
        final item = _items[i];
        if (!item.isLocal) {
          finalMedia.add(item.existing!);
          continue;
        }
        final url = item.isVideo
            ? await _service.uploadLogVideo(
                item.localBytes!,
                contentType: item.localMimeType ?? 'video/mp4',
                extension: item.localExtension ?? 'mp4',
              )
            : await _service.uploadLogPhoto(
                item.localBytes!,
                contentType: item.localMimeType ?? 'image/jpeg',
              );
        final inserted = await _service.insertMedia(
          logId: savedEntry.id,
          mediaUrl: url,
          mediaType: item.mediaType,
          position: i,
        );
        finalMedia.add(inserted);
      }

      final result = savedEntry.copyWith(media: finalMedia);
      if (!mounted) return;
      Navigator.pop<LogEntry>(context, result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '기록 수정' : '오늘 기록'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('저장'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_saving || _atMax) ? null : _pickImages,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('📷 사진 추가'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_saving || _atMax) ? null : _pickVideo,
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('🎥 동영상 추가'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_items.length} / $_kMaxMedia',
                style: textTheme.bodySmall?.copyWith(
                  color: _atMax
                      ? colorScheme.error
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (_items.isNotEmpty) ...[
              const SizedBox(height: 4),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return _MediaPreviewTile(
                      item: _items[index],
                      onRemove: _saving ? null : () => _removeAt(index),
                      colorScheme: colorScheme,
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: !_isEdit && _items.isEmpty,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: '오늘 무슨 일이 있었나요?',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaPreviewTile extends StatelessWidget {
  final _MediaItem item;
  final VoidCallback? onRemove;
  final ColorScheme colorScheme;

  const _MediaPreviewTile({
    required this.item,
    required this.onRemove,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _MediaThumb(item: item, colorScheme: colorScheme),
            ),
          ),
          if (item.isVideo)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 36,
                    shadows: [
                      Shadow(color: Colors.black54, blurRadius: 6),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaThumb extends StatelessWidget {
  final _MediaItem item;
  final ColorScheme colorScheme;

  const _MediaThumb({required this.item, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    if (item.isLocal) {
      if (item.isVideo) {
        return _LocalVideoThumb(bytes: item.localBytes!, colorScheme: colorScheme);
      }
      return Image.memory(
        item.localBytes!,
        fit: BoxFit.cover,
        width: 110,
        height: 110,
      );
    }
    final existing = item.existing!;
    if (existing.isVideo) {
      return _NetworkVideoThumb(
        url: existing.mediaUrl,
        colorScheme: colorScheme,
      );
    }
    return Image.network(
      existing.mediaUrl,
      fit: BoxFit.cover,
      width: 110,
      height: 110,
      errorBuilder: (_, _, _) => Container(
        color: colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.broken_image_outlined,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _LocalVideoThumb extends StatelessWidget {
  final Uint8List bytes;
  final ColorScheme colorScheme;
  const _LocalVideoThumb({required this.bytes, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      alignment: Alignment.center,
      child: const Icon(
        Icons.movie_outlined,
        color: Colors.white70,
        size: 36,
      ),
    );
  }
}

class _NetworkVideoThumb extends StatelessWidget {
  final String url;
  final ColorScheme colorScheme;
  const _NetworkVideoThumb({required this.url, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return _VideoFirstFrame(url: url, colorScheme: colorScheme);
  }
}

class _VideoFirstFrame extends StatefulWidget {
  final String url;
  final ColorScheme colorScheme;
  const _VideoFirstFrame({required this.url, required this.colorScheme});

  @override
  State<_VideoFirstFrame> createState() => _VideoFirstFrameState();
}

class _VideoFirstFrameState extends State<_VideoFirstFrame> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _ready = true;
      });
    } catch (_) {
      // Ignore; show fallback.
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _controller == null) {
      return Container(
        color: Colors.black87,
        alignment: Alignment.center,
        child: const Icon(
          Icons.movie_outlined,
          color: Colors.white70,
          size: 36,
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: _controller!.value.size.width,
        height: _controller!.value.size.height,
        child: VideoPlayer(_controller!),
      ),
    );
  }
}
