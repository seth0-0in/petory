import 'package:flutter/material.dart';

import '../data/care_tips.dart';
import '../models/care_tip.dart';
import '../services/supabase_service.dart';

class AllCareTipsScreen extends StatefulWidget {
  const AllCareTipsScreen({super.key});

  @override
  State<AllCareTipsScreen> createState() => _AllCareTipsScreenState();
}

class _AllCareTipsScreenState extends State<AllCareTipsScreen> {
  final SupabaseService _service = SupabaseService();

  bool _loading = true;
  String? _error;
  List<CareTip> _allTips = [];

  String _speciesFilter = 'all';
  String _lifeStageFilter = 'all';

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
      final tips = await _service.fetchAllCareTips();
      if (!mounted) return;
      setState(() {
        _allTips = tips;
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

  List<CareTip> get _filtered {
    return _allTips.where((t) {
      if (_speciesFilter != 'all' && t.species != _speciesFilter) return false;
      if (_lifeStageFilter != 'all') {
        // 특정 생애주기 선택 시: 그 생애주기 OR life_stage가 null인 '품종 맞춤' 팁
        if (t.lifeStage != null && t.lifeStage != _lifeStageFilter) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('전체 케어 팁')),
      body: Column(
        children: [
          _FilterBar(
            speciesFilter: _speciesFilter,
            lifeStageFilter: _lifeStageFilter,
            onSpeciesChanged: (v) => setState(() => _speciesFilter = v),
            onLifeStageChanged: (v) => setState(() => _lifeStageFilter = v),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
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
                      '일반적인 정보이며, 정확한 진단·처방은 수의사와 상담하세요.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '팁을 불러오지 못했어요.',
                            style: textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _load,
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildList(colorScheme, textTheme),
          ),
        ],
      ),
    );
  }

  Widget _buildList(ColorScheme colorScheme, TextTheme textTheme) {
    final tips = _filtered;
    if (tips.isEmpty) {
      return Center(
        child: Text(
          '해당 분류에 등록된 팁이 없어요.',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final breedOnly = tips.where((t) => t.lifeStage == null).toList();
    final stageScoped = tips.where((t) => t.lifeStage != null).toList();

    final items = <_ListItem>[];
    if (breedOnly.isNotEmpty) {
      items.add(_ListItem.section('품종 맞춤 · 전 생애'));
      for (final t in breedOnly) {
        items.add(_ListItem.tip(t));
      }
    }
    if (stageScoped.isNotEmpty) {
      if (breedOnly.isNotEmpty) {
        final label = _lifeStageFilter == 'all'
            ? '생애주기별'
            : '${lifeStageLabel(_lifeStageFilter)} 팁';
        items.add(_ListItem.section(label));
      }
      for (final t in stageScoped) {
        items.add(_ListItem.tip(t));
      }
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.isSection) {
          return Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 0),
            child: Text(
              item.sectionTitle!,
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }
        return _AllTipCard(
          tip: item.tip!,
          colorScheme: colorScheme,
          textTheme: textTheme,
        );
      },
    );
  }
}

class _ListItem {
  final String? sectionTitle;
  final CareTip? tip;
  const _ListItem._({this.sectionTitle, this.tip});
  factory _ListItem.section(String title) => _ListItem._(sectionTitle: title);
  factory _ListItem.tip(CareTip tip) => _ListItem._(tip: tip);
  bool get isSection => sectionTitle != null;
}

class _FilterBar extends StatelessWidget {
  final String speciesFilter;
  final String lifeStageFilter;
  final ValueChanged<String> onSpeciesChanged;
  final ValueChanged<String> onLifeStageChanged;

  const _FilterBar({
    required this.speciesFilter,
    required this.lifeStageFilter,
    required this.onSpeciesChanged,
    required this.onLifeStageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final speciesItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'all', child: Text('전체 종')),
      for (final key in kSpeciesKeys)
        DropdownMenuItem(value: key, child: Text(speciesLabel(key))),
    ];
    final stageItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'all', child: Text('전체 생애')),
      for (final key in kLifeStageKeys)
        DropdownMenuItem(value: key, child: Text(lifeStageLabel(key))),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: speciesFilter,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: speciesItems,
              onChanged: (v) {
                if (v != null) onSpeciesChanged(v);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: lifeStageFilter,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: stageItems,
              onChanged: (v) {
                if (v != null) onLifeStageChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AllTipCard extends StatelessWidget {
  final CareTip tip;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _AllTipCard({
    required this.tip,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final breed = tip.breed;
    final stage = tip.lifeStage;
    final categoryLabel = stage == null
        ? '${speciesLabel(tip.species)} · 전 생애'
        : '${speciesLabel(tip.species)} · ${lifeStageLabel(stage)}';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _CategoryChip(
                  label: categoryLabel,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
                if (breed != null)
                  _CategoryChip(
                    label: breed,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                    highlight: true,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.tips_and_updates_outlined,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tip.title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(tip.body, style: textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool highlight;

  const _CategoryChip({
    required this.label,
    required this.colorScheme,
    required this.textTheme,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = highlight
        ? colorScheme.tertiaryContainer
        : colorScheme.surfaceContainerHighest;
    final fg = highlight
        ? colorScheme.onTertiaryContainer
        : colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }
}
