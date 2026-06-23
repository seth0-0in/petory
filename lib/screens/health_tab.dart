import 'package:flutter/material.dart';

import '../models/daily_health_log.dart';
import '../models/pet.dart';
import '../models/vet_visit.dart';
import '../services/pet_session.dart';
import '../services/supabase_service.dart';
import 'daily_health_check_screen.dart';
import 'health_screen.dart';
import 'senior_symptom_check_screen.dart';

class HealthTab extends StatefulWidget {
  const HealthTab({super.key});

  @override
  State<HealthTab> createState() => _HealthTabState();
}

class _HealthTabState extends State<HealthTab> {
  final SupabaseService _service = SupabaseService();

  String? _loadedPetId;
  bool _seniorManualOn = false;
  DailyHealthLog? _todayHealthLog;
  List<VetVisit> _vetVisits = const [];

  VoidCallback? _petListener;
  VoidCallback? _revListener;

  @override
  void initState() {
    super.initState();
    _petListener = _onPetChanged;
    _revListener = _onRevChanged;
    PetSession.instance.selectedPet.addListener(_petListener!);
    PetSession.instance.rev.addListener(_revListener!);
    final pet = PetSession.instance.selectedPet.value;
    if (pet != null) {
      _loadSeniorData(pet);
    }
  }

  @override
  void dispose() {
    final pl = _petListener;
    if (pl != null) PetSession.instance.selectedPet.removeListener(pl);
    final rl = _revListener;
    if (rl != null) PetSession.instance.rev.removeListener(rl);
    super.dispose();
  }

  void _onPetChanged() {
    final pet = PetSession.instance.selectedPet.value;
    if (pet == null) {
      setState(() {
        _loadedPetId = null;
        _todayHealthLog = null;
        _vetVisits = const [];
        _seniorManualOn = false;
      });
      return;
    }
    if (pet.id != _loadedPetId) {
      _loadSeniorData(pet);
    } else {
      // 같은 펫인데 객체가 갱신된 경우(예: 무지개다리 토글) — 리빌드만.
      setState(() {});
    }
  }

  void _onRevChanged() {
    final pet = PetSession.instance.selectedPet.value;
    if (pet != null) {
      _loadSeniorData(pet);
    }
  }

  Future<void> _loadSeniorData(Pet pet) async {
    setState(() {
      _loadedPetId = pet.id;
    });
    try {
      final manual = await SeniorModeStore.isManualOn(pet.id);
      final senior = isSeniorEffective(pet, manualOn: manual);
      if (!senior) {
        if (!mounted) return;
        setState(() {
          _seniorManualOn = manual;
          _todayHealthLog = null;
          _vetVisits = const [];
        });
        return;
      }
      final results = await Future.wait([
        _service.fetchTodayHealthLog(pet.id),
        _service.fetchVetVisits(pet.id),
      ]);
      if (!mounted) return;
      if (PetSession.instance.selectedPet.value?.id != pet.id) return;
      setState(() {
        _seniorManualOn = manual;
        _todayHealthLog = results[0] as DailyHealthLog?;
        _vetVisits = results[1] as List<VetVisit>;
      });
    } catch (_) {
      // 무시.
    }
  }

  int? _daysSinceLastVetVisit() {
    if (_vetVisits.isEmpty) return null;
    DateTime? latest;
    for (final v in _vetVisits) {
      if (latest == null || v.visitedAt.isAfter(latest)) latest = v.visitedAt;
    }
    if (latest == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime(latest.year, latest.month, latest.day);
    return today.difference(last).inDays;
  }

  bool _heatTrackingEligible(Pet pet) {
    if (pet.isNeutered) return false;
    if (pet.breed == '햄스터') return false;
    return true;
  }

  void _openDailyHealthCheck(Pet pet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DailyHealthCheckScreen(
          petId: pet.id,
          petName: pet.name,
          existing: _todayHealthLog,
        ),
      ),
    ).then((_) {
      _loadSeniorData(pet);
    });
  }

  void _openSymptomCheck(Pet pet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SeniorSymptomCheckScreen(
          petName: pet.name,
          petSpecies: pet.species,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ValueListenableBuilder<Pet?>(
      valueListenable: PetSession.instance.selectedPet,
      builder: (context, pet, _) {
        if (pet == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('건강 기록')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '홈에서 반려동물을 먼저 선택해 주세요.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }
        final isSenior = isSeniorEffective(pet, manualOn: _seniorManualOn);
        final daysSinceVet = _daysSinceLastVetVisit();
        final showCheckupBanner =
            isSenior && daysSinceVet != null && daysSinceVet >= 180;

        final banner = (!isSenior && !showCheckupBanner)
            ? null
            : _SeniorTopBanner(
                pet: pet,
                logged: _todayHealthLog != null,
                showCheckup: showCheckupBanner,
                daysSinceVet: daysSinceVet,
                colorScheme: colorScheme,
                textTheme: textTheme,
                onOpenDailyCheck: () => _openDailyHealthCheck(pet),
                onOpenSymptomCheck: () => _openSymptomCheck(pet),
              );

        return HealthScreen(
          // 펫 변경 시 HealthScreen 재생성을 위해 key 사용.
          key: ValueKey('health-${pet.id}'),
          petId: pet.id,
          petName: pet.name,
          petSpecies: pet.species,
          showTrendTab: isSenior,
          showHeatTab: _heatTrackingEligible(pet),
          topBanner: banner,
        );
      },
    );
  }
}

class _SeniorTopBanner extends StatelessWidget {
  final Pet pet;
  final bool logged;
  final bool showCheckup;
  final int? daysSinceVet;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onOpenDailyCheck;
  final VoidCallback onOpenSymptomCheck;

  const _SeniorTopBanner({
    required this.pet,
    required this.logged,
    required this.showCheckup,
    required this.daysSinceVet,
    required this.colorScheme,
    required this.textTheme,
    required this.onOpenDailyCheck,
    required this.onOpenSymptomCheck,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onOpenDailyCheck,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Text(logged ? '✅' : '🏥',
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            logged
                                ? '오늘 ${pet.name} 건강체크 완료!'
                                : '오늘 ${pet.name} 건강체크 했나요?',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            logged
                                ? '식욕·활동량·수면 기록을 확인할 수 있어요'
                                : '식욕·활동량·수면을 1분 안에 기록해 보세요',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenSymptomCheck,
                  icon: const Icon(Icons.checklist),
                  label: const Text('증상 체크리스트'),
                ),
              ),
            ],
          ),
          if (showCheckup) ...[
            const SizedBox(height: 8),
            Material(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Text('⚠️', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${pet.name} 정기 검진 시기예요',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            daysSinceVet == null
                                ? '병원 방문 기록이 없어요'
                                : '마지막 병원 방문 후 $daysSinceVet일',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onErrorContainer
                                  .withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
