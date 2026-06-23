// Supabase의 todo_items 테이블과 매핑되는 모델.
//
// 가정한 스키마:
//   id              uuid primary key
//   pet_id          uuid references pets(id) on delete cascade
//   title           text not null
//   due_date        date  null
//   reminder_time   text  null  -- 'HH:mm'
//   repeat_type     text  not null default 'none'  -- none|daily|weekly|monthly
//   repeat_weekdays integer[]   null  -- 1(월) ~ 7(일)
//   note            text  null
//   is_done         boolean not null default false
//   done_at         timestamptz null
//   created_at      timestamptz not null default now()

enum TodoRepeatType { none, daily, weekly, monthly }

TodoRepeatType _parseRepeat(String? raw) {
  switch (raw) {
    case 'daily':
      return TodoRepeatType.daily;
    case 'weekly':
      return TodoRepeatType.weekly;
    case 'monthly':
      return TodoRepeatType.monthly;
    case 'none':
    default:
      return TodoRepeatType.none;
  }
}

String repeatTypeToApi(TodoRepeatType t) {
  switch (t) {
    case TodoRepeatType.daily:
      return 'daily';
    case TodoRepeatType.weekly:
      return 'weekly';
    case TodoRepeatType.monthly:
      return 'monthly';
    case TodoRepeatType.none:
      return 'none';
  }
}

String repeatTypeLabel(TodoRepeatType t) {
  switch (t) {
    case TodoRepeatType.daily:
      return '매일';
    case TodoRepeatType.weekly:
      return '매주';
    case TodoRepeatType.monthly:
      return '매월';
    case TodoRepeatType.none:
      return '반복 없음';
  }
}

class TodoItem {
  final String id;
  final String petId;
  final String title;
  final DateTime? dueDate;
  // 'HH:mm' 또는 null.
  final String? reminderTime;
  final TodoRepeatType repeatType;
  // 매주 반복일 때 선택된 요일 (1=월 ... 7=일). 그 외엔 빈 집합.
  final Set<int> repeatWeekdays;
  final String? note;
  final bool isDone;
  final DateTime? doneAt;
  final DateTime createdAt;

  const TodoItem({
    required this.id,
    required this.petId,
    required this.title,
    required this.dueDate,
    required this.reminderTime,
    required this.repeatType,
    required this.repeatWeekdays,
    required this.note,
    required this.isDone,
    required this.doneAt,
    required this.createdAt,
  });

  bool get isRepeating => repeatType != TodoRepeatType.none;

  int? get reminderHour {
    final t = reminderTime;
    if (t == null) return null;
    final parts = t.split(':');
    if (parts.length != 2) return null;
    return int.tryParse(parts[0]);
  }

  int? get reminderMinute {
    final t = reminderTime;
    if (t == null) return null;
    final parts = t.split(':');
    if (parts.length != 2) return null;
    return int.tryParse(parts[1]);
  }

  // 주어진 날짜에 이 할 일이 해당되는지 여부 (반복 포함).
  // - none: due_date == day
  // - daily: due_date == null이거나 due_date <= day인 경우 항상 true
  // - weekly: due_date 조건 충족 + day.weekday가 repeatWeekdays에 포함
  // - monthly: due_date의 day-of-month == day의 day-of-month (또는 시작일 이후)
  bool occursOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final start = dueDate == null
        ? null
        : DateTime(dueDate!.year, dueDate!.month, dueDate!.day);

    switch (repeatType) {
      case TodoRepeatType.none:
        return start != null && start.isAtSameMomentAs(d);
      case TodoRepeatType.daily:
        if (start == null) return true;
        return !d.isBefore(start);
      case TodoRepeatType.weekly:
        if (repeatWeekdays.isEmpty) return false;
        if (start != null && d.isBefore(start)) return false;
        return repeatWeekdays.contains(d.weekday);
      case TodoRepeatType.monthly:
        if (start == null) return false;
        if (d.isBefore(start)) return false;
        return d.day == start.day;
    }
  }

  factory TodoItem.fromMap(Map<String, dynamic> map) {
    final dueRaw = map['due_date'] as String?;
    final doneRaw = map['done_at'] as String?;
    final createdRaw = map['created_at'] as String?;
    final weekdaysRaw = map['repeat_weekdays'];
    final weekdays = <int>{};
    if (weekdaysRaw is List) {
      for (final w in weekdaysRaw) {
        if (w is int) {
          weekdays.add(w);
        } else if (w is num) {
          weekdays.add(w.toInt());
        }
      }
    }
    return TodoItem(
      id: map['id'] as String,
      petId: map['pet_id'] as String,
      title: map['title'] as String,
      dueDate: dueRaw == null ? null : DateTime.parse(dueRaw),
      reminderTime: map['reminder_time'] as String?,
      repeatType: _parseRepeat(map['repeat_type'] as String?),
      repeatWeekdays: weekdays,
      note: map['note'] as String?,
      isDone: (map['is_done'] as bool?) ?? false,
      doneAt: doneRaw == null ? null : DateTime.parse(doneRaw),
      createdAt:
          createdRaw == null ? DateTime.now() : DateTime.parse(createdRaw),
    );
  }
}
