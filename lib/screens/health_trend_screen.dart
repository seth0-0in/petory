import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/daily_health_log.dart';
import '../services/supabase_service.dart';
import 'senior_symptom_check_screen.dart';

class HealthTrendTab extends StatefulWidget {
  final String petId;
  final String petName;
  final String petSpecies;

  const HealthTrendTab({
    super.key,
    required this.petId,
    required this.petName,
    required this.petSpecies,
  });

  @override
  State<HealthTrendTab> createState() => _HealthTrendTabState();
}

class _HealthTrendTabState extends State<HealthTrendTab>
    with AutomaticKeepAliveClientMixin<HealthTrendTab> {
  final SupabaseService _service = SupabaseService();

  List<DailyHealthLog> _logs = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _openSymptomCheck() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SeniorSymptomCheckScreen(
          petName: widget.petName,
          petSpecies: widget.petSpecies,
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final logs = await _service.fetchRecentHealthLogs(widget.petId, days: 30);
      if (!mounted) return;
      setState(() {
        _logs = logs;
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
              Text('데이터를 불러오지 못했어요.', style: textTheme.bodyLarge),
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

    if (_logs.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          _SymptomCheckButton(
            colorScheme: colorScheme,
            textTheme: textTheme,
            onTap: _openSymptomCheck,
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              '최근 30일간 건강 체크 기록이 없어요.\n홈 화면에서 오늘 건강 체크를 시작해보세요.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          _SymptomCheckButton(
            colorScheme: colorScheme,
            textTheme: textTheme,
            onTap: _openSymptomCheck,
          ),
          const SizedBox(height: 16),
          Text(
            '최근 30일 건강 추이',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '빨간 점은 통증 신호가 있었던 날이에요',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _TrendChartCard(
            title: '🍖 식욕',
            getValue: (l) => l.appetite,
            logs: _logs,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: 10),
          _TrendChartCard(
            title: '🏃 활동량',
            getValue: (l) => l.activity,
            logs: _logs,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: 10),
          _TrendChartCard(
            title: '😴 수면',
            getValue: (l) => l.sleep,
            logs: _logs,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: 10),
          _TrendChartCard(
            title: '🚽 배변',
            getValue: (l) => l.digestion,
            logs: _logs,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: 20),
          Text(
            '최근 7일 기록',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _RecentList(logs: _logs, colorScheme: colorScheme, textTheme: textTheme),
        ],
      ),
    );
  }
}

class _TrendChartCard extends StatelessWidget {
  final String title;
  final int? Function(DailyHealthLog) getValue;
  final List<DailyHealthLog> logs;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _TrendChartCard({
    required this.title,
    required this.getValue,
    required this.logs,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    // 점수가 입력된 날만 라인에 표시. 통증 신호는 점수 유무와 별개로 빨간 점으로 표시.
    final spots = <FlSpot>[];
    final painSpots = <FlSpot>[];
    for (var i = 0; i < logs.length; i++) {
      final v = getValue(logs[i]);
      final x = i.toDouble();
      if (v != null) {
        spots.add(FlSpot(x, v.toDouble()));
      }
      if (logs[i].painSigns) {
        // 통증 신호는 값이 없으면 1로, 있으면 그 값에 표시.
        painSpots.add(FlSpot(x, (v ?? 1).toDouble()));
      }
    }

    final maxX = logs.length == 1 ? 1.0 : (logs.length - 1).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: 0.8,
                maxY: 5.2,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
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
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value != value.toInt().toDouble()) {
                          return const SizedBox.shrink();
                        }
                        final i = value.toInt();
                        if (i < 1 || i > 5) return const SizedBox.shrink();
                        return Text('$i', style: textTheme.bodySmall);
                      },
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
                      reservedSize: 24,
                      interval: _bottomInterval(logs.length),
                      getTitlesWidget: (value, meta) {
                        if (value != value.toInt().toDouble()) {
                          return const SizedBox.shrink();
                        }
                        final i = value.toInt();
                        if (i < 0 || i >= logs.length) {
                          return const SizedBox.shrink();
                        }
                        final dt = logs[i].loggedDate.toLocal();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${dt.month}/${dt.day}',
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
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                            radius: 3,
                            color: colorScheme.primary,
                            strokeWidth: 2,
                            strokeColor: colorScheme.surface,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: colorScheme.primary.withValues(alpha: 0.10),
                    ),
                  ),
                  if (painSpots.isNotEmpty)
                    LineChartBarData(
                      spots: painSpots,
                      isCurved: false,
                      color: colorScheme.error.withValues(alpha: 0.0),
                      barWidth: 0,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(
                              radius: 5,
                              color: colorScheme.error,
                              strokeWidth: 2,
                              strokeColor: colorScheme.surface,
                            ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _bottomInterval(int count) {
    if (count <= 7) return 1;
    if (count <= 15) return 2;
    if (count <= 22) return 4;
    return 7;
  }
}

class _RecentList extends StatelessWidget {
  final List<DailyHealthLog> logs;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _RecentList({
    required this.logs,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    // 최신 7일 (오름차순 정렬되어 있으므로 뒤에서 7개).
    final tail = logs.length <= 7
        ? logs.reversed.toList()
        : logs.sublist(logs.length - 7).reversed.toList();

    return Column(
      children: [
        for (final log in tail)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: log.painSigns
                  ? colorScheme.errorContainer.withValues(alpha: 0.6)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatShortDate(log.loggedDate),
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (log.painSigns)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '⚠️ 통증',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _metricRow('🍖 식욕', log.appetite),
                      _metricRow('🏃 활동량', log.activity),
                      _metricRow('😴 수면', log.sleep),
                      _metricRow('🚽 배변', log.digestion),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _metricRow(String label, int? value) {
    final stars = value == null ? '-' : '⭐' * value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              stars,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatShortDate(DateTime dt) {
    final local = dt.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '$m.$d (${weekdays[local.weekday - 1]})';
  }
}

class _SymptomCheckButton extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  const _SymptomCheckButton({
    required this.colorScheme,
    required this.textTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Text(
                '🔍',
                style: TextStyle(
                  fontSize: 22,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '지금 우리 아이 상태 확인',
                      style: textTheme.titleSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '카테고리별 증상 체크리스트',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
