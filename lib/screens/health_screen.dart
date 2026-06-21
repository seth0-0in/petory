import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/medication.dart';
import '../models/vaccination.dart';
import '../models/vet_visit.dart';
import '../models/weight_record.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';

class HealthScreen extends StatefulWidget {
  final String petId;
  final int initialTab;

  const HealthScreen({
    super.key,
    required this.petId,
    this.initialTab = 0,
  });

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseService _service = SupabaseService();

  late final TabController _tabController;

  List<WeightRecord> _records = [];
  bool _weightLoading = true;
  String? _weightError;

  List<Vaccination> _vaccinations = [];
  bool _vaccinationLoading = true;
  String? _vaccinationError;

  List<Medication> _medications = [];
  bool _medicationLoading = true;
  String? _medicationError;

  List<VetVisit> _vetVisits = [];
  bool _vetVisitLoading = true;
  String? _vetVisitError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadWeights();
    _loadVaccinations();
    _loadMedications();
    _loadVetVisits();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWeights() async {
    setState(() {
      _weightLoading = true;
      _weightError = null;
    });
    try {
      final records = await _service.fetchWeights(widget.petId);
      if (!mounted) return;
      setState(() {
        _records = records;
        _weightLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _weightError = e.toString();
        _weightLoading = false;
      });
    }
  }

  Future<void> _loadVaccinations() async {
    setState(() {
      _vaccinationLoading = true;
      _vaccinationError = null;
    });
    try {
      final items = await _service.fetchVaccinations(widget.petId);
      if (!mounted) return;
      setState(() {
        _vaccinations = items;
        _vaccinationLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _vaccinationError = e.toString();
        _vaccinationLoading = false;
      });
    }
  }

  Future<void> _loadMedications() async {
    setState(() {
      _medicationLoading = true;
      _medicationError = null;
    });
    try {
      final items = await _service.fetchMedications(widget.petId);
      if (!mounted) return;
      setState(() {
        _medications = items;
        _medicationLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _medicationError = e.toString();
        _medicationLoading = false;
      });
    }
  }

  Future<void> _loadVetVisits() async {
    setState(() {
      _vetVisitLoading = true;
      _vetVisitError = null;
    });
    try {
      final items = await _service.fetchVetVisits(widget.petId);
      if (!mounted) return;
      setState(() {
        _vetVisits = items;
        _vetVisitLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _vetVisitError = e.toString();
        _vetVisitLoading = false;
      });
    }
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }

  String _formatShortDate(DateTime dt) {
    final local = dt.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$m/$d';
  }

  Future<void> _openAddWeight() async {
    final added = await showModalBottomSheet<WeightRecord>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddWeightSheet(petId: widget.petId, service: _service),
    );
    if (added == null) return;
    if (!mounted) return;
    setState(() {
      final next = [..._records, added]
        ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
      _records = next;
    });
  }

  Future<void> _deleteRecord(WeightRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('체중 기록 삭제'),
        content: Text(
          '${_formatDate(record.measuredAt)}의 ${record.weightKg.toStringAsFixed(1)} kg 기록을 삭제할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteWeight(record.id);
      if (!mounted) return;
      setState(() {
        _records = _records.where((r) => r.id != record.id).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
    }
  }

  Future<void> _openAddVaccination() async {
    final added = await showModalBottomSheet<Vaccination>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) =>
          _VaccinationSheet(petId: widget.petId, service: _service),
    );
    if (added == null) return;
    if (!mounted) return;
    setState(() {
      _vaccinations = [..._vaccinations, added];
    });
    _rescheduleNotifications();
  }

  Future<void> _openEditVaccination(Vaccination existing) async {
    final updated = await showModalBottomSheet<Vaccination>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _VaccinationSheet(
        petId: widget.petId,
        service: _service,
        existing: existing,
      ),
    );
    if (updated == null) return;
    if (!mounted) return;
    setState(() {
      _vaccinations = _vaccinations
          .map((x) => x.id == updated.id ? updated : x)
          .toList();
    });
    _rescheduleNotifications();
  }

  Future<void> _rescheduleNotifications() async {
    final service = NotificationService.instance;
    if (!service.isSupported || !service.enabled) return;
    try {
      final pets = await _service.fetchPets();
      final vacByPet = <String, List<Vaccination>>{};
      final medByPet = <String, List<Medication>>{};
      for (final p in pets) {
        vacByPet[p.id] = await _service.fetchVaccinations(p.id);
        medByPet[p.id] = await _service.fetchMedications(p.id);
      }
      await service.rescheduleAll(
        pets: pets,
        vaccinationsByPetId: vacByPet,
        medicationsByPetId: medByPet,
      );
    } catch (_) {
      // 알림 재예약 실패는 무시.
    }
  }

  Future<void> _deleteVaccination(Vaccination v) async {
    final dateLabel = v.eventDate == null ? '' : '${_formatDate(v.eventDate!)}의 ';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('예방접종 기록 삭제'),
        content: Text('$dateLabel${v.name} 기록을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteVaccination(v.id);
      if (!mounted) return;
      setState(() {
        _vaccinations = _vaccinations.where((x) => x.id != v.id).toList();
      });
      _rescheduleNotifications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('삭제 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tabIndex = _tabController.index;

    final fabLabels = ['체중 추가', '접종 추가', '약 추가', '병원 기록 추가'];
    final fabActions = <VoidCallback>[
      _openAddWeight,
      _openAddVaccination,
      _openAddMedication,
      _openAddVetVisit,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('건강 기록'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: '체중'),
            Tab(text: '예방접종'),
            Tab(text: '투약'),
            Tab(text: '병원 기록'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWeightTab(colorScheme, textTheme),
          _buildVaccinationTab(colorScheme, textTheme),
          _buildMedicationTab(colorScheme, textTheme),
          _buildVetVisitTab(colorScheme, textTheme),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: fabActions[tabIndex],
        icon: const Icon(Icons.add),
        label: Text(fabLabels[tabIndex]),
      ),
    );
  }

  Widget _buildWeightTab(ColorScheme colorScheme, TextTheme textTheme) {
    if (_weightLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_weightError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('데이터를 불러오지 못했어요.', style: textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text(
                _weightError!,
                style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadWeights,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (_records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '아직 체중 기록이 없어요.\n오른쪽 아래 + 버튼으로 첫 기록을 남겨보세요.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final reversed = _records.reversed.toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SizedBox(
            height: 240,
            child: _buildChart(colorScheme, textTheme),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: reversed.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final r = reversed[index];
              return ListTile(
                leading: Icon(
                  Icons.monitor_weight_outlined,
                  color: colorScheme.primary,
                ),
                title: Text('${r.weightKg.toStringAsFixed(1)} kg'),
                subtitle: Text(_formatDate(r.measuredAt)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteRecord(r),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVaccinationTab(ColorScheme colorScheme, TextTheme textTheme) {
    if (_vaccinationLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_vaccinationError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('데이터를 불러오지 못했어요.', style: textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text(
                _vaccinationError!,
                style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadVaccinations,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (_vaccinations.isEmpty) {
      return Column(
        children: [
          _buildNextDueCard(colorScheme, textTheme),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '아직 예방접종 기록이 없어요.\n오른쪽 아래 + 버튼으로 첫 기록을 남겨보세요.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final groups = _buildVaccinationGroups();

    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        _buildNextDueCard(colorScheme, textTheme),
        for (final g in groups)
          _buildVaccinationGroupTile(g, colorScheme, textTheme),
      ],
    );
  }

  List<_VacGroup> _buildVaccinationGroups() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final byName = <String, List<Vaccination>>{};
    for (final v in _vaccinations) {
      byName.putIfAbsent(v.name, () => []).add(v);
    }

    int compareDatesDesc(DateTime? a, DateTime? b) {
      if (a == null && b == null) return 0;
      if (a == null) return 1;
      if (b == null) return -1;
      return b.compareTo(a);
    }

    final groups = <_VacGroup>[];
    for (final entry in byName.entries) {
      final list = [...entry.value]
        ..sort((a, b) => compareDatesDesc(a.eventDate, b.eventDate));

      Vaccination? nearestScheduled;
      for (final v in list) {
        if (!v.isScheduled) continue;
        final due = v.nextDueAt!;
        final dueOnly = DateTime(due.year, due.month, due.day);
        if (dueOnly.isBefore(today)) continue;
        if (nearestScheduled == null ||
            dueOnly.isBefore(
              DateTime(
                nearestScheduled.nextDueAt!.year,
                nearestScheduled.nextDueAt!.month,
                nearestScheduled.nextDueAt!.day,
              ),
            )) {
          nearestScheduled = v;
        }
      }

      DateTime? repDate;
      bool repIsScheduled = false;
      if (nearestScheduled != null) {
        repDate = nearestScheduled.nextDueAt;
        repIsScheduled = true;
      } else {
        for (final v in list) {
          final a = v.administeredAt;
          if (a == null) continue;
          if (repDate == null || a.isAfter(repDate)) repDate = a;
        }
      }

      groups.add(
        _VacGroup(
          name: entry.key,
          items: list,
          repDate: repDate,
          repIsScheduled: repIsScheduled,
        ),
      );
    }

    groups.sort((a, b) => compareDatesDesc(a.repDate, b.repDate));
    return groups;
  }

  Widget _buildVaccinationGroupTile(
    _VacGroup g,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final subtitle = g.repDate == null
        ? '기록 없음'
        : g.repIsScheduled
        ? '예정 · ${_formatDate(g.repDate!)}'
        : '최근 · ${_formatDate(g.repDate!)}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(Icons.vaccines_outlined, color: colorScheme.primary),
        title: Text(g.name),
        subtitle: Text(subtitle),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        children: [
          for (final v in g.items)
            _buildVaccinationRecordTile(v, colorScheme, textTheme),
        ],
      ),
    );
  }

  Widget _buildVaccinationRecordTile(
    Vaccination v,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final dateText = v.eventDate == null
        ? '날짜 없음'
        : _formatDate(v.eventDate!);
    final statusLabel = v.isCompleted ? '완료' : '예정';
    final statusColor = v.isCompleted ? colorScheme.primary : colorScheme.tertiary;
    final hasMemo = v.memo != null && v.memo!.isNotEmpty;

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 56, right: 4),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusLabel,
              style: textTheme.labelSmall?.copyWith(color: statusColor),
            ),
          ),
          const SizedBox(width: 8),
          Text(dateText, style: textTheme.bodyMedium),
        ],
      ),
      subtitle: hasMemo ? Text(v.memo!) : null,
      onTap: () => _openEditVaccination(v),
      trailing: PopupMenuButton<String>(
        tooltip: '더보기',
        icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant),
        onSelected: (value) {
          switch (value) {
            case 'edit':
              _openEditVaccination(v);
              break;
            case 'delete':
              _deleteVaccination(v);
              break;
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('수정')),
          PopupMenuItem(value: 'delete', child: Text('삭제')),
        ],
      ),
    );
  }

  Widget _buildNextDueCard(ColorScheme colorScheme, TextTheme textTheme) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Vaccination? upcoming;
    int? days;
    for (final v in _vaccinations) {
      final next = v.nextDueAt;
      if (next == null) continue;
      final due = DateTime(next.year, next.month, next.day);
      final diff = due.difference(today).inDays;
      if (diff < 0) continue;
      if (upcoming == null || diff < days!) {
        upcoming = v;
        days = diff;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Material(
        color: upcoming == null
            ? colorScheme.surfaceContainerHighest
            : colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: upcoming == null
              ? Row(
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '예정된 접종이 없어요',
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '다음 접종',
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      upcoming.name,
                      style: textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDate(upcoming.nextDueAt!)}  ·  ${days == 0 ? "오늘" : "D-$days"}',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildChart(ColorScheme colorScheme, TextTheme textTheme) {
    final spots = <FlSpot>[
      for (var i = 0; i < _records.length; i++)
        FlSpot(i.toDouble(), _records[i].weightKg),
    ];

    final weights = _records.map((r) => r.weightKg).toList();
    final minW = weights.reduce((a, b) => a < b ? a : b);
    final maxW = weights.reduce((a, b) => a > b ? a : b);
    final pad = (maxW - minW).abs() < 0.01 ? 1.0 : (maxW - minW) * 0.2;
    final minY = (minW - pad).clamp(0, double.infinity).toDouble();
    final maxY = maxW + pad;

    final maxX = _records.length == 1 ? 1.0 : (_records.length - 1).toDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(1),
                style: textTheme.bodySmall,
              ),
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= _records.length) {
                  return const SizedBox.shrink();
                }
                if (value != i.toDouble()) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _formatShortDate(_records[i].measuredAt),
                    style: textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: colorScheme.primary,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(
                    radius: 4,
                    color: colorScheme.primary,
                    strokeWidth: 2,
                    strokeColor: colorScheme.surface,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: colorScheme.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddMedication() async {
    final added = await showModalBottomSheet<Medication>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _MedicationSheet(petId: widget.petId, service: _service),
    );
    if (added == null) return;
    if (!mounted) return;
    setState(() {
      _medications = [added, ..._medications];
    });
    _rescheduleNotifications();
  }

  Future<void> _openEditMedication(Medication existing) async {
    final updated = await showModalBottomSheet<Medication>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _MedicationSheet(
        petId: widget.petId,
        service: _service,
        existing: existing,
      ),
    );
    if (updated == null) return;
    if (!mounted) return;
    setState(() {
      _medications = _medications
          .map((x) => x.id == updated.id ? updated : x)
          .toList();
    });
    _rescheduleNotifications();
  }

  Future<void> _deleteMedication(Medication m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('투약 기록 삭제'),
        content: Text('${m.name} 기록을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteMedication(m.id);
      if (!mounted) return;
      setState(() {
        _medications = _medications.where((x) => x.id != m.id).toList();
      });
      _rescheduleNotifications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    }
  }

  Widget _buildMedicationTab(ColorScheme colorScheme, TextTheme textTheme) {
    if (_medicationLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_medicationError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('데이터를 불러오지 못했어요.', style: textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text(
                _medicationError!,
                style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadMedications,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (_medications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '아직 투약 기록이 없어요.\n오른쪽 아래 + 버튼으로 첫 기록을 남겨보세요.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final active = <Medication>[];
    final finished = <Medication>[];
    for (final m in _medications) {
      if (m.isActiveOn(today)) {
        active.add(m);
      } else {
        finished.add(m);
      }
    }

    int byStartDesc(Medication a, Medication b) {
      final ad = a.startDate;
      final bd = b.startDate;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    }

    active.sort(byStartDesc);
    finished.sort(byStartDesc);

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 88),
      children: [
        if (active.isNotEmpty) ...[
          _buildSectionHeader('복용 중', active.length, colorScheme, textTheme),
          for (final m in active)
            _buildMedicationCard(m, colorScheme, textTheme, isActive: true),
        ],
        if (finished.isNotEmpty) ...[
          _buildSectionHeader('종료', finished.length, colorScheme, textTheme),
          for (final m in finished)
            _buildMedicationCard(m, colorScheme, textTheme, isActive: false),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(
    String title,
    int count,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Row(
        children: [
          Text(
            title,
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(
    Medication m,
    ColorScheme colorScheme,
    TextTheme textTheme, {
    required bool isActive,
  }) {
    final badgeColor = m.kind == MedicationKind.supplement
        ? colorScheme.tertiary
        : colorScheme.primary;

    final infoChips = <Widget>[];
    if (m.dosage != null && m.dosage!.isNotEmpty) {
      infoChips.add(_infoPill(Icons.medication_outlined, m.dosage!, colorScheme, textTheme));
    }
    if (m.frequency != null && m.frequency!.isNotEmpty) {
      infoChips.add(_infoPill(Icons.repeat, m.frequency!, colorScheme, textTheme));
    }

    String periodText;
    if (m.startDate == null && m.endDate == null) {
      periodText = '기간 미지정';
    } else {
      final s = m.startDate == null ? '?' : _formatDate(m.startDate!);
      final e = m.endDate == null ? '계속' : _formatDate(m.endDate!);
      periodText = '$s ~ $e';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openEditMedication(m),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                m.kind == MedicationKind.supplement
                    ? Icons.local_pharmacy_outlined
                    : Icons.medication_outlined,
                color: isActive ? badgeColor : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            m.name,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            m.kind.label,
                            style: textTheme.labelSmall?.copyWith(
                              color: badgeColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (infoChips.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: infoChips),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      periodText,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (m.reminderEnabled && m.times.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.notifications_active_outlined,
                            size: 14,
                            color: badgeColor,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _medicationReminderSummary(m),
                              style: textTheme.bodySmall?.copyWith(
                                color: badgeColor,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (m.memo != null && m.memo!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        m.memo!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '더보기',
                icon: Icon(
                  Icons.more_vert,
                  color: colorScheme.onSurfaceVariant,
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _openEditMedication(m);
                      break;
                    case 'delete':
                      _deleteMedication(m);
                      break;
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('수정')),
                  PopupMenuItem(value: 'delete', child: Text('삭제')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoPill(
    IconData icon,
    String label,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddVetVisit() async {
    final added = await showModalBottomSheet<VetVisit>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _VetVisitSheet(petId: widget.petId, service: _service),
    );
    if (added == null) return;
    if (!mounted) return;
    setState(() {
      final next = [..._vetVisits, added]
        ..sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
      _vetVisits = next;
    });
  }

  Future<void> _openEditVetVisit(VetVisit existing) async {
    final updated = await showModalBottomSheet<VetVisit>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _VetVisitSheet(
        petId: widget.petId,
        service: _service,
        existing: existing,
      ),
    );
    if (updated == null) return;
    if (!mounted) return;
    setState(() {
      final next = _vetVisits
          .map((x) => x.id == updated.id ? updated : x)
          .toList()
        ..sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
      _vetVisits = next;
    });
  }

  Future<void> _deleteVetVisit(VetVisit v) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('병원 기록 삭제'),
        content: Text('${_formatDate(v.visitedAt)} 기록을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteVetVisit(v.id);
      if (!mounted) return;
      setState(() {
        _vetVisits = _vetVisits.where((x) => x.id != v.id).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    }
  }

  Widget _buildVetVisitTab(ColorScheme colorScheme, TextTheme textTheme) {
    if (_vetVisitLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_vetVisitError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('데이터를 불러오지 못했어요.', style: textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text(
                _vetVisitError!,
                style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadVetVisits,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (_vetVisits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '아직 병원 기록이 없어요.\n오른쪽 아래 + 버튼으로 첫 기록을 남겨보세요.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 88),
      itemCount: _vetVisits.length,
      itemBuilder: (context, index) {
        final v = _vetVisits[index];
        return _buildVetVisitCard(v, colorScheme, textTheme);
      },
    );
  }

  Widget _buildVetVisitCard(
    VetVisit v,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final detailLines = <Widget>[];
    if (v.reason != null && v.reason!.isNotEmpty) {
      detailLines.add(
        _vetDetailRow(Icons.notes_outlined, v.reason!, colorScheme, textTheme),
      );
    }
    if (v.diagnosis != null && v.diagnosis!.isNotEmpty) {
      detailLines.add(
        _vetDetailRow(
          Icons.medical_information_outlined,
          v.diagnosis!,
          colorScheme,
          textTheme,
        ),
      );
    }
    if (v.treatment != null && v.treatment!.isNotEmpty) {
      detailLines.add(
        _vetDetailRow(
          Icons.healing_outlined,
          v.treatment!,
          colorScheme,
          textTheme,
        ),
      );
    }
    if (v.memo != null && v.memo!.isNotEmpty) {
      detailLines.add(
        _vetDetailRow(
          Icons.sticky_note_2_outlined,
          v.memo!,
          colorScheme,
          textTheme,
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openEditVetVisit(v),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.local_hospital_outlined, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _formatDate(v.visitedAt),
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (v.cost != null) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _formatCost(v.cost!),
                              style: textTheme.labelMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (v.hospital != null && v.hospital!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        v.hospital!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (detailLines.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...detailLines,
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '더보기',
                icon: Icon(
                  Icons.more_vert,
                  color: colorScheme.onSurfaceVariant,
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _openEditVetVisit(v);
                      break;
                    case 'delete':
                      _deleteVetVisit(v);
                      break;
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('수정')),
                  PopupMenuItem(value: 'delete', child: Text('삭제')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vetDetailRow(
    IconData icon,
    String text,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _medicationReminderSummary(Medication m) {
    const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    String dayLabel;
    if (m.weekdays.isEmpty) {
      dayLabel = '매일';
    } else {
      final sorted = [...m.weekdays]..sort();
      final labels = sorted
          .where((w) => w >= 1 && w <= 7)
          .map((w) => weekdayLabels[w - 1])
          .toList();
      dayLabel = labels.isEmpty ? '매일' : '매주 ${labels.join('·')}';
    }
    final sortedTimes = [...m.times]..sort();
    return '$dayLabel ${sortedTimes.join('·')}';
  }

  String _formatCost(int won) {
    final neg = won < 0;
    final s = (neg ? -won : won).toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${neg ? '-' : ''}${buf.toString()}원';
  }
}

class _AddWeightSheet extends StatefulWidget {
  final String petId;
  final SupabaseService service;

  const _AddWeightSheet({required this.petId, required this.service});

  @override
  State<_AddWeightSheet> createState() => _AddWeightSheetState();
}

class _AddWeightSheetState extends State<_AddWeightSheet> {
  final TextEditingController _controller = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
    });
  }

  Future<void> _save() async {
    final text = _controller.text.trim().replaceAll(',', '.');
    final value = double.tryParse(text);
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 체중(kg)을 입력해 주세요.')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });
    try {
      final saved = await widget.service.addWeight(widget.petId, value, _date);
      if (!mounted) return;
      Navigator.pop<WeightRecord>(context, saved);
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('체중 추가', style: textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '체중 (kg)',
              border: OutlineInputBorder(),
              hintText: '예: 4.2',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _saving ? null : _pickDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text('측정일: ${_formatDate(_date)}'),
          ),
          const SizedBox(height: 16),
          FilledButton(
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
    );
  }
}

class _VacGroup {
  final String name;
  final List<Vaccination> items;
  final DateTime? repDate;
  final bool repIsScheduled;

  const _VacGroup({
    required this.name,
    required this.items,
    required this.repDate,
    required this.repIsScheduled,
  });
}

class _VaccinationSheet extends StatefulWidget {
  final String petId;
  final SupabaseService service;
  final Vaccination? existing;

  const _VaccinationSheet({
    required this.petId,
    required this.service,
    this.existing,
  });

  @override
  State<_VaccinationSheet> createState() => _VaccinationSheetState();
}

class _VaccinationSheetState extends State<_VaccinationSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _memoController;
  late DateTime _date;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _memoController = TextEditingController(text: existing?.memo ?? '');
    _date =
        existing?.administeredAt ?? existing?.nextDueAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('백신 이름을 입력해 주세요.')),
      );
      return;
    }

    final memoText = _memoController.text.trim();
    final memo = memoText.isEmpty ? null : memoText;

    setState(() {
      _saving = true;
    });
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dateOnly = DateTime(_date.year, _date.month, _date.day);
      final isFuture = dateOnly.isAfter(today);
      final administered = isFuture ? null : _date;
      final nextDue = isFuture ? _date : null;

      final Vaccination result;
      if (_isEdit) {
        await widget.service.updateVaccination(
          widget.existing!.id,
          name: name,
          administeredAt: administered,
          nextDueAt: nextDue,
          memo: memo,
        );
        result = Vaccination(
          id: widget.existing!.id,
          name: name,
          administeredAt: administered,
          nextDueAt: nextDue,
          memo: memo,
        );
      } else {
        result = await widget.service.addVaccination(
          widget.petId,
          name: name,
          date: _date,
          memo: memo,
        );
      }
      if (!mounted) return;
      Navigator.pop<Vaccination>(context, result);
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(_date.year, _date.month, _date.day);
    final isFuture = dateOnly.isAfter(today);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEdit ? '예방접종 수정' : '예방접종 추가',
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: !_isEdit,
            decoration: const InputDecoration(
              labelText: '백신 이름',
              border: OutlineInputBorder(),
              hintText: '예: 종합백신 DHPPL',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _saving ? null : _pickDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text('날짜: ${_formatDate(_date)}'),
          ),
          const SizedBox(height: 6),
          Text(
            isFuture ? '미래 날짜 → 예정 기록으로 저장돼요' : '오늘/과거 날짜 → 완료 기록으로 저장돼요',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _memoController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '메모 (선택)',
              border: OutlineInputBorder(),
              hintText: '예: 동물병원 OOO에서 접종',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
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
    );
  }
}

class _MedicationSheet extends StatefulWidget {
  final String petId;
  final SupabaseService service;
  final Medication? existing;

  const _MedicationSheet({
    required this.petId,
    required this.service,
    this.existing,
  });

  @override
  State<_MedicationSheet> createState() => _MedicationSheetState();
}

enum _ReminderRecurrence { daily, weekly }

class _MedicationSheetState extends State<_MedicationSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _dosageController;
  late final TextEditingController _frequencyController;
  late final TextEditingController _memoController;

  late MedicationKind _kind;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;

  bool _reminderEnabled = false;
  _ReminderRecurrence _recurrence = _ReminderRecurrence.daily;
  final Set<int> _selectedWeekdays = <int>{};
  final List<TimeOfDay> _times = <TimeOfDay>[];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _dosageController = TextEditingController(text: e?.dosage ?? '');
    _frequencyController = TextEditingController(text: e?.frequency ?? '');
    _memoController = TextEditingController(text: e?.memo ?? '');
    _kind = e?.kind ?? MedicationKind.medication;
    _startDate = e?.startDate;
    _endDate = e?.endDate;

    if (e != null) {
      _reminderEnabled = e.reminderEnabled;
      _recurrence = e.weekdays.isEmpty
          ? _ReminderRecurrence.daily
          : _ReminderRecurrence.weekly;
      for (final w in e.weekdays) {
        if (w >= 1 && w <= 7) _selectedWeekdays.add(w);
      }
      for (final raw in e.times) {
        final parts = raw.split(':');
        if (parts.length != 2) continue;
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h == null || m == null) continue;
        if (h < 0 || h > 23 || m < 0 || m > 59) continue;
        _times.add(TimeOfDay(hour: h, minute: m));
      }
      _sortTimes();
    }
  }

  void _sortTimes() {
    _times.sort((a, b) {
      final am = a.hour * 60 + a.minute;
      final bm = b.hour * 60 + b.minute;
      return am.compareTo(bm);
    });
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null) return;
    final exists = _times.any(
      (t) => t.hour == picked.hour && t.minute == picked.minute,
    );
    setState(() {
      if (!exists) {
        _times.add(picked);
        _sortTimes();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
    });
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() {
      _endDate = picked;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('약/영양제 이름을 입력해 주세요.')),
      );
      return;
    }
    if (_startDate != null &&
        _endDate != null &&
        _endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('종료일은 시작일 이후로 설정해 주세요.')),
      );
      return;
    }

    if (_reminderEnabled) {
      if (_times.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림을 받을 복용 시각을 1개 이상 추가해 주세요.')),
        );
        return;
      }
      if (_recurrence == _ReminderRecurrence.weekly &&
          _selectedWeekdays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림을 받을 요일을 선택해 주세요.')),
        );
        return;
      }
    }

    final dosage = _dosageController.text.trim();
    final frequency = _frequencyController.text.trim();
    final memo = _memoController.text.trim();

    final timesPayload = _reminderEnabled
        ? _times.map(_formatTimeOfDay).toList()
        : const <String>[];
    final weekdaysPayload = _reminderEnabled &&
            _recurrence == _ReminderRecurrence.weekly
        ? (_selectedWeekdays.toList()..sort())
        : const <int>[];

    setState(() {
      _saving = true;
    });

    try {
      final Medication result;
      if (_isEdit) {
        result = await widget.service.updateMedication(
          widget.existing!.id,
          name: name,
          kind: _kind,
          dosage: dosage,
          frequency: frequency,
          startDate: _startDate,
          endDate: _endDate,
          memo: memo,
          reminderEnabled: _reminderEnabled,
          times: timesPayload,
          weekdays: weekdaysPayload,
        );
      } else {
        result = await widget.service.addMedication(
          widget.petId,
          name: name,
          kind: _kind,
          dosage: dosage,
          frequency: frequency,
          startDate: _startDate,
          endDate: _endDate,
          memo: memo,
          reminderEnabled: _reminderEnabled,
          times: timesPayload,
          weekdays: weekdaysPayload,
        );
      }
      if (!mounted) return;
      Navigator.pop<Medication>(context, result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? '투약 수정' : '투약 추가',
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: !_isEdit,
              decoration: const InputDecoration(
                labelText: '이름',
                border: OutlineInputBorder(),
                hintText: '예: 심장사상충약',
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<MedicationKind>(
              segments: const [
                ButtonSegment(
                  value: MedicationKind.medication,
                  label: Text('약'),
                  icon: Icon(Icons.medication_outlined),
                ),
                ButtonSegment(
                  value: MedicationKind.supplement,
                  label: Text('영양제'),
                  icon: Icon(Icons.local_pharmacy_outlined),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) {
                setState(() {
                  _kind = s.first;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dosageController,
              decoration: const InputDecoration(
                labelText: '용량 (선택)',
                border: OutlineInputBorder(),
                hintText: '예: 1정, 5ml',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _frequencyController,
              decoration: const InputDecoration(
                labelText: '횟수 (선택)',
                border: OutlineInputBorder(),
                hintText: '예: 하루 2회',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickStart,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      _startDate == null ? '시작일' : _formatDate(_startDate!),
                    ),
                  ),
                ),
                if (_startDate != null)
                  IconButton(
                    tooltip: '시작일 지우기',
                    icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                    onPressed: () => setState(() => _startDate = null),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickEnd,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _endDate == null
                          ? '종료일 (비우면 복용 중)'
                          : _formatDate(_endDate!),
                    ),
                  ),
                ),
                if (_endDate != null)
                  IconButton(
                    tooltip: '종료일 지우기',
                    icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                    onPressed: () => setState(() => _endDate = null),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _memoController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
                border: OutlineInputBorder(),
                hintText: '예: 식후 30분에 복용',
              ),
            ),
            const SizedBox(height: 16),
            _buildReminderSection(colorScheme, textTheme),
            const SizedBox(height: 16),
            FilledButton(
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
      ),
    );
  }

  Widget _buildReminderSection(ColorScheme colorScheme, TextTheme textTheme) {
    const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(
              Icons.notifications_active_outlined,
              color: colorScheme.primary,
            ),
            title: const Text('복용 알림 받기'),
            subtitle: const Text('정해진 시각에 알림으로 알려드릴게요'),
            value: _reminderEnabled,
            onChanged: _saving
                ? null
                : (v) {
                    setState(() {
                      _reminderEnabled = v;
                    });
                  },
          ),
          if (_reminderEnabled) ...[
            const SizedBox(height: 4),
            Text(
              '빈도',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            SegmentedButton<_ReminderRecurrence>(
              segments: const [
                ButtonSegment(
                  value: _ReminderRecurrence.daily,
                  label: Text('매일'),
                  icon: Icon(Icons.today_outlined),
                ),
                ButtonSegment(
                  value: _ReminderRecurrence.weekly,
                  label: Text('매주'),
                  icon: Icon(Icons.event_repeat_outlined),
                ),
              ],
              selected: {_recurrence},
              onSelectionChanged: (s) {
                setState(() {
                  _recurrence = s.first;
                });
              },
            ),
            if (_recurrence == _ReminderRecurrence.weekly) ...[
              const SizedBox(height: 12),
              Text(
                '요일',
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 1; i <= 7; i++)
                    FilterChip(
                      label: Text(weekdayLabels[i - 1]),
                      selected: _selectedWeekdays.contains(i),
                      onSelected: (sel) {
                        setState(() {
                          if (sel) {
                            _selectedWeekdays.add(i);
                          } else {
                            _selectedWeekdays.remove(i);
                          }
                        });
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '복용 시각',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _saving ? null : _addTime,
                  icon: const Icon(Icons.add),
                  label: const Text('시간 추가'),
                ),
              ],
            ),
            if (_times.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(
                  '시간 추가 버튼을 눌러 복용 시각을 정해주세요',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in _times)
                    InputChip(
                      avatar: Icon(
                        Icons.access_time,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      label: Text(_formatTimeOfDay(t)),
                      onDeleted: _saving
                          ? null
                          : () {
                              setState(() {
                                _times.remove(t);
                              });
                            },
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _VetVisitSheet extends StatefulWidget {
  final String petId;
  final SupabaseService service;
  final VetVisit? existing;

  const _VetVisitSheet({
    required this.petId,
    required this.service,
    this.existing,
  });

  @override
  State<_VetVisitSheet> createState() => _VetVisitSheetState();
}

class _VetVisitSheetState extends State<_VetVisitSheet> {
  late final TextEditingController _hospitalController;
  late final TextEditingController _reasonController;
  late final TextEditingController _diagnosisController;
  late final TextEditingController _treatmentController;
  late final TextEditingController _memoController;
  late final TextEditingController _costController;

  late DateTime _visitedAt;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _hospitalController = TextEditingController(text: e?.hospital ?? '');
    _reasonController = TextEditingController(text: e?.reason ?? '');
    _diagnosisController = TextEditingController(text: e?.diagnosis ?? '');
    _treatmentController = TextEditingController(text: e?.treatment ?? '');
    _memoController = TextEditingController(text: e?.memo ?? '');
    _costController = TextEditingController(
      text: e?.cost == null ? '' : e!.cost.toString(),
    );
    _visitedAt = e?.visitedAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _hospitalController.dispose();
    _reasonController.dispose();
    _diagnosisController.dispose();
    _treatmentController.dispose();
    _memoController.dispose();
    _costController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitedAt,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() {
      _visitedAt = picked;
    });
  }

  Future<void> _save() async {
    final hospital = _hospitalController.text.trim();
    final reason = _reasonController.text.trim();
    final diagnosis = _diagnosisController.text.trim();
    final treatment = _treatmentController.text.trim();
    final memo = _memoController.text.trim();

    final costText = _costController.text.trim().replaceAll(',', '');
    int? cost;
    if (costText.isNotEmpty) {
      final parsed = int.tryParse(costText);
      if (parsed == null || parsed < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('비용은 0 이상의 정수(원)로 입력해 주세요.')),
        );
        return;
      }
      cost = parsed;
    }

    setState(() {
      _saving = true;
    });

    try {
      final VetVisit result;
      if (_isEdit) {
        result = await widget.service.updateVetVisit(
          widget.existing!.id,
          visitedAt: _visitedAt,
          hospital: hospital,
          reason: reason,
          diagnosis: diagnosis,
          treatment: treatment,
          cost: cost,
          memo: memo,
        );
      } else {
        result = await widget.service.addVetVisit(
          widget.petId,
          visitedAt: _visitedAt,
          hospital: hospital,
          reason: reason,
          diagnosis: diagnosis,
          treatment: treatment,
          cost: cost,
          memo: memo,
        );
      }
      if (!mounted) return;
      Navigator.pop<VetVisit>(context, result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? '병원 기록 수정' : '병원 기록 추가',
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text('방문일: ${_formatDate(_visitedAt)}'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hospitalController,
              decoration: const InputDecoration(
                labelText: '병원명 (선택)',
                border: OutlineInputBorder(),
                hintText: '예: ○○ 동물병원',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: '증상/사유 (선택)',
                border: OutlineInputBorder(),
                hintText: '예: 구토, 기침',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _diagnosisController,
              decoration: const InputDecoration(
                labelText: '진단 (선택)',
                border: OutlineInputBorder(),
                hintText: '예: 급성 위염',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _treatmentController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '처치 (선택)',
                border: OutlineInputBorder(),
                hintText: '예: 수액, 처방약 3일분',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _costController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '비용 (원, 선택)',
                border: OutlineInputBorder(),
                hintText: '예: 35000',
                suffixText: '원',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _memoController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
                border: OutlineInputBorder(),
                hintText: '예: 재방문 권유받음',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
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
      ),
    );
  }
}
