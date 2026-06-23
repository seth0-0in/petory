import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/care_tips.dart';
import 'nearby_vet_sheet.dart';

class _SymptomCategory {
  final String icon;
  final String title;
  final List<String> symptoms;

  const _SymptomCategory({
    required this.icon,
    required this.title,
    required this.symptoms,
  });
}

const List<_SymptomCategory> _kDogCategories = [
  _SymptomCategory(
    icon: '🦴',
    title: '관절·움직임',
    symptoms: [
      '계단 오르내리기를 꺼려해요',
      '일어나거나 눕기 힘들어해요',
      '특정 다리를 절뚝거려요',
      '산책 거리가 줄었어요',
    ],
  ),
  _SymptomCategory(
    icon: '🧠',
    title: '인지·행동',
    symptoms: [
      '멍하니 벽을 바라봐요',
      '밤에 이유 없이 짖거나 울어요',
      '집 안에서 길을 잃은 것처럼 헤매요',
      '가족을 못 알아보는 것 같아요',
    ],
  ),
  _SymptomCategory(
    icon: '❤️',
    title: '심장·호흡',
    symptoms: [
      '가벼운 운동에도 숨을 많이 헐떡여요',
      '마른기침을 자주 해요',
      '배가 불러 보여요',
      '잇몸이 창백하거나 파래요',
    ],
  ),
  _SymptomCategory(
    icon: '🍖',
    title: '식욕·소화',
    symptoms: [
      '갑자기 밥을 안 먹어요',
      '물을 지나치게 많이 마셔요',
      '구토나 설사가 잦아요',
      '체중이 눈에 띄게 줄었어요',
    ],
  ),
  _SymptomCategory(
    icon: '👁️',
    title: '눈·귀·피부',
    symptoms: [
      '눈이 뿌옇게 변했어요 (백내장 의심)',
      '귀에서 냄새나 분비물이 나요',
      '피부에 혹이나 덩어리가 만져져요',
      '털이 많이 빠지거나 피부가 건조해요',
    ],
  ),
];

const List<_SymptomCategory> _kCatCategories = [
  _SymptomCategory(
    icon: '🦴',
    title: '움직임·관절',
    symptoms: [
      '높은 곳을 못 올라가요',
      '점프를 꺼려해요',
      '걸음이 뻣뻣해요',
    ],
  ),
  _SymptomCategory(
    icon: '🧠',
    title: '행동 변화',
    symptoms: [
      '숨어 있는 시간이 늘었어요',
      '그루밍이 줄었어요',
      '평소와 다른 울음소리를 내요',
    ],
  ),
  _SymptomCategory(
    icon: '❤️',
    title: '심장·호흡',
    symptoms: [
      '입으로 숨을 쉬어요',
      '호흡이 빠르고 얕아요',
      '운동 후 과도하게 헐떡여요',
    ],
  ),
  _SymptomCategory(
    icon: '🍖',
    title: '식욕·소화',
    symptoms: [
      '갑자기 밥을 안 먹어요',
      '물을 지나치게 많이 마셔요',
      '체중이 급격히 줄었어요',
      '구토가 잦아요',
    ],
  ),
  _SymptomCategory(
    icon: '👁️',
    title: '눈·귀·피부',
    symptoms: [
      '눈 분비물이 늘었어요',
      '귀에서 냄새가 나요',
      '피부에 혹이 만져져요',
      '털 윤기가 줄었어요',
    ],
  ),
];

const List<_SymptomCategory> _kOtherCategories = [
  _SymptomCategory(
    icon: '🏃',
    title: '활동량',
    symptoms: [
      '움직임이 눈에 띄게 줄었어요',
      '쳇바퀴를 안 써요',
    ],
  ),
  _SymptomCategory(
    icon: '🍖',
    title: '식욕·소화',
    symptoms: [
      '밥을 안 먹어요',
      '변이 줄거나 없어요',
      '체중이 줄었어요',
    ],
  ),
  _SymptomCategory(
    icon: '👁️',
    title: '외형 변화',
    symptoms: [
      '털이 빠지거나 윤기가 없어요',
      '눈 분비물이 있어요',
      '피부에 혹이 만져져요',
    ],
  ),
  _SymptomCategory(
    icon: '😰',
    title: '통증 신호',
    symptoms: [
      '만지면 피해요',
      '이를 갈아요',
      '구석에만 있어요',
    ],
  ),
];

List<_SymptomCategory> _categoriesForSpecies(String species) {
  final key = speciesKeyFromKorean(species);
  switch (key) {
    case 'dog':
      return _kDogCategories;
    case 'cat':
      return _kCatCategories;
    case 'other':
    default:
      return _kOtherCategories;
  }
}

enum _SeverityLevel { ok, watch, consult, urgent }

class _SeverityResult {
  final _SeverityLevel level;
  final String message;
  final String emoji;

  const _SeverityResult({
    required this.level,
    required this.message,
    required this.emoji,
  });
}

_SeverityResult _resultFor(int count) {
  if (count == 0) {
    return const _SeverityResult(
      level: _SeverityLevel.ok,
      emoji: '🎉',
      message: '이상 신호가 없네요! 오늘도 건강한 하루 보내세요',
    );
  }
  if (count <= 2) {
    return const _SeverityResult(
      level: _SeverityLevel.watch,
      emoji: '🔍',
      message: '주의 깊게 관찰해주세요. 증상이 지속되면 수의사와 상담하세요',
    );
  }
  if (count <= 4) {
    return const _SeverityResult(
      level: _SeverityLevel.consult,
      emoji: '⚠️',
      message: '수의사 상담을 권장해요. 가까운 시일 내에 검진받아보세요',
    );
  }
  return const _SeverityResult(
    level: _SeverityLevel.urgent,
    emoji: '🚨',
    message: '빠른 수의사 상담이 필요해요. 지금 바로 병원에 연락해보세요',
  );
}

class SeniorSymptomCheckScreen extends StatefulWidget {
  final String petName;
  final String petSpecies;

  const SeniorSymptomCheckScreen({
    super.key,
    required this.petName,
    required this.petSpecies,
  });

  @override
  State<SeniorSymptomCheckScreen> createState() =>
      _SeniorSymptomCheckScreenState();
}

class _SeniorSymptomCheckScreenState extends State<SeniorSymptomCheckScreen> {
  final Set<String> _checked = <String>{};

  int get _checkCount => _checked.length;

  List<_SymptomCategory> get _categories =>
      _categoriesForSpecies(widget.petSpecies);

  void _toggle(String symptom, bool selected) {
    setState(() {
      if (selected) {
        _checked.add(symptom);
      } else {
        _checked.remove(symptom);
      }
    });
  }

  void _reset() {
    if (_checked.isEmpty) return;
    setState(() {
      _checked.clear();
    });
  }

  Future<void> _share() async {
    final result = _resultFor(_checkCount);
    final buffer = StringBuffer();
    buffer.writeln('🐾 ${widget.petName} 시니어 증상 체크');
    buffer.writeln('');
    if (_checked.isEmpty) {
      buffer.writeln('체크된 증상이 없어요.');
    } else {
      for (final category in _categories) {
        final picked =
            category.symptoms.where(_checked.contains).toList();
        if (picked.isEmpty) continue;
        buffer.writeln('${category.icon} ${category.title}');
        for (final s in picked) {
          buffer.writeln('• $s');
        }
        buffer.writeln('');
      }
    }
    buffer.writeln('${result.emoji} ${result.message}');
    buffer.writeln('');
    buffer.writeln('※ 이 체크리스트는 의학적 진단이 아니에요. 정확한 진단은 수의사와 상담하세요.');

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: buffer.toString(),
          subject: '${widget.petName} 증상 체크 결과',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유에 실패했어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final result = _resultFor(_checkCount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('증상 체크'),
        actions: [
          IconButton(
            tooltip: '초기화',
            icon: const Icon(Icons.refresh),
            onPressed: _checked.isEmpty ? null : _reset,
          ),
          IconButton(
            tooltip: '결과 공유',
            icon: const Icon(Icons.ios_share),
            onPressed: _share,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  _DisclaimerBanner(
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${widget.petName}의 상태에 해당하는 항목을 체크해 주세요',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final category in _categories) ...[
                    _CategoryCard(
                      category: category,
                      checkedSymptoms: _checked,
                      onChanged: _toggle,
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            _ResultBar(
              result: result,
              count: _checkCount,
              colorScheme: colorScheme,
              textTheme: textTheme,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '이 체크리스트는 의학적 진단이 아니에요. 정확한 진단은 수의사와 상담하세요.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final _SymptomCategory category;
  final Set<String> checkedSymptoms;
  final void Function(String symptom, bool selected) onChanged;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _CategoryCard({
    required this.category,
    required this.checkedSymptoms,
    required this.onChanged,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final picked =
        category.symptoms.where(checkedSymptoms.contains).length;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(
              children: [
                Text(
                  category.icon,
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 8),
                Text(
                  category.title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (picked > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$picked',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (final symptom in category.symptoms)
            CheckboxListTile(
              value: checkedSymptoms.contains(symptom),
              onChanged: (v) => onChanged(symptom, v ?? false),
              title: Text(symptom),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),
        ],
      ),
    );
  }
}

class _ResultBar extends StatelessWidget {
  final _SeverityResult result;
  final int count;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onFindVet;

  const _ResultBar({
    required this.result,
    required this.count,
    required this.colorScheme,
    required this.textTheme,
    required this.onFindVet,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    switch (result.level) {
      case _SeverityLevel.ok:
        bg = colorScheme.secondaryContainer;
        fg = colorScheme.onSecondaryContainer;
      case _SeverityLevel.watch:
        bg = colorScheme.primaryContainer;
        fg = colorScheme.onPrimaryContainer;
      case _SeverityLevel.consult:
        bg = colorScheme.tertiaryContainer;
        fg = colorScheme.onTertiaryContainer;
      case _SeverityLevel.urgent:
        bg = colorScheme.errorContainer;
        fg = colorScheme.onErrorContainer;
    }

    final showVet = result.level == _SeverityLevel.urgent;

    return Material(
      color: bg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '체크 $count개',
                          style: textTheme.labelMedium?.copyWith(
                            color: fg.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          result.message,
                          style: textTheme.bodyMedium?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (showVet) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: onFindVet,
                  icon: const Icon(Icons.local_hospital_outlined),
                  label: const Text('가까운 동물병원 찾기'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
