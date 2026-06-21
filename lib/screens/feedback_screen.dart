import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/supabase_service.dart';

const String kAppVersion = 'v1.0.0';

// 카카오 채널 만들면 이 값만 채우면 버튼이 나타남.
const String kKakaoChannelUrl = '';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const List<String> _categories = [
    '개선 제안',
    '버그 신고',
    '정보 업데이트 요청',
    '기타',
  ];

  final SupabaseService _service = SupabaseService();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  String _category = _categories.first;
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용을 입력해 주세요.')),
      );
      return;
    }

    setState(() => _sending = true);

    final contact = _contactController.text.trim();
    try {
      await _service.submitFeedback(
        category: _category,
        message: message,
        contact: contact.isEmpty ? null : contact,
        appVersion: kAppVersion,
      );
      if (!mounted) return;
      _messageController.clear();
      _contactController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('소중한 의견 감사합니다.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('보내기 실패: $e')),
      );
    }
  }

  Future<void> _openKakao() async {
    final uri = Uri.tryParse(kKakaoChannelUrl);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('링크를 열 수 없어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final showKakao = kKakaoChannelUrl.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('문의 · 피드백')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('카테고리', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: _categories
                  .map(
                    (c) => DropdownMenuItem<String>(value: c, child: Text(c)),
                  )
                  .toList(),
              onChanged: _sending
                  ? null
                  : (v) {
                      if (v == null) return;
                      setState(() => _category = v);
                    },
            ),
            const SizedBox(height: 20),
            Text('내용', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              enabled: !_sending,
              minLines: 6,
              maxLines: 12,
              decoration: const InputDecoration(
                hintText: '어떤 점이 좋았는지, 불편했는지 자유롭게 적어주세요.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              textInputAction: TextInputAction.newline,
            ),
            const SizedBox(height: 20),
            Text('연락처 (선택)', style: textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              '답변을 원하시면 이메일이나 카카오톡 ID를 남겨주세요.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contactController,
              enabled: !_sending,
              decoration: const InputDecoration(
                hintText: '예: name@example.com',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _sending ? null : _submit,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_sending ? '보내는 중...' : '보내기'),
            ),
            if (showKakao) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _sending ? null : _openKakao,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('카카오톡으로 문의하기'),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              '앱 버전 $kAppVersion',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
