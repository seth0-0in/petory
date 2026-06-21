import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/log_entry.dart';
import '../services/supabase_service.dart';

class AddLogScreen extends StatefulWidget {
  final String petId;
  final LogEntry? existing;

  const AddLogScreen({super.key, required this.petId, this.existing});

  @override
  State<AddLogScreen> createState() => _AddLogScreenState();
}

class _AddLogScreenState extends State<AddLogScreen> {
  final SupabaseService _service = SupabaseService();
  late final TextEditingController _controller;
  final ImagePicker _picker = ImagePicker();

  Uint8List? _photoBytes;
  String? _mimeType;
  String? _existingPhotoUrl;
  bool _photoRemoved = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _controller = TextEditingController(text: existing?.content ?? '');
    _existingPhotoUrl = existing?.photoUrl;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photoBytes = bytes;
      _mimeType = picked.mimeType ?? 'image/jpeg';
      _photoRemoved = false;
    });
  }

  void _removePhoto() {
    setState(() {
      _photoBytes = null;
      _mimeType = null;
      _photoRemoved = true;
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
      final bytes = _photoBytes;

      if (_isEdit) {
        String? photoUrl;
        if (bytes != null) {
          photoUrl = await _service.uploadLogPhoto(
            bytes,
            contentType: _mimeType ?? 'image/jpeg',
          );
        } else if (_photoRemoved) {
          photoUrl = null;
        } else {
          photoUrl = _existingPhotoUrl;
        }

        final updated = await _service.updateLog(
          widget.existing!.id,
          text,
          photoUrl: photoUrl,
        );
        if (!mounted) return;
        Navigator.pop<LogEntry>(context, updated);
      } else {
        String? photoUrl;
        if (bytes != null) {
          photoUrl = await _service.uploadLogPhoto(
            bytes,
            contentType: _mimeType ?? 'image/jpeg',
          );
        }

        final saved = await _service.addLog(
          widget.petId,
          text,
          photoUrl: photoUrl,
        );
        if (!mounted) return;
        Navigator.pop<LogEntry>(context, saved);
      }
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
    final photoBytes = _photoBytes;
    final showingExistingPhoto =
        photoBytes == null && !_photoRemoved && _existingPhotoUrl != null;

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
            if (photoBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: Image.memory(
                    photoBytes,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _saving ? null : _pickPhoto,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('다시 고르기'),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: _saving ? null : _removePhoto,
                    icon: const Icon(Icons.close),
                    label: const Text('사진 제거'),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                  ),
                ],
              ),
            ] else if (showingExistingPhoto) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: Image.network(
                    _existingPhotoUrl!,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _saving ? null : _pickPhoto,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('새로 고르기'),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: _saving ? null : _removePhoto,
                    icon: const Icon(Icons.close),
                    label: const Text('사진 제거'),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                  ),
                ],
              ),
            ] else
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickPhoto,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('사진 첨부'),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: !_isEdit,
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
