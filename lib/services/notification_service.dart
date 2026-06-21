import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/medication.dart';
import '../models/pet.dart';
import '../models/vaccination.dart';

class NotificationTap {
  final String petId;
  final String type;

  const NotificationTap({required this.petId, required this.type});
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String _kEnabledKey = 'notifications_enabled';
  static const String _androidChannelId = 'pet_diary_reminders';
  static const String _androidChannelName = '리마인더';
  static const String _androidChannelDesc = '예방접종, 기념일, 투약 등 리마인더 알림';

  // 시퀀셜 ID(접종·기념일)는 0..0x3FFFFFFF, 투약 해시 ID는 0x40000000..0x7FFFFFFF.
  static const int _medicationIdMask = 0x40000000;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _enabled = true;

  bool get enabled => _enabled;
  bool get isSupported => !kIsWeb;
  bool get isInitialized => _initialized;

  final ValueNotifier<NotificationTap?> tapNotifier =
      ValueNotifier<NotificationTap?>(null);

  Future<void> init() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_kEnabledKey) ?? true;
      return;
    }
    if (_initialized) return;

    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // 디바이스 타임존을 얻지 못하면 UTC 기본값 유지.
    }

    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kEnabledKey) ?? true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onResponse,
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          _androidChannelId,
          _androidChannelName,
          description: _androidChannelDesc,
          importance: Importance.high,
        ),
      );
    }

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
      _handlePayload(launchDetails.notificationResponse?.payload);
    }

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    if (!_initialized) return false;

    bool granted = false;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final notif = await android.requestNotificationsPermission();
      granted = notif ?? granted;
      try {
        await android.requestExactAlarmsPermission();
      } catch (_) {
        // 정확 알람 권한 요청은 일부 기기에서 실패할 수 있으므로 무시.
      }
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final ok = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      granted = ok ?? granted;
    }

    return granted;
  }

  void _onResponse(NotificationResponse response) {
    _handlePayload(response.payload);
  }

  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final parts = payload.split('|');
    if (parts.length < 2) return;
    tapNotifier.value = NotificationTap(type: parts[0], petId: parts[1]);
  }

  void consumeTap() {
    tapNotifier.value = null;
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, value);
    if (kIsWeb) return;
    if (!_initialized) return;
    if (!value) {
      await _plugin.cancelAll();
    }
  }

  Future<void> cancelAll() async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancelAll();
  }

  Future<void> rescheduleAll({
    required List<Pet> pets,
    required Map<String, List<Vaccination>> vaccinationsByPetId,
    Map<String, List<Medication>> medicationsByPetId = const {},
  }) async {
    if (kIsWeb) return;
    if (!_initialized) return;

    await _plugin.cancelAll();
    if (!_enabled) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var nextId = 1;

    for (final pet in pets) {
      final vaccinations = vaccinationsByPetId[pet.id] ?? const <Vaccination>[];
      for (final v in vaccinations) {
        final due = v.nextDueAt;
        if (due == null) continue;
        if (v.administeredAt != null) continue;

        final dueDate = DateTime(due.year, due.month, due.day);
        final dayBefore = dueDate.subtract(const Duration(days: 1));
        final dayBeforeAt9 = DateTime(
          dayBefore.year,
          dayBefore.month,
          dayBefore.day,
          9,
        );
        if (dayBeforeAt9.isAfter(now)) {
          await _scheduleOnce(
            id: nextId++,
            when: dayBeforeAt9,
            title: '${pet.name} 예방접종 안내',
            body: '내일은 ${pet.name} ${v.name} 예방접종일이에요',
            payload: 'health|${pet.id}',
          );
        }

        final dueAt9 = DateTime(dueDate.year, dueDate.month, dueDate.day, 9);
        if (dueAt9.isAfter(now)) {
          await _scheduleOnce(
            id: nextId++,
            when: dueAt9,
            title: '${pet.name} 예방접종일',
            body: '오늘은 ${pet.name} ${v.name} 예방접종일이에요',
            payload: 'health|${pet.id}',
          );
        }
      }

      final adoption = DateTime(
        pet.adoptionDate.year,
        pet.adoptionDate.month,
        pet.adoptionDate.day,
      );

      var dayCount = 0;
      for (var n = 100; n <= 20000 && dayCount < 5; n += 100) {
        final date = adoption.add(Duration(days: n - 1));
        if (date.isBefore(today)) continue;
        final at9 = DateTime(date.year, date.month, date.day, 9);
        if (!at9.isAfter(now)) continue;
        await _scheduleOnce(
          id: nextId++,
          when: at9,
          title: '🎉 ${pet.name} 입양 $n일',
          body: '${pet.name}와 함께한 지 $n일이 되었어요!',
          payload: 'home|${pet.id}',
        );
        dayCount++;
      }

      var yearCount = 0;
      for (var n = 1; n <= 30 && yearCount < 3; n++) {
        final date = DateTime(adoption.year + n, adoption.month, adoption.day);
        if (date.isBefore(today)) continue;
        final at9 = DateTime(date.year, date.month, date.day, 9);
        if (!at9.isAfter(now)) continue;
        await _scheduleOnce(
          id: nextId++,
          when: at9,
          title: '🎉 ${pet.name} 입양 $n주년',
          body: '${pet.name} 입양 $n주년을 축하해요!',
          payload: 'home|${pet.id}',
        );
        yearCount++;
      }

      final bd = pet.birthday;
      if (bd != null) {
        var bdCount = 0;
        for (var n = 0; n <= 5 && bdCount < 2; n++) {
          final date = DateTime(today.year + n, bd.month, bd.day);
          if (date.isBefore(today)) continue;
          final at9 = DateTime(date.year, date.month, date.day, 9);
          if (!at9.isAfter(now)) continue;
          await _scheduleOnce(
            id: nextId++,
            when: at9,
            title: '🎂 ${pet.name} 생일',
            body: '오늘은 ${pet.name}의 생일이에요! 축하해요 🎉',
            payload: 'home|${pet.id}',
          );
          bdCount++;
        }
      }

      final medications = medicationsByPetId[pet.id] ?? const <Medication>[];
      for (final m in medications) {
        await _scheduleMedication(pet: pet, medication: m, today: today);
      }
    }
  }

  Future<void> _scheduleMedication({
    required Pet pet,
    required Medication medication,
    required DateTime today,
  }) async {
    if (!medication.reminderEnabled) return;
    if (medication.times.isEmpty) return;
    if (!medication.isActiveOn(today)) return;

    final parsedTimes = <_HourMinute>[];
    for (final raw in medication.times) {
      final parsed = _parseHourMinute(raw);
      if (parsed != null) parsedTimes.add(parsed);
    }
    if (parsedTimes.isEmpty) return;

    final dosage = medication.dosage;
    final body = dosage == null || dosage.isEmpty
        ? '${pet.name} ${medication.name} 복용 시간이에요'
        : '${pet.name} ${medication.name} ($dosage) 복용 시간이에요';

    final weekdays = medication.weekdays;

    if (weekdays.isEmpty) {
      for (final t in parsedTimes) {
        await _scheduleRepeating(
          id: _medicationId(medication.id, t.hour, t.minute, 0),
          title: '💊 ${medication.name} 복용 시간',
          body: body,
          hour: t.hour,
          minute: t.minute,
          weekday: null,
          payload: 'medication|${pet.id}',
        );
      }
      return;
    }

    final uniqueWeekdays = <int>{};
    for (final w in weekdays) {
      if (w >= 1 && w <= 7) uniqueWeekdays.add(w);
    }
    for (final w in uniqueWeekdays) {
      for (final t in parsedTimes) {
        await _scheduleRepeating(
          id: _medicationId(medication.id, t.hour, t.minute, w),
          title: '💊 ${medication.name} 복용 시간',
          body: body,
          hour: t.hour,
          minute: t.minute,
          weekday: w,
          payload: 'medication|${pet.id}',
        );
      }
    }
  }

  Future<void> _scheduleOnce({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    required String payload,
  }) async {
    final scheduled = tz.TZDateTime.from(when, tz.local);
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    } catch (_) {
      // 정확 알람 권한 미부여 등 일부 환경에서 실패할 수 있으나 무시.
    }
  }

  Future<void> _scheduleRepeating({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required int? weekday,
    required String payload,
  }) async {
    final scheduled = _nextScheduleDate(hour: hour, minute: minute, weekday: weekday);
    final match = weekday == null
        ? DateTimeComponents.time
        : DateTimeComponents.dayOfWeekAndTime;
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: match,
        payload: payload,
      );
    } catch (_) {
      // 권한 미부여 등 일부 환경에서 실패할 수 있으나 무시.
    }
  }

  tz.TZDateTime _nextScheduleDate({
    required int hour,
    required int minute,
    required int? weekday,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    if (weekday != null) {
      while (scheduled.weekday != weekday) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
    }
    return scheduled;
  }

  static NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: _androidChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  int _medicationId(String medicationId, int hour, int minute, int weekday) {
    var h = 0x811C9DC5;
    void mix(int value) {
      h ^= value & 0xFF;
      h = (h * 0x01000193) & 0x7FFFFFFF;
    }

    for (var i = 0; i < medicationId.length; i++) {
      mix(medicationId.codeUnitAt(i));
    }
    mix(hour);
    mix(minute);
    mix(weekday);
    return _medicationIdMask | (h & 0x3FFFFFFF);
  }

  _HourMinute? _parseHourMinute(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return _HourMinute(h, m);
  }
}

class _HourMinute {
  final int hour;
  final int minute;
  const _HourMinute(this.hour, this.minute);
}
