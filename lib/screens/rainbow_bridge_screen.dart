import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/pet.dart';
import '../services/supabase_service.dart';
import 'nearby_funeral_sheet.dart';

class RainbowBridgeScreen extends StatefulWidget {
  const RainbowBridgeScreen({super.key});

  @override
  State<RainbowBridgeScreen> createState() => _RainbowBridgeScreenState();
}

class _RainbowBridgeScreenState extends State<RainbowBridgeScreen> {
  final SupabaseService _service = SupabaseService();
  List<Pet> _memorialPets = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await _service.fetchPets();
      if (!mounted) return;
      setState(() {
        _memorialPets = all.where((p) => p.isRainbowBridge).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _memorialPets = const [];
        _loading = false;
      });
    }
  }

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      await launchUrl(uri);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$number 전화 연결에 실패했어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark
        ? const Color(0xFF1B1428)
        : const Color(0xFFF5F0FA);
    final cardBg = isDark
        ? Colors.deepPurple.shade900.withValues(alpha: 0.35)
        : Colors.white;
    final accent = isDark
        ? Colors.deepPurple.shade200
        : Colors.deepPurple.shade400;
    final softText = isDark
        ? Colors.deepPurple.shade100
        : Colors.deepPurple.shade900;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('🌈 무지개다리 정보'),
        foregroundColor: softText,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _IntroBanner(
              cardBg: cardBg,
              accent: accent,
              softText: softText,
            ),
            const SizedBox(height: 18),
            _SectionTitle(
              icon: '💜',
              title: '펫로스 증후군이란?',
              softText: softText,
            ),
            const SizedBox(height: 10),
            _BulletCard(
              cardBg: cardBg,
              accent: accent,
              items: const [
                '반려동물을 잃은 후 느끼는 깊은 슬픔은 자연스러운 감정이에요.',
                '슬픔, 죄책감, 분노, 우울감은 모두 정상적인 반응이에요.',
                '충분히 슬퍼하는 것이 회복의 첫걸음이에요.',
                '주변의 이해가 부족해도 당신의 슬픔은 진짜예요.',
              ],
            ),
            const SizedBox(height: 22),
            _SectionTitle(
              icon: '🏥',
              title: '장례 절차 안내',
              softText: softText,
            ),
            const SizedBox(height: 10),
            _FuneralAccordion(cardBg: cardBg, accent: accent),
            const SizedBox(height: 22),
            _SectionTitle(
              icon: '🔍',
              title: '장례식장 찾기',
              softText: softText,
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '지도 앱에서 가까운 반려동물 장례식장을 검색해드려요.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: softText,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => showNearbyFuneralSheet(context),
                      icon: const Icon(Icons.search),
                      label: const Text(
                        '근처 반려동물 장례식장 찾기',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            _SectionTitle(
              icon: '💙',
              title: '마음 돌보기',
              softText: softText,
            ),
            const SizedBox(height: 10),
            _BulletCard(
              cardBg: cardBg,
              accent: accent,
              items: const [
                '슬픔을 일기로 기록해보세요 (Petory 일기 기능 활용)',
                '반려동물과의 추억 사진을 정리해보세요',
                '펫로스 커뮤니티나 상담을 이용해보세요',
                '충분한 시간을 두고 천천히 회복하세요',
                '새 반려동물 입양은 충분히 슬퍼한 후 결정하세요',
              ],
            ),
            const SizedBox(height: 22),
            _SectionTitle(
              icon: '📞',
              title: '도움받을 수 있는 곳',
              softText: softText,
            ),
            const SizedBox(height: 10),
            _HelpCard(
              cardBg: cardBg,
              accent: accent,
              softText: softText,
              entries: [
                _HelpEntry(
                  title: '한국펫로스협회',
                  description: '펫로스 상담 제공',
                  phone: null,
                ),
                _HelpEntry(
                  title: '정신건강 위기상담 전화',
                  description: '24시간 운영',
                  phone: '1577-0199',
                ),
                _HelpEntry(
                  title: '생명의전화',
                  description: '심리 상담 · 위기 상담',
                  phone: '1588-9191',
                ),
              ],
              onCall: _call,
            ),
            const SizedBox(height: 28),
            _SectionTitle(
              icon: '🌈',
              title: '하늘나라로 떠난 우리 아이',
              softText: softText,
            ),
            const SizedBox(height: 10),
            _MemorialSection(
              loading: _loading,
              pets: _memorialPets,
              cardBg: cardBg,
              accent: accent,
              softText: softText,
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                '🌈 무지개다리 너머에서 행복하길',
                style: textTheme.bodyMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroBanner extends StatelessWidget {
  final Color cardBg;
  final Color accent;
  final Color softText;

  const _IntroBanner({
    required this.cardBg,
    required this.accent,
    required this.softText,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🌈', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '사랑하는 반려동물을 떠나보내는 일은 너무나 힘든 일이에요. '
              '조금이나마 도움이 되길 바랍니다.',
              style: textTheme.bodyMedium?.copyWith(
                color: softText,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String icon;
  final String title;
  final Color softText;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.softText,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: softText,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletCard extends StatelessWidget {
  final Color cardBg;
  final Color accent;
  final List<String> items;

  const _BulletCard({
    required this.cardBg,
    required this.accent,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.deepPurple.shade50
                            : Colors.deepPurple.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FuneralStep {
  final String title;
  final String body;

  const _FuneralStep({required this.title, required this.body});
}

const List<_FuneralStep> _kFuneralSteps = [
  _FuneralStep(
    title: '1) 임종 직후',
    body: '수의사의 확인을 받으면 사망 증명서 발급이 가능해요. '
        '아이를 깨끗한 천이나 담요로 감싸 따뜻하게 안아 주세요.',
  ),
  _FuneralStep(
    title: '2) 장례 방법 선택',
    body: '화장(개별/합동), 자연장, 수목장 중 선택할 수 있어요. '
        '가족과 충분히 상의해서 결정하세요.',
  ),
  _FuneralStep(
    title: '3) 개별 화장',
    body: '유골을 단독으로 처리하여 유골함을 수령할 수 있어요. '
        '추모 공간을 따로 마련하고 싶을 때 선택해요.',
  ),
  _FuneralStep(
    title: '4) 합동 화장',
    body: '여러 반려동물과 함께 진행해 비용이 비교적 저렴해요. '
        '유골은 따로 받지 않아요.',
  ),
  _FuneralStep(
    title: '5) 자연장 / 수목장',
    body: '지정된 곳에 수목과 함께 안장돼요. '
        '자연으로 돌려보내고 싶을 때 선택해요.',
  ),
  _FuneralStep(
    title: '6) 소요 비용',
    body: '소형견·고양이 약 15~30만 원, 중형견 약 25~50만 원. '
        '업체와 옵션에 따라 다르니 미리 확인하세요.',
  ),
  _FuneralStep(
    title: '7) 준비물',
    body: '반려동물 사진, 평소 좋아하던 물건(장난감, 담요, 사료 등)을 '
        '함께 챙기면 마지막 인사를 정성껏 전할 수 있어요.',
  ),
];

class _FuneralAccordion extends StatelessWidget {
  final Color cardBg;
  final Color accent;

  const _FuneralAccordion({required this.cardBg, required this.accent});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bodyColor =
        isDark ? Colors.deepPurple.shade50 : Colors.deepPurple.shade900;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: accent.withValues(alpha: 0.15),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: Column(
          children: [
            for (var i = 0; i < _kFuneralSteps.length; i++) ...[
              ExpansionTile(
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                iconColor: accent,
                collapsedIconColor: accent,
                title: Text(
                  _kFuneralSteps[i].title,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _kFuneralSteps[i].body,
                      style: textTheme.bodyMedium?.copyWith(
                        height: 1.55,
                        color: bodyColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (i < _kFuneralSteps.length - 1)
                Divider(
                  height: 1,
                  color: accent.withValues(alpha: 0.12),
                  indent: 14,
                  endIndent: 14,
                ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

class _HelpEntry {
  final String title;
  final String description;
  final String? phone;

  const _HelpEntry({
    required this.title,
    required this.description,
    required this.phone,
  });
}

class _HelpCard extends StatelessWidget {
  final Color cardBg;
  final Color accent;
  final Color softText;
  final List<_HelpEntry> entries;
  final Future<void> Function(String number) onCall;

  const _HelpCard({
    required this.cardBg,
    required this.accent,
    required this.softText,
    required this.entries,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: Icon(Icons.support_agent, color: accent),
              title: Text(
                entries[i].title,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: softText,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  entries[i].phone == null
                      ? entries[i].description
                      : '${entries[i].description} · ${entries[i].phone}',
                  style: textTheme.bodySmall?.copyWith(
                    color: softText.withValues(alpha: 0.75),
                  ),
                ),
              ),
              trailing: entries[i].phone == null
                  ? null
                  : OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accent,
                        side: BorderSide(color: accent),
                      ),
                      onPressed: () => onCall(entries[i].phone!),
                      icon: const Icon(Icons.call, size: 16),
                      label: const Text('전화'),
                    ),
            ),
            if (i < entries.length - 1)
              Divider(
                height: 1,
                color: accent.withValues(alpha: 0.12),
                indent: 14,
                endIndent: 14,
              ),
          ],
        ],
      ),
      ),
    );
  }
}

class _MemorialSection extends StatelessWidget {
  final bool loading;
  final List<Pet> pets;
  final Color cardBg;
  final Color accent;
  final Color softText;

  const _MemorialSection({
    required this.loading,
    required this.pets,
    required this.cardBg,
    required this.accent,
    required this.softText,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (loading) {
      return Container(
        height: 90,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: accent,
            ),
          ),
        ),
      );
    }
    if (pets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accent.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.favorite_outline, color: accent, size: 28),
            const SizedBox(height: 8),
            Text(
              '아직 추모 중인 아이가 없어요.',
              style: textTheme.bodyMedium?.copyWith(
                color: softText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '펫 수정 화면에서 "무지개다리" 토글로\n추모 상태로 보존할 수 있어요.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: softText.withValues(alpha: 0.75),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final pet in pets) ...[
          _MemorialPetTile(
            pet: pet,
            cardBg: cardBg,
            accent: accent,
            softText: softText,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MemorialPetTile extends StatelessWidget {
  final Pet pet;
  final Color cardBg;
  final Color accent;
  final Color softText;

  const _MemorialPetTile({
    required this.pet,
    required this.cardBg,
    required this.accent,
    required this.softText,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.33, 0.59, 0.11, 0, 0,
        0.33, 0.59, 0.11, 0, 0,
        0.33, 0.59, 0.11, 0, 0,
        0,    0,    0,    1, 0,
      ]),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accent.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: accent.withValues(alpha: 0.18),
              child: Text(
                pet.name.characters.first,
                style: textTheme.titleMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        pet.name,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: softText,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('🌈', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${pet.species} · 함께한 추억 ${pet.daysSinceAdoption + 1}일',
                    style: textTheme.bodySmall?.copyWith(
                      color: softText.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
