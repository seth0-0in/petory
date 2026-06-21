import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/log_entry.dart';
import '../models/medication.dart';
import '../models/pet.dart';
import '../models/vaccination.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import 'add_log_screen.dart';
import 'calendar_screen.dart';
import 'care_tips_screen.dart';
import 'edit_pet_screen.dart';
import 'family_share_screen.dart';
import 'gallery_screen.dart';
import 'health_screen.dart';
import 'milestones_screen.dart';
import 'nearby_vet_sheet.dart';
import 'photo_view_screen.dart';
import 'settings_screen.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';

const String _kGuestBannerDismissedPrefsKey = 'guest_banner_dismissed';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseService _service = SupabaseService();

  List<Pet> _pets = [];
  Pet? _selectedPet;
  List<LogEntry> _logs = [];
  List<Vaccination> _vaccinations = [];
  bool _loading = true;
  bool _logsLoading = false;
  String? _error;
  bool _promptingOverdue = false;

  bool _searchVisible = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTimeRange? _dateRange;

  StreamSubscription<AuthState>? _authSub;
  String? _lastAuthUserId;

  bool _guestBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _lastAuthUserId = AuthService.instance.currentUser?.id;
    _load();
    _loadGuestBannerState();
    NotificationService.instance.tapNotifier.addListener(_onNotificationTap);
    _authSub = AuthService.instance.onAuthStateChange.listen(_onAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeRequestNotificationPermission();
      _onNotificationTap();
    });
  }

  Future<void> _loadGuestBannerState() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_kGuestBannerDismissedPrefsKey) ?? false;
    if (!mounted) return;
    if (dismissed != _guestBannerDismissed) {
      setState(() {
        _guestBannerDismissed = dismissed;
      });
    }
  }

  Future<void> _dismissGuestBanner() async {
    setState(() {
      _guestBannerDismissed = true;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kGuestBannerDismissedPrefsKey, true);
  }

  Future<void> _openSignUpFromBanner() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SignUpScreen()),
    );
    if (!mounted) return;
    // 계정 전환에 성공했다면 isAnonymous가 false가 되어 배너가 자동으로 사라짐.
    setState(() {});
  }

  bool get _shouldShowGuestBanner =>
      AuthService.instance.isAnonymous &&
      _pets.isNotEmpty &&
      !_guestBannerDismissed;

  @override
  void dispose() {
    _authSub?.cancel();
    NotificationService.instance.tapNotifier.removeListener(_onNotificationTap);
    _searchController.dispose();
    super.dispose();
  }

  void _onAuthChanged(AuthState state) {
    final newId = state.session?.user.id;
    if (newId == _lastAuthUserId) return;
    _lastAuthUserId = newId;
    if (!mounted) return;
    // 사용자가 바뀌면 펫·기록을 모두 다시 불러오고, 알림도 새 사용자 기준으로 재예약.
    setState(() {
      _pets = [];
      _selectedPet = null;
      _logs = [];
      _vaccinations = [];
      _resetFilters();
    });
    _load();
  }

  Future<void> _maybeRequestNotificationPermission() async {
    final service = NotificationService.instance;
    if (!service.isSupported || !service.enabled) return;
    await service.requestPermissions();
  }

  void _onNotificationTap() {
    final tap = NotificationService.instance.tapNotifier.value;
    if (tap == null) return;
    NotificationService.instance.consumeTap();
    if (!mounted) return;

    Pet? target;
    for (final p in _pets) {
      if (p.id == tap.petId) {
        target = p;
        break;
      }
    }
    if (target == null) return;

    Future<void> jump() async {
      await _selectPet(target!);
      if (!mounted) return;
      if (tap.type == 'health') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HealthScreen(petId: target!.id, initialTab: 1),
          ),
        );
      } else if (tap.type == 'medication') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HealthScreen(petId: target!.id, initialTab: 2),
          ),
        );
      }
    }

    jump();
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
      // 알림 재예약 실패는 UX에 영향을 주지 않도록 무시.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pets = await _service.fetchPets();
      Pet? selected;
      List<LogEntry> logs = [];
      List<Vaccination> vaccinations = [];
      if (pets.isNotEmpty) {
        selected = pets.first;
        final results = await Future.wait([
          _service.fetchLogs(selected.id),
          _service.fetchVaccinations(selected.id),
        ]);
        logs = results[0] as List<LogEntry>;
        vaccinations = results[1] as List<Vaccination>;
      }
      if (!mounted) return;
      setState(() {
        _pets = pets;
        _selectedPet = selected;
        _logs = logs;
        _vaccinations = vaccinations;
        _loading = false;
      });
      _scheduleOverduePrompts();
      _rescheduleNotifications();
      _onNotificationTap();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectPet(Pet pet) async {
    if (_selectedPet?.id == pet.id) return;
    setState(() {
      _selectedPet = pet;
      _logs = [];
      _vaccinations = [];
      _logsLoading = true;
      _resetFilters();
    });
    try {
      final results = await Future.wait([
        _service.fetchLogs(pet.id),
        _service.fetchVaccinations(pet.id),
      ]);
      if (!mounted) return;
      setState(() {
        _logs = results[0] as List<LogEntry>;
        _vaccinations = results[1] as List<Vaccination>;
        _logsLoading = false;
      });
      _scheduleOverduePrompts();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _logsLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('기록을 불러오지 못했어요: $e')));
    }
  }

  Future<void> _openEditPet(Pet pet) async {
    final updated = await Navigator.push<Pet>(
      context,
      MaterialPageRoute(builder: (_) => EditPetScreen(pet: pet)),
    );
    if (updated == null) return;
    if (!mounted) return;
    setState(() {
      final i = _pets.indexWhere((p) => p.id == updated.id);
      if (i != -1) _pets[i] = updated;
      if (_selectedPet?.id == updated.id) _selectedPet = updated;
    });
    _rescheduleNotifications();
  }

  Future<void> _openCreatePet() async {
    final created = await Navigator.push<Pet>(
      context,
      MaterialPageRoute(builder: (_) => const EditPetScreen()),
    );
    if (created == null) return;
    if (!mounted) return;
    setState(() {
      _pets = [..._pets, created];
    });
    await _selectPet(created);
    _rescheduleNotifications();
  }

  Future<void> _openPetPicker() async {
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
                _PetPickerTile(
                  pet: p,
                  selected: p.id == _selectedPet?.id,
                  onTap: () {
                    Navigator.pop(ctx);
                    _selectPet(p);
                  },
                  onEdit: () {
                    Navigator.pop(ctx);
                    _openEditPet(p);
                  },
                  onShare: () {
                    Navigator.pop(ctx);
                    _openFamilyShare(p);
                  },
                ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('새 반려동물 추가'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openCreatePet();
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_add_outlined),
                title: const Text('코드로 참여'),
                subtitle: const Text('가족이 보낸 초대 코드로 함께 보기'),
                onTap: () {
                  Navigator.pop(ctx);
                  _redeemInviteCode();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openFamilyShare(Pet pet) async {
    final left = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FamilyShareScreen(petId: pet.id, petName: pet.name),
      ),
    );
    if (left == true) {
      await _load();
    }
  }

  Future<void> _redeemInviteCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('코드로 참여'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '가족이 공유한 초대 코드를 입력하세요.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: '초대 코드',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                Navigator.pop(ctx, value.trim());
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, controller.text.trim()),
            child: const Text('참여'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.isEmpty) return;
    if (!mounted) return;

    try {
      final joined = await _service.redeemPetInvite(code);
      if (!mounted) return;
      final pets = await _service.fetchPets();
      if (!mounted) return;
      Pet? joinedPet;
      for (final p in pets) {
        if (p.id == joined.petId) {
          joinedPet = p;
          break;
        }
      }
      setState(() {
        _pets = pets;
      });
      if (joinedPet != null) {
        await _selectPet(joinedPet);
      }
      if (!mounted) return;
      final petName = joined.petName ?? joinedPet?.name;
      final message = petName == null
          ? '가족 공유에 참여했어요.'
          : '$petName 가족 공유에 참여했어요.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      _rescheduleNotifications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeInviteError(e))));
    }
  }

  String _humanizeInviteError(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('expired')) return '만료된 초대 코드예요.';
    if (msg.contains('not found') ||
        msg.contains('invalid') ||
        msg.contains('no rows')) {
      return '유효하지 않은 초대 코드예요.';
    }
    if (msg.contains('already')) return '이미 이 펫의 멤버예요.';
    return '참여하지 못했어요: $error';
  }

  void _openHealth() {
    final pet = _selectedPet;
    if (pet == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HealthScreen(petId: pet.id)),
    );
  }

  void _openCareTips() {
    final pet = _selectedPet;
    if (pet == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CareTipsScreen(pet: pet)),
    );
  }

  void _openMilestones() {
    final pet = _selectedPet;
    if (pet == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MilestonesScreen(petId: pet.id)),
    );
  }

  void _openGallery() {
    final pet = _selectedPet;
    if (pet == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GalleryScreen(petId: pet.id)),
    );
  }

  void _openCalendar() {
    final pet = _selectedPet;
    if (pet == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CalendarScreen(pet: pet)),
    );
  }

  Future<void> _openAddLog() async {
    final pet = _selectedPet;
    if (pet == null) return;

    final saved = await Navigator.push<LogEntry>(
      context,
      MaterialPageRoute(builder: (_) => AddLogScreen(petId: pet.id)),
    );
    if (saved == null) return;
    if (!mounted) return;
    setState(() {
      _logs.insert(0, saved);
    });
  }

  Future<void> _openEditLog(LogEntry log) async {
    final pet = _selectedPet;
    if (pet == null) return;

    final updated = await Navigator.push<LogEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => AddLogScreen(petId: pet.id, existing: log),
      ),
    );
    if (updated == null) return;
    if (!mounted) return;
    setState(() {
      final i = _logs.indexWhere((l) => l.id == updated.id);
      if (i != -1) {
        _logs[i] = updated;
      }
    });
  }

  Future<void> _confirmDeleteLog(LogEntry log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('이 기록을 삭제할까요?'),
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
      await _service.deleteLog(log.id);
      if (!mounted) return;
      setState(() {
        _logs = _logs.where((l) => l.id != log.id).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    }
  }

  void _resetFilters() {
    _searchVisible = false;
    _searchController.clear();
    _searchQuery = '';
    _dateRange = null;
  }

  bool get _hasActiveFilter =>
      _searchQuery.trim().isNotEmpty || _dateRange != null;

  List<LogEntry> get _filteredLogs {
    final query = _searchQuery.trim().toLowerCase();
    final range = _dateRange;
    if (query.isEmpty && range == null) return _logs;

    DateTime? startDate;
    DateTime? endDate;
    if (range != null) {
      startDate = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      endDate = DateTime(range.end.year, range.end.month, range.end.day);
    }

    return _logs.where((log) {
      if (query.isNotEmpty && !log.content.toLowerCase().contains(query)) {
        return false;
      }
      if (startDate != null && endDate != null) {
        final local = log.createdAt.toLocal();
        final logDate = DateTime(local.year, local.month, local.day);
        if (logDate.isBefore(startDate) || logDate.isAfter(endDate)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _toggleSearch() {
    setState(() {
      if (_searchVisible) {
        _resetFilters();
      } else {
        _searchVisible = true;
      }
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _dateRange,
      helpText: '기간 선택',
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      _dateRange = picked;
    });
  }

  String _formatDateRangeLabel(DateTimeRange r) {
    final s = _formatDate(r.start);
    final e = _formatDate(r.end);
    if (s == e) return s;
    return '$s ~ $e';
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }

  void _scheduleOverduePrompts() {
    if (_promptingOverdue) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleOverdueVaccinations();
    });
  }

  Future<void> _handleOverdueVaccinations() async {
    if (_promptingOverdue) return;
    if (!mounted) return;

    final petAtStart = _selectedPet;
    if (petAtStart == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final candidates = <Vaccination>[];
    for (final v in _vaccinations) {
      if (!v.isScheduled) continue;
      final due = v.nextDueAt!;
      final dueOnly = DateTime(due.year, due.month, due.day);
      final days = dueOnly.difference(today).inDays;
      if (days >= -3 && days <= 3) {
        candidates.add(v);
      }
    }
    if (candidates.isEmpty) return;
    candidates.sort((a, b) => a.nextDueAt!.compareTo(b.nextDueAt!));

    _promptingOverdue = true;
    try {
      for (final v in candidates) {
        if (!mounted) return;
        if (_selectedPet?.id != petAtStart.id) return;

        final didIt = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('예방접종 확인'),
            content: Text('${v.name} 예방접종 맞았나요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('아니오'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('예'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (_selectedPet?.id != petAtStart.id) return;
        if (didIt != true) continue;

        final hasNext = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('다음 접종'),
            content: Text('다음 ${v.name} 접종일이 있나요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('없어요'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('있어요'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (_selectedPet?.id != petAtStart.id) return;

        DateTime? nextDue;
        if (hasNext == true) {
          final today2 = DateTime(now.year, now.month, now.day);
          nextDue = await showDatePicker(
            context: context,
            initialDate: today2,
            firstDate: today2,
            lastDate: DateTime(today2.year + 10),
            helpText: '${v.name} 다음 예정일',
          );
          if (!mounted) return;
          if (_selectedPet?.id != petAtStart.id) return;
        }

        try {
          await _service.completeVaccination(v.id, nextDue: nextDue);
          if (!mounted) return;
          if (_selectedPet?.id != petAtStart.id) return;
          final reloaded = await _service.fetchVaccinations(petAtStart.id);
          if (!mounted) return;
          if (_selectedPet?.id != petAtStart.id) return;
          setState(() {
            _vaccinations = reloaded;
          });
          _rescheduleNotifications();
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('업데이트 실패: $e')));
        }
      }
    } finally {
      _promptingOverdue = false;
    }
  }

  List<_VaccinationAlert> _vaccinationAlerts() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final alerts = <_VaccinationAlert>[];
    for (final v in _vaccinations) {
      if (!v.isScheduled) continue;
      final due = v.nextDueAt!;
      final dueOnly = DateTime(due.year, due.month, due.day);
      final days = dueOnly.difference(today).inDays;
      if (days >= 0 && days <= 14) {
        alerts.add(_VaccinationAlert(v, days));
      }
    }
    alerts.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
    return alerts.take(2).toList();
  }

  void _openVaccinationsTab() {
    final pet = _selectedPet;
    if (pet == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HealthScreen(petId: pet.id, initialTab: 1),
      ),
    );
  }

  _Anniversary? _nextAnniversary(Pet pet) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final adoption = DateTime(
      pet.adoptionDate.year,
      pet.adoptionDate.month,
      pet.adoptionDate.day,
    );

    final candidates = <_Anniversary>[];

    for (var n = 100; n <= 10000; n += 100) {
      final date = adoption.add(Duration(days: n - 1));
      if (date.isBefore(today)) continue;
      candidates.add(
        _Anniversary(
          upcomingLabel: '입양 $n일',
          todayLabel: '입양 $n일',
          date: date,
          daysUntil: date.difference(today).inDays,
        ),
      );
      break;
    }

    for (var n = 1; n <= 30; n++) {
      final date = DateTime(adoption.year + n, adoption.month, adoption.day);
      if (date.isBefore(today)) continue;
      candidates.add(
        _Anniversary(
          upcomingLabel: '입양 $n주년',
          todayLabel: '입양 $n주년',
          date: date,
          daysUntil: date.difference(today).inDays,
        ),
      );
      break;
    }

    final bd = pet.birthday;
    if (bd != null) {
      var bdate = DateTime(today.year, bd.month, bd.day);
      if (bdate.isBefore(today)) {
        bdate = DateTime(today.year + 1, bd.month, bd.day);
      }
      candidates.add(
        _Anniversary(
          upcomingLabel: '생일',
          todayLabel: '생일',
          date: bdate,
          daysUntil: bdate.difference(today).inDays,
        ),
      );
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
    return candidates.first;
  }

  Widget _buildDashboard(ColorScheme colorScheme, TextTheme textTheme) {
    if (_logsLoading) return const SizedBox.shrink();

    final pet = _selectedPet;
    final alerts = _vaccinationAlerts();
    final photoCount = _logs.where((l) => l.photoUrl != null).length;
    final anniversary = pet == null ? null : _nextAnniversary(pet);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_shouldShowGuestBanner) ...[
            _GuestAccountBanner(
              colorScheme: colorScheme,
              textTheme: textTheme,
              onCreateAccount: _openSignUpFromBanner,
              onDismiss: _dismissGuestBanner,
            ),
            const SizedBox(height: 8),
          ],
          if (anniversary != null && pet != null) ...[
            _AnniversaryCard(
              petName: pet.name,
              anniversary: anniversary,
              colorScheme: colorScheme,
              textTheme: textTheme,
              onTap: _openMilestones,
            ),
            const SizedBox(height: 8),
          ],
          for (final a in alerts) ...[
            _VaccinationBanner(
              alert: a,
              colorScheme: colorScheme,
              textTheme: textTheme,
              onTap: _openVaccinationsTab,
            ),
            const SizedBox(height: 8),
          ],
          _NearbyVetButton(
            colorScheme: colorScheme,
            textTheme: textTheme,
            onTap: () => showNearbyVetSheet(context),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(
                icon: Icons.edit_note_outlined,
                label: '기록 ${_logs.length}개',
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              _StatChip(
                icon: Icons.photo_outlined,
                label: '사진 $photoCount장',
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('데이터를 불러오지 못했어요.', style: textTheme.bodyLarge),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('다시 시도')),
              ],
            ),
          ),
        ),
      );
    }

    if (_selectedPet == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            '🐾 Petory',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              tooltip: '설정',
              icon: const Icon(Icons.settings_outlined),
              color: colorScheme.primary,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen(selectedPet: null)),
                );
              },
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pets, size: 64, color: colorScheme.primary),
                const SizedBox(height: 16),
                Text('반려동물을 등록해주세요.', style: textTheme.titleMedium),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _openCreatePet,
                  icon: const Icon(Icons.add),
                  label: const Text('반려동물 등록'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _redeemInviteCode,
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('초대 코드로 참여'),
                ),
                if (AuthService.instance.isAnonymous) ...[
                  const SizedBox(height: 24),
                  Text(
                    '이미 계정이 있으신가요?',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SignInScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('로그인하고 데이터 불러오기'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final pet = _selectedPet!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '🐾 ${pet.name}의 하루',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: '설정',
            icon: const Icon(Icons.settings_outlined),
            color: colorScheme.primary,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(selectedPet: pet),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: _openPetPicker,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: colorScheme.primaryContainer,
                            child: Text(
                              pet.name.characters.first,
                              style: textTheme.titleLarge?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
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
                                        pet.name,
                                        style: textTheme.titleLarge,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_drop_down,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                                Text(
                                  '${pet.species} · 함께한 지',
                                  style: textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'D+${pet.daysSinceAdoption + 1}일',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: _searchVisible ? '검색 닫기' : '기록 검색',
                          icon: Icon(
                            _searchVisible ? Icons.search_off : Icons.search,
                          ),
                          color: colorScheme.primary,
                          visualDensity: VisualDensity.compact,
                          onPressed: _toggleSearch,
                        ),
                        IconButton(
                          tooltip: '캘린더',
                          icon: const Icon(Icons.calendar_month_outlined),
                          color: colorScheme.primary,
                          visualDensity: VisualDensity.compact,
                          onPressed: _openCalendar,
                        ),
                        IconButton(
                          tooltip: '사진 갤러리',
                          icon: const Icon(Icons.photo_library_outlined),
                          color: colorScheme.primary,
                          visualDensity: VisualDensity.compact,
                          onPressed: _openGallery,
                        ),
                        IconButton(
                          tooltip: '특별한 순간',
                          icon: const Icon(Icons.celebration_outlined),
                          color: colorScheme.primary,
                          visualDensity: VisualDensity.compact,
                          onPressed: _openMilestones,
                        ),
                        IconButton(
                          tooltip: '건강 기록',
                          icon: const Icon(Icons.monitor_heart_outlined),
                          color: colorScheme.primary,
                          visualDensity: VisualDensity.compact,
                          onPressed: _openHealth,
                        ),
                        IconButton(
                          tooltip: '케어 팁',
                          icon: const Icon(Icons.tips_and_updates_outlined),
                          color: colorScheme.primary,
                          visualDensity: VisualDensity.compact,
                          onPressed: _openCareTips,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _buildDashboard(colorScheme, textTheme),
            if (_searchVisible) _buildSearchBar(colorScheme, textTheme),
            if (_hasActiveFilter) _buildFilterChips(colorScheme, textTheme),
            Expanded(
              child: _logsLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildTimeline(colorScheme, textTheme),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddLog,
        icon: const Icon(Icons.add),
        label: const Text('오늘 기록'),
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '기록 내용 검색',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '검색어 지우기',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: '날짜 범위',
            icon: const Icon(Icons.date_range),
            onPressed: _pickDateRange,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ColorScheme colorScheme, TextTheme textTheme) {
    final chips = <Widget>[];
    if (_searchQuery.trim().isNotEmpty) {
      chips.add(
        InputChip(
          avatar: const Icon(Icons.search, size: 18),
          label: Text('"${_searchQuery.trim()}"'),
          onDeleted: () {
            _searchController.clear();
            setState(() {
              _searchQuery = '';
            });
          },
        ),
      );
    }
    final range = _dateRange;
    if (range != null) {
      chips.add(
        InputChip(
          avatar: const Icon(Icons.date_range, size: 18),
          label: Text(_formatDateRangeLabel(range)),
          onDeleted: () {
            setState(() {
              _dateRange = null;
            });
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(spacing: 8, runSpacing: 4, children: chips),
    );
  }

  Widget _buildTimeline(ColorScheme colorScheme, TextTheme textTheme) {
    final logs = _filteredLogs;
    if (logs.isEmpty) {
      final message = _hasActiveFilter
          ? '검색 결과가 없어요'
          : '아직 기록이 없어요. 첫 기록을 남겨보세요!';
      return Center(
        child: Text(
          message,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (log.photoUrl != null)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PhotoViewScreen(imageUrl: log.photoUrl!),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Hero(
                      tag: log.photoUrl!,
                      child: Image.network(
                        log.photoUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 4, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(log.content, style: textTheme.bodyLarge),
                          const SizedBox(height: 8),
                          Text(
                            _formatDate(log.createdAt),
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
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
                            _openEditLog(log);
                            break;
                          case 'delete':
                            _confirmDeleteLog(log);
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
            ],
          ),
        );
      },
    );
  }
}

class _Anniversary {
  final String upcomingLabel;
  final String todayLabel;
  final DateTime date;
  final int daysUntil;

  const _Anniversary({
    required this.upcomingLabel,
    required this.todayLabel,
    required this.date,
    required this.daysUntil,
  });
}

class _AnniversaryCard extends StatelessWidget {
  final String petName;
  final _Anniversary anniversary;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  const _AnniversaryCard({
    required this.petName,
    required this.anniversary,
    required this.colorScheme,
    required this.textTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = anniversary.daysUntil == 0;
    final message = isToday
        ? '오늘은 $petName ${anniversary.todayLabel}! 🎉'
        : '🎉 ${anniversary.upcomingLabel}까지 D-${anniversary.daysUntil}';

    return Material(
      color: colorScheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.celebration_outlined,
                color: colorScheme.onTertiaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onTertiaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _VaccinationAlert {
  final Vaccination vaccination;
  final int daysUntil;

  const _VaccinationAlert(this.vaccination, this.daysUntil);
}

class _VaccinationBanner extends StatelessWidget {
  final _VaccinationAlert alert;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  const _VaccinationBanner({
    required this.alert,
    required this.colorScheme,
    required this.textTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = colorScheme.primaryContainer;
    final fg = colorScheme.onPrimaryContainer;

    final String message;
    if (alert.daysUntil == 0) {
      message = '${alert.vaccination.name} 예정일이 오늘이에요';
    } else {
      message = '${alert.vaccination.name} 예정일이 ${alert.daysUntil}일 남았어요';
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.vaccines_outlined, color: fg),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: textTheme.bodyMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbyVetButton extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  const _NearbyVetButton({
    required this.colorScheme,
    required this.textTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = colorScheme.secondaryContainer;
    final fg = colorScheme.onSecondaryContainer;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.local_hospital_outlined, color: fg),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '내 주변 동물병원 찾기',
                      style: textTheme.bodyMedium?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '지도 앱으로 바로 연결돼요',
                      style: textTheme.bodySmall?.copyWith(
                        color: fg.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestAccountBanner extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onCreateAccount;
  final VoidCallback onDismiss;

  const _GuestAccountBanner({
    required this.colorScheme,
    required this.textTheme,
    required this.onCreateAccount,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final bg = colorScheme.surfaceContainerHighest;
    final fg = colorScheme.onSurface;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            Icon(Icons.shield_moon_outlined, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '계정을 만들면 기기를 바꿔도\n데이터가 안전하게 보관돼요',
                    style: textTheme.bodyMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FilledButton.tonal(
                    onPressed: onCreateAccount,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                    ),
                    child: const Text('계정 만들기'),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '닫기',
              icon: const Icon(Icons.close),
              color: colorScheme.onSurfaceVariant,
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

class _PetPickerTile extends StatelessWidget {
  final Pet pet;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onShare;

  const _PetPickerTile({
    required this.pet,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        child: Text(
          pet.name.characters.first,
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      title: Text(pet.name),
      subtitle: Text(pet.species),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) Icon(Icons.check, color: colorScheme.primary),
          IconButton(
            tooltip: '가족 공유',
            icon: const Icon(Icons.group_add_outlined),
            onPressed: onShare,
          ),
          IconButton(
            tooltip: '수정',
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
