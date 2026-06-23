import 'package:flutter/material.dart';

import 'nearby_vet_sheet.dart';

class _GuideCategory {
  final String icon;
  final String title;
  final List<String> items;
  final _Severity severity;

  const _GuideCategory({
    required this.icon,
    required this.title,
    required this.items,
    required this.severity,
  });
}

enum _Severity { danger, warning }

const List<_GuideCategory> _kCategories = [
  _GuideCategory(
    icon: '🚨',
    title: '즉시 병원 가야 하는 증상',
    severity: _Severity.danger,
    items: [
      '호흡 곤란 (입으로 숨쉬기, 청색증)',
      '의식 잃음 또는 경련',
      '심한 출혈이 멈추지 않음',
      '독극물 섭취 의심',
      '골절 또는 심한 외상',
      '배가 갑자기 심하게 부풀어 오름',
      '소변을 12시간 이상 못 봄',
      '잇몸이 창백하거나 파란색',
    ],
  ),
  _GuideCategory(
    icon: '🫁',
    title: '호흡 곤란 시 대처',
    severity: _Severity.warning,
    items: [
      '안정된 자세로 눕히기 (옆으로)',
      '목 주변 목줄 등 제거',
      '입안 이물질 확인 (손가락 넣지 않기)',
      '즉시 병원으로 이동',
      '이동 중 따뜻하게 유지',
    ],
  ),
  _GuideCategory(
    icon: '💊',
    title: '독극물 섭취 시 대처',
    severity: _Severity.danger,
    items: [
      '먹은 것을 확인하고 사진 찍기',
      '절대 구토 유발하지 않기',
      '섭취한 물질, 양, 시간을 메모',
      '즉시 병원으로 이동',
      '반려동물에게 위험한 음식: 포도/건포도, 초콜릿, 양파/마늘, 자일리톨, 아보카도, 마카다미아',
    ],
  ),
  _GuideCategory(
    icon: '🩹',
    title: '출혈 시 대처',
    severity: _Severity.warning,
    items: [
      '깨끗한 천으로 압박',
      '5~10분간 지속 압박 (중간에 확인하지 않기)',
      '압박해도 멈추지 않으면 즉시 병원',
      '지혈대는 사용하지 않기',
    ],
  ),
  _GuideCategory(
    icon: '🌡️',
    title: '열사병 시 대처',
    severity: _Severity.warning,
    items: [
      '즉시 시원한 곳으로 이동',
      '미지근한 물로 몸 적시기 (차가운 물 X)',
      '선풍기로 바람 쐬기',
      '물 마시게 하기 (강요 X)',
      '즉시 병원으로 이동',
    ],
  ),
  _GuideCategory(
    icon: '🦴',
    title: '골절 의심 시 대처',
    severity: _Severity.warning,
    items: [
      '최대한 움직이지 않게 하기',
      '부목 대지 않기 (잘못하면 악화)',
      '담요나 수건으로 감싸 고정',
      '즉시 병원으로 이동',
    ],
  ),
  _GuideCategory(
    icon: '😵',
    title: '경련 시 대처',
    severity: _Severity.danger,
    items: [
      '주변 위험한 물건 치우기',
      '절대 입에 손 넣지 않기',
      '조용하고 어둡게 환경 조성',
      '경련 시간 측정 (5분 이상이면 즉시 병원)',
      '경련 후 수의사에게 영상 보여주기',
    ],
  ),
  _GuideCategory(
    icon: '🐾',
    title: '이물질 삼킴 시 대처',
    severity: _Severity.warning,
    items: [
      '삼킨 물건 크기·종류 파악',
      '실, 끈, 날카로운 물체는 즉시 병원',
      '구토 유발 시도하지 않기',
      '증상(구토·식욕부진·무기력) 관찰하며 즉시 병원',
    ],
  ),
];

class EmergencyGuideScreen extends StatelessWidget {
  const EmergencyGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🚨 위급상황 대처 가이드'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _DisclaimerBanner(
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  const SizedBox(height: 16),
                  for (final category in _kCategories) ...[
                    _CategoryTile(
                      category: category,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            _FindVetBar(
              colorScheme: colorScheme,
              onFindVet: () => showNearbyVetSheet(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisclaimerBanner extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _DisclaimerBanner({
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? Colors.red.shade900.withValues(alpha: 0.25)
        : Colors.red.shade50;
    final border = isDark ? Colors.red.shade400 : Colors.red.shade300;
    final iconColor = isDark ? Colors.red.shade200 : Colors.red.shade700;
    final textColor = isDark ? Colors.red.shade100 : Colors.red.shade900;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '이 정보는 응급 상황에서의 일반적인 지침이며, 빠른 수의사 상담이 최우선입니다.',
              style: textTheme.bodyMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final _GuideCategory category;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _CategoryTile({
    required this.category,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDanger = category.severity == _Severity.danger;
    final accent = isDanger
        ? (isDark ? Colors.red.shade300 : Colors.red.shade700)
        : (isDark ? Colors.orange.shade300 : Colors.orange.shade800);
    final tileBg = isDanger
        ? (isDark
            ? Colors.red.shade900.withValues(alpha: 0.18)
            : Colors.red.shade50)
        : (isDark
            ? Colors.orange.shade900.withValues(alpha: 0.18)
            : Colors.orange.shade50);
    final border = isDanger
        ? (isDark ? Colors.red.shade700 : Colors.red.shade200)
        : (isDark ? Colors.orange.shade700 : Colors.orange.shade200);

    return Container(
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: accent,
          collapsedIconColor: accent,
          title: Row(
            children: [
              Text(category.icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  category.title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in category.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
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
                              height: 1.45,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _FindVetBar extends StatelessWidget {
  final ColorScheme colorScheme;
  final VoidCallback onFindVet;

  const _FindVetBar({
    required this.colorScheme,
    required this.onFindVet,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.surface,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onFindVet,
              icon: const Icon(Icons.local_hospital_outlined),
              label: const Text(
                '내 주변 동물병원 찾기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
