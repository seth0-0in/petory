import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pet.dart';
import '../services/auth_service.dart';
import '../services/export_service.dart';
import '../services/notification_service.dart';
import '../services/reminder_scheduler.dart';
import '../services/supabase_service.dart';
import '../theme/theme_controller.dart';
import 'feedback_screen.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';
import 'theme_picker_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.selectedPet});

  final Pet? selectedPet;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SupabaseService _service = SupabaseService();
  final ExportService _exportService = ExportService();
  late bool _notificationsEnabled;
  bool _toggling = false;
  bool _signingOut = false;
  bool _exporting = false;
  bool _seniorManualOn = false;
  bool _seniorToggling = false;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = NotificationService.instance.enabled;
    _authSub = AuthService.instance.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
    _loadSeniorManualOn();
  }

  Future<void> _loadSeniorManualOn() async {
    final pet = widget.selectedPet;
    if (pet == null) return;
    final value = await SeniorModeStore.isManualOn(pet.id);
    if (!mounted) return;
    setState(() {
      _seniorManualOn = value;
    });
  }

  Future<void> _onToggleSeniorManual(bool value) async {
    final pet = widget.selectedPet;
    if (pet == null || _seniorToggling) return;
    setState(() {
      _seniorToggling = true;
    });
    try {
      await SeniorModeStore.setManualOn(pet.id, value);
      if (!mounted) return;
      setState(() {
        _seniorManualOn = value;
        _seniorToggling = false;
      });
      await _rescheduleAfterSeniorChange();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _seniorToggling = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('시니어 모드 변경 실패: $e')));
    }
  }

  Future<void> _rescheduleAfterSeniorChange() async {
    await rescheduleAllReminders(_service);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _openSignUp() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SignUpScreen()),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openSignIn() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
    );
    if (mounted) setState(() {});
  }

  Future<void> _confirmSignOut() async {
    if (_signingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text(
          '로그아웃하면 새 게스트로 전환됩니다. 이 계정의 데이터는 기기에서 보이지 않게 돼요. '
          '다시 보려면 동일한 이메일로 로그인하세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() {
      _signingOut = true;
    });

    try {
      await AuthService.instance.signOutToGuest();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃되었습니다. (새 게스트로 전환)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('로그아웃 실패: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _signingOut = false;
        });
      }
    }
  }

  Future<void> _onToggleNotifications(bool value) async {
    if (_toggling) return;
    final service = NotificationService.instance;

    setState(() {
      _toggling = true;
    });

    try {
      if (value && service.isSupported) {
        final granted = await service.requestPermissions();
        if (!granted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('알림 권한이 거부되어 켤 수 없어요. 시스템 설정에서 허용해 주세요.')),
          );
          setState(() {
            _toggling = false;
          });
          return;
        }
      }

      await service.setEnabled(value);

      if (value && service.isSupported) {
        // 시니어 펫 매일 건강 체크 알림도 함께 재예약.
        await _rescheduleAfterSeniorChange();
      }

      if (!mounted) return;
      setState(() {
        _notificationsEnabled = value;
        _toggling = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _toggling = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('알림 설정 변경 실패: $e')));
    }
  }

  Future<void> _onExportData() async {
    final pet = widget.selectedPet;
    if (pet == null || _exporting) return;

    final format = await showDialog<ExportFormat>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('내보내기 형식 선택'),
          content: Text(
            '${pet.name}의 기록을 어떤 형식으로 내보낼까요?',
            style: Theme.of(ctx).textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx, ExportFormat.json),
              icon: Icon(Icons.data_object, color: scheme.primary),
              label: const Text('JSON'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, ExportFormat.csv),
              icon: const Icon(Icons.table_chart_outlined),
              label: const Text('CSV'),
            ),
          ],
        );
      },
    );

    if (format == null || !mounted) return;

    setState(() {
      _exporting = true;
    });

    try {
      final bundle = await _exportService.exportPet(pet, format);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bundle.bytes,
              name: bundle.filename,
              mimeType: bundle.mimeType,
            ),
          ],
          fileNameOverrides: [bundle.filename],
          subject: '${pet.name} 기록 내보내기',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내보내기에 실패했어요')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final service = NotificationService.instance;
    final supported = service.isSupported;
    final auth = AuthService.instance;

    final pet = widget.selectedPet;
    final showSeniorToggle = pet != null && pet.birthday == null;

    return Scaffold(
      appBar: AppBar(title: const Text('⚙️ 설정')),
      body: ListView(
        children: [
          _buildAccountSection(auth, colorScheme, textTheme),
          const Divider(height: 1),
          SwitchListTile(
            secondary: Icon(
              Icons.notifications_outlined,
              color: supported ? colorScheme.primary : colorScheme.outline,
            ),
            title: const Text('알림'),
            subtitle: Text(
              supported
                  ? '예방접종, 기념일을 기기 알림으로 받아요'
                  : '이 환경에서는 알림이 지원되지 않아요',
            ),
            value: supported && _notificationsEnabled,
            onChanged: supported && !_toggling ? _onToggleNotifications : null,
          ),
          const Divider(height: 1),
          if (showSeniorToggle) ...[
            SwitchListTile(
              secondary: Icon(
                Icons.elderly_outlined,
                color: colorScheme.primary,
              ),
              title: Text('${pet.name} 시니어 모드'),
              subtitle: const Text(
                '생일이 없어 입양일로 추정 중이에요. 시니어 펫인데 자동 판정이 틀렸다면 켜주세요.',
              ),
              value: _seniorManualOn,
              onChanged: _seniorToggling ? null : _onToggleSeniorManual,
            ),
            const Divider(height: 1),
          ],
          ListTile(
            leading: Icon(
              Icons.palette_outlined,
              color: colorScheme.primary,
            ),
            title: const Text('테마 색 변경'),
            subtitle: const Text('앱 전체 색을 골라보세요'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showThemePickerSheet(context),
          ),
          const Divider(height: 1),
          _buildThemeModeTile(colorScheme, textTheme),
          const Divider(height: 1),
          _buildExportTile(colorScheme),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              Icons.mark_email_unread_outlined,
              color: colorScheme.primary,
            ),
            title: const Text('문의 · 피드백'),
            subtitle: const Text('개선 제안, 버그 신고 등을 보내주세요'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FeedbackScreen()),
              );
            },
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildThemeModeTile(ColorScheme colorScheme, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.brightness_6_outlined,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '화면 모드',
                      style: textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '라이트 · 다크 · 시스템 기본 중에서 선택',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (context, mode, _) {
              return SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('시스템'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('라이트'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('다크'),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (selected) {
                    final next = selected.first;
                    if (next != mode) setThemeMode(next);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExportTile(ColorScheme colorScheme) {
    final pet = widget.selectedPet;
    final enabled = pet != null && !_exporting;
    return ListTile(
      leading: Icon(
        Icons.ios_share,
        color: enabled ? colorScheme.primary : colorScheme.outline,
      ),
      title: const Text('데이터 내보내기'),
      subtitle: Text(
        pet == null
            ? '내보낼 반려동물을 먼저 선택해 주세요'
            : '${pet.name}의 기록을 CSV 또는 JSON으로 내보내요',
      ),
      trailing: _exporting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: enabled ? _onExportData : null,
    );
  }

  Widget _buildAccountSection(
    AuthService auth,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final isAccount = auth.isAccount;
    final email = auth.currentEmail;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isAccount
                    ? Icons.account_circle
                    : Icons.person_outline,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '계정',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isAccount
                  ? colorScheme.secondaryContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: isAccount
                ? Row(
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '로그인됨',
                              style: textTheme.labelLarge?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email ?? '이메일 인증 대기 중',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Text(
                    '게스트로 사용 중 — 계정을 만들면 기기를 바꿔도 데이터가 보존돼요.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          if (isAccount)
            OutlinedButton.icon(
              onPressed: _signingOut ? null : _confirmSignOut,
              icon: _signingOut
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout),
              label: const Text('로그아웃'),
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _openSignUp,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('계정 만들기'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openSignIn,
                    icon: const Icon(Icons.login),
                    label: const Text('로그인'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
