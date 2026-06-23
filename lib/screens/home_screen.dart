import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/log_entry.dart';
import '../models/log_media.dart';
import '../models/pet.dart';
import '../models/vaccination.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/pet_session.dart';
import '../services/reminder_scheduler.dart';
import '../services/supabase_service.dart';
import 'add_log_screen.dart';
import 'calendar_screen.dart';
import 'care_tips_screen.dart';
import 'edit_pet_screen.dart';
import 'family_share_screen.dart';
import 'gallery_screen.dart';
import 'log_detail_screen.dart';
import 'milestones_screen.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';
import 'todo_screen.dart';

const String _kGuestBannerDismissedPrefsKey = 'guest_banner_dismissed';

class HomeScreen extends StatefulWidget {
  // 하단 탭 전환 콜백 (MainScreen이 주입). null이면 탭 전환 동작 없음.
  final void Function(int tabIndex)? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseService _service = SupabaseService();
  final ImagePicker _picker = ImagePicker();

  List<Pet> _pets = [];
  Pet? _selectedPet;
  List<LogEntry> _logs = [];
  List<Vaccination> _vaccinations = [];
  int _todayTodoCount = 0;
  bool _seniorManualOn = false;
  bool _loading = true;
  String? _error;
  bool _uploadingAvatar = false;

  StreamSubscription<AuthState>? _authSub;
  String? _lastAuthUserId;
  bool _guestBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _lastAuthUserId = AuthService.instance.currentUser?.id;
    _load();
    _loadGuestBannerState();
    _authSub = AuthService.instance.onAuthStateChange.listen(_onAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeRequestNotificationPermission();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
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

  bool get _shouldShowGuestBanner =>
      AuthService.instance.isAnonymous &&
      _pets.isNotEmpty &&
      !_guestBannerDismissed;

  void _onAuthChanged(AuthState state) {
    final newId = state.session?.user.id;
    if (newId == _lastAuthUserId) return;
    _lastAuthUserId = newId;
    if (!mounted) return;
    setState(() {
      _pets = [];
      _selectedPet = null;
      _logs = [];
      _vaccinations = [];
      _seniorManualOn = false;
    });
    PetSession.instance.clear();
    _load();
  }

  Future<void> _maybeRequestNotificationPermission() async {
    final service = NotificationService.instance;
    if (!service.isSupported || !service.enabled) return;
    await service.requestPermissions();
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
      bool seniorManualOn = false;
      if (pets.isNotEmpty) {
        selected = pets.first;
        final results = await Future.wait([
          _service.fetchLogs(selected.id),
          _service.fetchVaccinations(selected.id),
          SeniorModeStore.isManualOn(selected.id),
        ]);
        logs = results[0] as List<LogEntry>;
        vaccinations = results[1] as List<Vaccination>;
        seniorManualOn = results[2] as bool;
      }
      if (!mounted) return;
      setState(() {
        _pets = pets;
        _selectedPet = selected;
        _logs = logs;
        _vaccinations = vaccinations;
        _seniorManualOn = seniorManualOn;
        _loading = false;
      });
      PetSession.instance.setPets(pets);
      PetSession.instance.setSelectedPet(selected);
      _rescheduleNotifications();
      _refreshTodayTodoCount();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refreshTodayTodoCount() async {
    final count = await countTodayOpenTodos(_service);
    if (!mounted) return;
    setState(() {
      _todayTodoCount = count;
    });
  }

  Future<void> _rescheduleNotifications() async {
    await rescheduleAllReminders(_service);
  }

  Future<void> _selectPet(Pet pet) async {
    setState(() {
      _selectedPet = pet;
      _logs = [];
      _vaccinations = [];
    });
    PetSession.instance.setSelectedPet(pet);
    try {
      final results = await Future.wait([
        _service.fetchLogs(pet.id),
        _service.fetchVaccinations(pet.id),
        SeniorModeStore.isManualOn(pet.id),
      ]);
      if (!mounted) return;
      // 도중에 펫이 바뀌었으면 결과 무시.
      if (_selectedPet?.id != pet.id) return;
      setState(() {
        _logs = results[0] as List<LogEntry>;
        _vaccinations = results[1] as List<Vaccination>;
        _seniorManualOn = results[2] as bool;
      });
    } catch (_) {
      // 무시.
    }
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
                child:
                    Text('펫 선택', style: Theme.of(ctx).textTheme.titleMedium),
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
        builder: (_) =>
            FamilyShareScreen(petId: pet.id, petName: pet.name),
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
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('참여'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    try {
      final res = await _service.redeemPetInvite(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.petName == null ? '참여했어요!' : '${res.petName}의 가족이 되었어요!',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('참여 실패: $e')),
      );
    }
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
    PetSession.instance.setPets(_pets);
    await _selectPet(created);
    _rescheduleNotifications();
  }

  Future<void> _openEditPet(Pet pet) async {
    final updated = await Navigator.push<Pet>(
      context,
      MaterialPageRoute(builder: (_) => EditPetScreen(pet: pet)),
    );
    if (updated == null) return;
    if (!mounted) return;
    setState(() {
      _pets = _pets.map((p) => p.id == updated.id ? updated : p).toList();
      if (_selectedPet?.id == updated.id) {
        _selectedPet = updated;
      }
    });
    PetSession.instance.setPets(_pets);
    if (PetSession.instance.selectedPet.value?.id == updated.id) {
      PetSession.instance.setSelectedPet(updated);
    }
    PetSession.instance.bumpRev();
    _rescheduleNotifications();
  }

  void _openSearchTab() {
    widget.onNavigateToTab?.call(1);
  }

  Future<void> _changeProfileImage(Pet pet) async {
    if (_uploadingAvatar) return;
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final mime = picked.mimeType ?? 'image/jpeg';
    final extIdx = picked.name.lastIndexOf('.');
    final ext = (extIdx > 0 && extIdx < picked.name.length - 1)
        ? picked.name.substring(extIdx + 1).toLowerCase()
        : 'jpg';

    setState(() {
      _uploadingAvatar = true;
    });
    try {
      final url = await _service.uploadPetProfileImage(
        bytes,
        petId: pet.id,
        contentType: mime,
        extension: ext,
      );
      final updated = await _service.updatePetProfileImage(pet.id, url);
      if (!mounted) return;
      setState(() {
        _pets = _pets.map((p) => p.id == updated.id ? updated : p).toList();
        if (_selectedPet?.id == updated.id) _selectedPet = updated;
        _uploadingAvatar = false;
      });
      PetSession.instance.setPets(_pets);
      if (PetSession.instance.selectedPet.value?.id == updated.id) {
        PetSession.instance.setSelectedPet(updated);
      }
      PetSession.instance.bumpRev();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingAvatar = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('프로필 사진 변경 실패: $e')),
      );
    }
  }

  void _openCalendar() {
    final pet = _selectedPet;
    if (pet == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarScreen(pet: pet),
      ),
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

  void _openMilestones() {
    final pet = _selectedPet;
    if (pet == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MilestonesScreen(petId: pet.id)),
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

  Future<void> _openTodos() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TodoScreen(
          pets: _pets,
          defaultPet: _selectedPet,
        ),
      ),
    );
    if (!mounted) return;
    _refreshTodayTodoCount();
  }

  Future<void> _openAddLog() async {
    final pet = _selectedPet;
    if (pet == null) return;
    final result = await Navigator.push<LogEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => AddLogScreen(petId: pet.id),
      ),
    );
    if (result == null) return;
    if (!mounted) return;
    setState(() {
      _logs = [result, ..._logs];
    });
  }

  void _openLogDetail(LogEntry log) {
    final pet = _selectedPet;
    if (pet == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LogDetailScreen(pet: pet, log: log),
      ),
    );
  }

  // 가장 가까운 다가오는 기념일/생일/D-day 한 개를 계산.
  _Anniversary? _nextAnniversary(Pet pet) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _Anniversary? best;

    void considerCandidate({
      required String upcomingLabel,
      required String todayLabel,
      required DateTime date,
    }) {
      final d = DateTime(date.year, date.month, date.day);
      if (d.isBefore(today)) return;
      final diff = d.difference(today).inDays;
      if (best == null || diff < best!.daysUntil) {
        best = _Anniversary(
          upcomingLabel: upcomingLabel,
          todayLabel: todayLabel,
          date: d,
          daysUntil: diff,
        );
      }
    }

    final adoption = DateTime(
      pet.adoptionDate.year,
      pet.adoptionDate.month,
      pet.adoptionDate.day,
    );
    for (var n = 100; n <= 20000; n += 100) {
      final date = adoption.add(Duration(days: n - 1));
      if (date.isBefore(today)) continue;
      considerCandidate(
        upcomingLabel: '입양 $n일',
        todayLabel: '오늘은 입양 $n일!',
        date: date,
      );
      break;
    }
    for (var n = 1; n <= 30; n++) {
      final date =
          DateTime(adoption.year + n, adoption.month, adoption.day);
      if (date.isBefore(today)) continue;
      considerCandidate(
        upcomingLabel: '입양 $n주년',
        todayLabel: '오늘은 입양 $n주년!',
        date: date,
      );
      break;
    }
    final bd = pet.birthday;
    if (bd != null) {
      for (var n = 0; n <= 5; n++) {
        final date = DateTime(today.year + n, bd.month, bd.day);
        if (date.isBefore(today)) continue;
        considerCandidate(
          upcomingLabel: '${pet.name} 생일',
          todayLabel: '오늘은 ${pet.name} 생일! 🎂',
          date: date,
        );
        break;
      }
    }
    return best;
  }

  // 가장 임박한 미접종/접종 예정 백신 1개.
  _VaccinationAlert? _topVaccinationAlert() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _VaccinationAlert? best;
    for (final v in _vaccinations) {
      if (v.administeredAt != null) continue;
      final due = v.nextDueAt;
      if (due == null) continue;
      final dueDate = DateTime(due.year, due.month, due.day);
      final diff = dueDate.difference(today).inDays;
      // 14일 이내거나 이미 기한 지남.
      if (diff > 14) continue;
      if (best == null || diff < best!.daysUntil) {
        best = _VaccinationAlert(
          name: v.name,
          dueDate: dueDate,
          daysUntil: diff,
        );
      }
    }
    return best;
  }

  Future<void> _openSignUpFromBanner() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SignUpScreen()),
    );
    if (!mounted) return;
    setState(() {});
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
    final anniversary = _nextAnniversary(pet);
    final topVacAlert = _topVaccinationAlert();
    final recentLogs = _logs.take(3).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🐾 Petory',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          _TodoAppBarAction(
            count: _todayTodoCount,
            colorScheme: colorScheme,
            onTap: _openTodos,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _buildPetHeader(pet, colorScheme, textTheme),
            const SizedBox(height: 4),
            _buildActionIcons(colorScheme),
            const Divider(height: 24),
            if (_shouldShowGuestBanner) ...[
              _GuestAccountBanner(
                colorScheme: colorScheme,
                textTheme: textTheme,
                onCreateAccount: _openSignUpFromBanner,
                onDismiss: _dismissGuestBanner,
              ),
              const SizedBox(height: 8),
            ],
            if (_todayTodoCount > 0) ...[
              _TodayTodoBanner(
                count: _todayTodoCount,
                colorScheme: colorScheme,
                textTheme: textTheme,
                onTap: _openTodos,
              ),
              const SizedBox(height: 8),
            ],
            if (anniversary != null) ...[
              _AnniversaryCard(
                petName: pet.name,
                anniversary: anniversary,
                colorScheme: colorScheme,
                textTheme: textTheme,
                onTap: _openMilestones,
              ),
              const SizedBox(height: 8),
            ],
            if (topVacAlert != null) ...[
              _VaccinationBanner(
                alert: topVacAlert,
                colorScheme: colorScheme,
                textTheme: textTheme,
                onTap: () => widget.onNavigateToTab?.call(2),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.edit_note_outlined,
                    size: 20, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  '최근 일기',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => widget.onNavigateToTab?.call(1),
                  child: const Text('전체 보기'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (recentLogs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    '아직 기록이 없어요.\n첫 기록을 남겨보세요!',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              for (final log in recentLogs) ...[
                _RecentLogPreview(
                  log: log,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  onTap: () => _openLogDetail(log),
                ),
                const SizedBox(height: 8),
              ],
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

  Widget _buildPetHeader(Pet pet, ColorScheme colorScheme, TextTheme textTheme) {
    return InkWell(
      onTap: _openPetPicker,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            _PetAvatar(
              pet: pet,
              radius: 28,
              uploading: _uploadingAvatar,
              colorScheme: colorScheme,
              textTheme: textTheme,
              onTap: () => _changeProfileImage(pet),
              showCameraBadge: true,
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
                          style: textTheme.titleLarge?.copyWith(
                            color: pet.isRainbowBridge
                                ? Colors.deepPurple.shade400
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (pet.isRainbowBridge) ...[
                        const SizedBox(width: 4),
                        const Text('🌈', style: TextStyle(fontSize: 18)),
                      ],
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  Text(
                    pet.isRainbowBridge
                        ? '${pet.species} · 함께한 추억'
                        : '${pet.species} · 함께한 지',
                    style: textTheme.bodySmall?.copyWith(
                      color: pet.isRainbowBridge
                          ? Colors.deepPurple.shade300
                          : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              pet.isRainbowBridge
                  ? '추억 ${pet.daysSinceAdoption + 1}일'
                  : 'D+${pet.daysSinceAdoption + 1}일',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: pet.isRainbowBridge ? 16 : null,
                color: pet.isRainbowBridge
                    ? Colors.deepPurple.shade400
                    : colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcons(ColorScheme colorScheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: '기록 검색',
            icon: const Icon(Icons.search),
            color: colorScheme.primary,
            visualDensity: VisualDensity.compact,
            onPressed: _openSearchTab,
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
            tooltip: '케어 팁',
            icon: const Icon(Icons.tips_and_updates_outlined),
            color: colorScheme.primary,
            visualDensity: VisualDensity.compact,
            onPressed: _openCareTips,
          ),
          IconButton(
            tooltip: '할 일',
            icon: const Icon(Icons.checklist_rounded),
            color: colorScheme.primary,
            visualDensity: VisualDensity.compact,
            onPressed: _openTodos,
          ),
        ],
      ),
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

class _VaccinationAlert {
  final String name;
  final DateTime dueDate;
  final int daysUntil;
  const _VaccinationAlert({
    required this.name,
    required this.dueDate,
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
    final label =
        isToday ? anniversary.todayLabel : '${anniversary.upcomingLabel}';
    final sub = isToday
        ? '$petName와 함께한 특별한 날이에요'
        : 'D-${anniversary.daysUntil} (${anniversary.date.month}/${anniversary.date.day})';
    return Material(
      color: colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Text('🎉', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSecondaryContainer
                            .withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: colorScheme.onSecondaryContainer),
            ],
          ),
        ),
      ),
    );
  }
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
    final overdue = alert.daysUntil < 0;
    final isToday = alert.daysUntil == 0;
    final label = overdue
        ? '${alert.name} 접종이 ${alert.daysUntil.abs()}일 지났어요'
        : isToday
            ? '오늘 ${alert.name} 접종일이에요'
            : '${alert.name} 접종 D-${alert.daysUntil}';
    final color = overdue
        ? colorScheme.errorContainer
        : colorScheme.primaryContainer;
    final onColor = overdue
        ? colorScheme.onErrorContainer
        : colorScheme.onPrimaryContainer;
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Text(overdue ? '⚠️' : '💉',
                  style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: onColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${alert.dueDate.year}.${alert.dueDate.month.toString().padLeft(2, '0')}.${alert.dueDate.day.toString().padLeft(2, '0')} 예정',
                      style: textTheme.bodySmall?.copyWith(
                        color: onColor.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: onColor),
            ],
          ),
        ),
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
    return Material(
      color: colorScheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Icon(Icons.cloud_outlined,
                color: colorScheme.onTertiaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '계정을 만들면 기기 간에 데이터가 동기화돼요',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: onCreateAccount,
                        child: const Text('계정 만들기'),
                      ),
                      TextButton(
                        onPressed: onDismiss,
                        child: const Text('나중에'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayTodoBanner extends StatelessWidget {
  final int count;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  const _TodayTodoBanner({
    required this.count,
    required this.colorScheme,
    required this.textTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Text('📋', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '오늘 할 일 $count개',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '체크하지 않은 할 일이 있어요. 탭해서 확인해보세요.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onTertiaryContainer
                            .withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onTertiaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodoAppBarAction extends StatelessWidget {
  final int count;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _TodoAppBarAction({
    required this.count,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: '할 일',
          icon: const Icon(Icons.checklist_rounded),
          color: colorScheme.primary,
          onPressed: onTap,
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
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
    final purple = Colors.deepPurple.shade400;

    final leading = _PetAvatar(
      pet: pet,
      radius: 20,
      uploading: false,
      colorScheme: colorScheme,
      textTheme: textTheme,
      onTap: null,
      showCameraBadge: false,
    );

    final title = pet.isRainbowBridge
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  pet.name,
                  style: TextStyle(color: purple, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Text('🌈', style: TextStyle(fontSize: 14)),
            ],
          )
        : Text(pet.name);

    final subtitle = pet.isRainbowBridge
        ? Text(
            '${pet.species} · 추모 중',
            style: TextStyle(color: purple.withValues(alpha: 0.8)),
          )
        : Text(pet.species);

    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected)
            Icon(
              Icons.check,
              color: pet.isRainbowBridge ? purple : colorScheme.primary,
            ),
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

class _RecentLogPreview extends StatelessWidget {
  final LogEntry log;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  const _RecentLogPreview({
    required this.log,
    required this.colorScheme,
    required this.textTheme,
    required this.onTap,
  });

  String _shortDate(DateTime t) {
    final y = t.year.toString().padLeft(4, '0');
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }

  @override
  Widget build(BuildContext context) {
    final media = log.displayMedia;
    final hasMedia = media.isNotEmpty;
    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasMedia)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 70,
                    height: 70,
                    child: _PreviewThumb(
                      media: media.first,
                      colorScheme: colorScheme,
                    ),
                  ),
                )
              else
                Container(
                  width: 70,
                  height: 70,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.edit_note_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.content,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          _shortDate(log.createdAt),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (log.likeCount > 0) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.favorite,
                              size: 12, color: Colors.red.shade400),
                          const SizedBox(width: 3),
                          Text(
                            '${log.likeCount}',
                            style: textTheme.bodySmall?.copyWith(
                              color: Colors.red.shade400,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewThumb extends StatelessWidget {
  final LogMedia media;
  final ColorScheme colorScheme;

  const _PreviewThumb({required this.media, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    if (media.isVideo) {
      return Container(
        color: Colors.black87,
        alignment: Alignment.center,
        child: const Icon(
          Icons.play_circle_fill,
          color: Colors.white70,
          size: 24,
        ),
      );
    }
    return Image.network(
      media.mediaUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: colorScheme.surface,
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image_outlined,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _PetAvatar extends StatelessWidget {
  final Pet pet;
  final double radius;
  final bool uploading;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  // null이면 비활성 (자체 탭 없음). 그렇지 않으면 탭 시 콜백 호출.
  final VoidCallback? onTap;
  final bool showCameraBadge;

  const _PetAvatar({
    required this.pet,
    required this.radius,
    required this.uploading,
    required this.colorScheme,
    required this.textTheme,
    required this.onTap,
    required this.showCameraBadge,
  });

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final purple = Colors.deepPurple.shade400;
    final initial = pet.name.isEmpty ? '🐾' : pet.name.characters.first;
    final url = pet.profileImageUrl;

    Widget avatarContent = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url != null
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(initial, purple),
              )
            : _fallback(initial, purple),
      ),
    );

    if (pet.isRainbowBridge) {
      avatarContent = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.33, 0.59, 0.11, 0, 0,
          0.33, 0.59, 0.11, 0, 0,
          0.33, 0.59, 0.11, 0, 0,
          0,    0,    0,    1, 0,
        ]),
        child: avatarContent,
      );
    }

    final stack = Stack(
      clipBehavior: Clip.none,
      children: [
        avatarContent,
        if (uploading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.35),
              ),
              alignment: Alignment.center,
              child: SizedBox(
                width: radius * 0.7,
                height: radius * 0.7,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        if (showCameraBadge && !uploading)
          Positioned(
            right: -2,
            bottom: -2,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.surface, width: 1.5),
                ),
                child: Icon(
                  Icons.photo_camera_outlined,
                  size: radius * 0.45,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ),
      ],
    );

    if (onTap == null) return stack;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: stack,
    );
  }

  Widget _fallback(String initial, Color purple) {
    final bg = pet.isRainbowBridge
        ? Colors.deepPurple.withValues(alpha: 0.22)
        : colorScheme.primaryContainer;
    final fg = pet.isRainbowBridge ? purple : colorScheme.onPrimaryContainer;
    return Container(
      color: bg,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.9,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
