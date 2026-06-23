import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/log_entry.dart';
import '../models/milestone.dart';
import '../models/pet.dart';
import '../models/vaccination.dart';
import '../models/vet_visit.dart';
import '../models/weight_record.dart';
import '../services/supabase_service.dart';
import 'add_log_screen.dart';
import 'health_screen.dart';
import 'photo_view_screen.dart';

enum CalendarEventType {
  log,
  weight,
  vaccinationDone,
  vaccinationDue,
  milestone,
  vetVisit,
  anniversary,
}

class CalendarEvent {
  final CalendarEventType type;
  final DateTime date;
  final String title;
  final String? subtitle;
  final Object? payload;

  const CalendarEvent({
    required this.type,
    required this.date,
    required this.title,
    this.subtitle,
    this.payload,
  });
}

class CalendarScreen extends StatefulWidget {
  final Pet pet;
  const CalendarScreen({super.key, required this.pet});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final SupabaseService _service = SupabaseService();

  late Pet _pet;
  List<Pet> _pets = [];

  late DateTime _focusedDay;
  late DateTime _selectedDay;

  bool _loading = true;
  String? _error;

  List<LogEntry> _logs = [];
  List<WeightRecord> _weights = [];
  List<Vaccination> _vaccinations = [];
  List<Milestone> _milestones = [];
  List<VetVisit> _vetVisits = [];

  Map<DateTime, List<CalendarEvent>> _eventsByDay = {};

  @override
  void initState() {
    super.initState();
    _pet = widget.pet;
    final now = DateTime.now();
    _focusedDay = DateTime(now.year, now.month, now.day);
    _selectedDay = _focusedDay;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final pets = await _service.fetchPets();
      if (!mounted) return;
      setState(() {
        _pets = pets;
      });
    } catch (_) {
      // 펫 목록 불러오기 실패는 캘린더 자체에 영향 없게 무시.
    }
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final petId = _pet.id;
      final results = await Future.wait<dynamic>([
        _service.fetchLogs(petId),
        _service.fetchWeights(petId),
        _service.fetchVaccinations(petId),
        _service.fetchMilestones(petId),
        _service.fetchVetVisits(petId),
      ]);
      if (!mounted) return;
      setState(() {
        _logs = results[0] as List<LogEntry>;
        _weights = results[1] as List<WeightRecord>;
        _vaccinations = results[2] as List<Vaccination>;
        _milestones = results[3] as List<Milestone>;
        _vetVisits = results[4] as List<VetVisit>;
        _eventsByDay = _buildEventsMap();
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

  DateTime _dateKey(DateTime dt) {
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  Map<DateTime, List<CalendarEvent>> _buildEventsMap() {
    final map = <DateTime, List<CalendarEvent>>{};

    void add(CalendarEvent ev) {
      final key = _dateKey(ev.date);
      map.putIfAbsent(key, () => []).add(ev);
    }

    for (final l in _logs) {
      final preview = l.content.length > 30
          ? '${l.content.substring(0, 30)}...'
          : l.content;
      add(
        CalendarEvent(
          type: CalendarEventType.log,
          date: l.createdAt,
          title: '일기',
          subtitle: preview.isEmpty ? null : preview,
          payload: l,
        ),
      );
    }

    for (final w in _weights) {
      add(
        CalendarEvent(
          type: CalendarEventType.weight,
          date: w.measuredAt,
          title: '체중',
          subtitle: '${w.weightKg.toStringAsFixed(1)} kg',
          payload: w,
        ),
      );
    }

    for (final v in _vaccinations) {
      final administered = v.administeredAt;
      if (administered != null) {
        add(
          CalendarEvent(
            type: CalendarEventType.vaccinationDone,
            date: administered,
            title: '${v.name} 접종 완료',
            subtitle: v.memo,
            payload: v,
          ),
        );
      }
      final due = v.nextDueAt;
      if (due != null) {
        add(
          CalendarEvent(
            type: CalendarEventType.vaccinationDue,
            date: due,
            title: '${v.name} 접종 예정',
            subtitle: v.memo,
            payload: v,
          ),
        );
      }
    }

    for (final m in _milestones) {
      add(
        CalendarEvent(
          type: CalendarEventType.milestone,
          date: m.achievedAt,
          title: m.title,
          subtitle: m.memo,
          payload: m,
        ),
      );
    }

    for (final v in _vetVisits) {
      final subtitle =
          (v.hospital != null && v.hospital!.isNotEmpty)
              ? (v.reason != null && v.reason!.isNotEmpty
                  ? '${v.hospital} · ${v.reason}'
                  : v.hospital)
              : v.reason;
      add(
        CalendarEvent(
          type: CalendarEventType.vetVisit,
          date: v.visitedAt,
          title: '병원 방문',
          subtitle: subtitle,
          payload: v,
        ),
      );
    }

    _addAnniversariesFor(_focusedDay, map);
    return map;
  }

  void _addAnniversariesFor(
    DateTime focused,
    Map<DateTime, List<CalendarEvent>> map,
  ) {
    final rangeStart = DateTime(focused.year, focused.month - 1, 1);
    final rangeEnd = DateTime(focused.year, focused.month + 2, 0);

    bool inRange(DateTime d) =>
        !d.isBefore(rangeStart) && !d.isAfter(rangeEnd);

    void put(CalendarEvent ev) {
      final key = _dateKey(ev.date);
      map.putIfAbsent(key, () => []).add(ev);
    }

    final adoption = DateTime(
      _pet.adoptionDate.year,
      _pet.adoptionDate.month,
      _pet.adoptionDate.day,
    );

    // 입양 N주년: 연도별 입양월일.
    for (var y = adoption.year + 1; y <= focused.year + 2; y++) {
      final d = DateTime(y, adoption.month, adoption.day);
      if (!inRange(d)) continue;
      final n = y - adoption.year;
      put(
        CalendarEvent(
          type: CalendarEventType.anniversary,
          date: d,
          title: '입양 $n주년',
          subtitle: '${_pet.name}와 함께한 지 $n년',
        ),
      );
    }

    // 입양 N일(D+100/200/...): 보이는 달에 들어오는 것만.
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final daysSinceAdoptionToRangeEnd =
        rangeEnd.difference(adoption).inDays + 1;
    for (var n = 100; n <= daysSinceAdoptionToRangeEnd; n += 100) {
      final d = adoption.add(Duration(days: n - 1));
      if (!inRange(d)) continue;
      if (d.isBefore(todayOnly)) continue; // 다가오는 것만.
      put(
        CalendarEvent(
          type: CalendarEventType.anniversary,
          date: d,
          title: '입양 $n일',
          subtitle: '${_pet.name}와 함께한 지 $n일',
        ),
      );
    }

    // 생일: 매년 같은 월일.
    final bd = _pet.birthday;
    if (bd != null) {
      for (var y = bd.year; y <= focused.year + 2; y++) {
        final d = DateTime(y, bd.month, bd.day);
        if (!inRange(d)) continue;
        final age = y - bd.year;
        put(
          CalendarEvent(
            type: CalendarEventType.anniversary,
            date: d,
            title: '${_pet.name} 생일',
            subtitle: age == 0 ? '태어난 날' : '$age살 생일',
          ),
        );
      }
    }
  }

  List<CalendarEvent> _eventsFor(DateTime day) {
    return _eventsByDay[_dateKey(day)] ?? const [];
  }

  Future<void> _openPetPicker() async {
    if (_pets.length <= 1) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text('펫 선택', style: Theme.of(ctx).textTheme.titleMedium),
              ),
              for (final p in _pets)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(ctx).colorScheme.primaryContainer,
                    child: Text(
                      p.name.characters.first,
                      style: TextStyle(
                        color:
                            Theme.of(ctx).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  title: Text(p.name),
                  subtitle: Text(p.species),
                  trailing: p.id == _pet.id
                      ? Icon(
                          Icons.check,
                          color: Theme.of(ctx).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    if (p.id != _pet.id) _selectPet(p);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectPet(Pet p) async {
    setState(() {
      _pet = p;
      _logs = [];
      _weights = [];
      _vaccinations = [];
      _milestones = [];
      _vetVisits = [];
      _eventsByDay = {};
    });
    await _load();
  }

  void _onEventTap(CalendarEvent ev) {
    switch (ev.type) {
      case CalendarEventType.log:
        final log = ev.payload as LogEntry;
        if (log.photoUrl != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PhotoViewScreen(imageUrl: log.photoUrl!),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddLogScreen(petId: _pet.id, existing: log),
            ),
          );
        }
        break;
      case CalendarEventType.weight:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                HealthScreen(petId: _pet.id, initialTab: HealthTab.weight),
          ),
        );
        break;
      case CalendarEventType.vaccinationDone:
      case CalendarEventType.vaccinationDue:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HealthScreen(
              petId: _pet.id,
              initialTab: HealthTab.vaccinations,
            ),
          ),
        );
        break;
      case CalendarEventType.vetVisit:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                HealthScreen(petId: _pet.id, initialTab: HealthTab.vetVisits),
          ),
        );
        break;
      case CalendarEventType.milestone:
      case CalendarEventType.anniversary:
        // 표시만.
        break;
    }
  }

  Color _colorFor(CalendarEventType type, ColorScheme cs) {
    switch (type) {
      case CalendarEventType.log:
        return cs.primary;
      case CalendarEventType.weight:
        return cs.secondary;
      case CalendarEventType.vaccinationDone:
      case CalendarEventType.vaccinationDue:
        return cs.tertiary;
      case CalendarEventType.milestone:
        return cs.tertiary;
      case CalendarEventType.vetVisit:
        return cs.error;
      case CalendarEventType.anniversary:
        return cs.primary;
    }
  }

  IconData _iconFor(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.log:
        return Icons.photo_outlined;
      case CalendarEventType.weight:
        return Icons.monitor_weight_outlined;
      case CalendarEventType.vaccinationDone:
        return Icons.vaccines_outlined;
      case CalendarEventType.vaccinationDue:
        return Icons.event_outlined;
      case CalendarEventType.milestone:
        return Icons.emoji_events_outlined;
      case CalendarEventType.vetVisit:
        return Icons.local_hospital_outlined;
      case CalendarEventType.anniversary:
        return Icons.celebration_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _pets.length > 1 ? _openPetPicker : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${_pet.name} 캘린더'),
              if (_pets.length > 1) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(cs, tt)
              : _buildBody(cs, tt),
    );
  }

  Widget _buildError(ColorScheme cs, TextTheme tt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('데이터를 불러오지 못했어요.', style: tt.bodyLarge),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: tt.bodySmall?.copyWith(color: cs.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ColorScheme cs, TextTheme tt) {
    final firstDay = DateTime(2000, 1, 1);
    final lastDay = DateTime(DateTime.now().year + 5, 12, 31);
    final dayEvents = _eventsFor(_selectedDay);

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: TableCalendar<CalendarEvent>(
              locale: 'ko_KR',
              firstDay: firstDay,
              lastDay: lastDay,
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) =>
                  isSameDay(day, _selectedDay),
              eventLoader: _eventsFor,
              startingDayOfWeek: StartingDayOfWeek.monday,
              availableCalendarFormats: const {
                CalendarFormat.month: '월',
              },
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: TextStyle(color: cs.error),
                selectedDecoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: TextStyle(
                  color: cs.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
                todayDecoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
                markerDecoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                markersAlignment: Alignment.bottomCenter,
                markersOffset: const PositionedOffset(bottom: 4),
                markerSize: 5,
                markerMargin: const EdgeInsets.symmetric(horizontal: 1.2),
              ),
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: tt.titleMedium ?? const TextStyle(),
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: cs.onSurface,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: cs.onSurface,
                ),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekendStyle: TextStyle(color: cs.error),
              ),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
              },
              onPageChanged: (focused) {
                setState(() {
                  _focusedDay = focused;
                  _eventsByDay = _buildEventsMap();
                });
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            children: [
              Text(
                _formatSelectedHeading(_selectedDay),
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              if (dayEvents.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${dayEvents.length}',
                    style: tt.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: _buildEventList(dayEvents, cs, tt)),
      ],
    );
  }

  Widget _buildEventList(
    List<CalendarEvent> events,
    ColorScheme cs,
    TextTheme tt,
  ) {
    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '이 날의 기록이 없어요',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final ev = events[index];
        final color = _colorFor(ev.type, cs);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconFor(ev.type), color: color, size: 20),
            ),
            title: Text(
              ev.title,
              style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: (ev.subtitle == null || ev.subtitle!.isEmpty)
                ? null
                : Text(
                    ev.subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: _isNavigable(ev.type)
                ? const Icon(Icons.chevron_right)
                : null,
            onTap: _isNavigable(ev.type) ? () => _onEventTap(ev) : null,
          ),
        );
      },
    );
  }

  bool _isNavigable(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.log:
      case CalendarEventType.weight:
      case CalendarEventType.vaccinationDone:
      case CalendarEventType.vaccinationDue:
      case CalendarEventType.vetVisit:
        return true;
      case CalendarEventType.milestone:
      case CalendarEventType.anniversary:
        return false;
    }
  }

  String _formatSelectedHeading(DateTime dt) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y.$m.$d (${weekdays[dt.weekday - 1]})';
  }
}
