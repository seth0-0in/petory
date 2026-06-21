import 'package:flutter/material.dart';

import '../data/care_tips.dart';
import '../models/care_tip.dart';
import '../models/pet.dart';
import '../services/supabase_service.dart';
import 'all_care_tips_screen.dart';

class CareTipsScreen extends StatefulWidget {
  final Pet pet;
  const CareTipsScreen({super.key, required this.pet});

  @override
  State<CareTipsScreen> createState() => _CareTipsScreenState();
}

class _CareTipsScreenState extends State<CareTipsScreen> {
  final SupabaseService _service = SupabaseService();

  bool _loading = true;
  String? _error;
  List<CareTip> _tips = [];
  late final String _speciesKey;
  late final String _lifeStage;

  @override
  void initState() {
    super.initState();
    _speciesKey = speciesKeyFromKorean(widget.pet.species);
    _lifeStage = lifeStageFor(
      speciesKey: _speciesKey,
      birthday: widget.pet.birthday,
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tips = await _service.fetchRelevantCareTips(
        species: _speciesKey,
        lifeStage: _lifeStage,
        breed: widget.pet.breed,
      );
      if (!mounted) return;
      setState(() {
        _tips = tips;
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

  void _openAll() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AllCareTipsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasBirthday = widget.pet.birthday != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('나이·종별 케어 팁'),
        actions: [
          TextButton.icon(
            onPressed: _openAll,
            icon: const Icon(Icons.list_alt),
            label: const Text('전체 보기'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _StageHeader(
              pet: widget.pet,
              lifeStage: _lifeStage,
              hasBirthday: hasBirthday,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            const SizedBox(height: 12),
            _DisclaimerBanner(
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            const SizedBox(height: 16),
            if (!hasBirthday) ...[
              _InfoNote(
                icon: Icons.cake_outlined,
                message: '생일을 등록하면 나이대별 맞춤 팁을 볼 수 있어요.',
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              const SizedBox(height: 12),
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _InfoNote(
                icon: Icons.error_outline,
                message: '팁을 불러오지 못했어요: $_error',
                colorScheme: colorScheme,
                textTheme: textTheme,
              )
            else if (_tips.isEmpty)
              _InfoNote(
                icon: Icons.hourglass_empty,
                message: '준비 중인 정보예요.',
                colorScheme: colorScheme,
                textTheme: textTheme,
              )
            else
              for (final tip in _tips) ...[
                _TipCard(
                  tip: tip,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _openAll,
              icon: const Icon(Icons.list_alt),
              label: const Text('전체 팁 보기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageHeader extends StatelessWidget {
  final Pet pet;
  final String lifeStage;
  final bool hasBirthday;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _StageHeader({
    required this.pet,
    required this.lifeStage,
    required this.hasBirthday,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final breedSuffix = (pet.breed != null && pet.breed!.isNotEmpty)
        ? ' · ${pet.breed}'
        : '';
    final stageText = hasBirthday
        ? '${pet.species}$breedSuffix · ${lifeStageLabel(lifeStage)}'
        : '${pet.species}$breedSuffix · 나이 미등록 (기본 ${lifeStageLabel(lifeStage)} 팁)';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.pets, color: colorScheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet.name,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  stageText,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
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
              '일반적인 정보이며, 정확한 진단·처방은 수의사와 상담하세요.',
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

class _InfoNote extends StatelessWidget {
  final IconData icon;
  final String message;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _InfoNote({
    required this.icon,
    required this.message,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final CareTip tip;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _TipCard({
    required this.tip,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final breed = tip.breed;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                if (breed != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      breed,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
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
