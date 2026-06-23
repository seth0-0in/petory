import 'package:flutter/material.dart';

import '../models/log_entry.dart';
import '../models/log_media.dart';
import '../services/supabase_service.dart';
import 'media_viewer_screen.dart';

class _GalleryItem {
  final LogEntry log;
  final LogMedia media;
  const _GalleryItem({required this.log, required this.media});
}

class GalleryScreen extends StatefulWidget {
  final String petId;

  const GalleryScreen({super.key, required this.petId});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final SupabaseService _service = SupabaseService();

  List<_GalleryItem> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final logs = await _service.fetchLogs(widget.petId);
      if (!mounted) return;
      final items = <_GalleryItem>[];
      for (final l in logs) {
        for (final m in l.displayMedia) {
          items.add(_GalleryItem(log: l, media: m));
        }
      }
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _open(int index) {
    final allMedia = [for (final it in _items) it.media];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaViewerScreen(
          media: allMedia,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('사진 갤러리')),
      body: _buildBody(colorScheme, textTheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme, TextTheme textTheme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('사진을 불러오지 못했어요.', style: textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('다시 시도')),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '아직 미디어가 없어요.\n기록에 사진이나 동영상을 추가하면 여기 모아져요.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final m = _items[index].media;
        return GestureDetector(
          onTap: () => _open(index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: m.mediaUrl,
                  child: _GalleryThumb(media: m, colorScheme: colorScheme),
                ),
                if (m.isVideo)
                  const IgnorePointer(
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
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GalleryThumb extends StatelessWidget {
  final LogMedia media;
  final ColorScheme colorScheme;
  const _GalleryThumb({required this.media, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    if (media.isVideo) {
      return Container(
        color: Colors.black87,
        alignment: Alignment.center,
        child: const Icon(
          Icons.movie_outlined,
          color: Colors.white54,
          size: 36,
        ),
      );
    }
    return Image.network(
      media.mediaUrl,
      fit: BoxFit.cover,
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
