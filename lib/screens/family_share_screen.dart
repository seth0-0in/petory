import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pet_member.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import 'sign_up_screen.dart';

class FamilyShareScreen extends StatefulWidget {
  final String petId;
  final String petName;

  const FamilyShareScreen({
    super.key,
    required this.petId,
    required this.petName,
  });

  @override
  State<FamilyShareScreen> createState() => _FamilyShareScreenState();
}

class _FamilyShareScreenState extends State<FamilyShareScreen> {
  final SupabaseService _service = SupabaseService();

  bool _loading = true;
  String? _error;
  List<PetMember> _members = [];

  String? _inviteCode;
  bool _creatingInvite = false;
  bool _leaving = false;

  String? get _currentUid =>
      Supabase.instance.client.auth.currentUser?.id;

  PetMember? get _me {
    final uid = _currentUid;
    if (uid == null) return null;
    for (final m in _members) {
      if (m.userId == uid) return m;
    }
    return null;
  }

  bool get _isOwner => _me?.role == PetMemberRole.owner;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final members = await _service.fetchPetMembers(widget.petId);
      if (!mounted) return;
      setState(() {
        _members = members;
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

  Future<void> _createInvite() async {
    if (_creatingInvite) return;
    setState(() {
      _creatingInvite = true;
    });
    try {
      final code = await _service.createPetInvite(widget.petId);
      if (!mounted) return;
      setState(() {
        _inviteCode = code;
        _creatingInvite = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _creatingInvite = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('초대 코드 생성 실패: $e')));
    }
  }

  Future<void> _copyInvite() async {
    final code = _inviteCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('초대 코드를 복사했어요.')));
  }

  Future<void> _confirmRemove(PetMember member) async {
    final label = member.email ?? '게스트';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('멤버 내보내기'),
        content: Text('$label 님을 ${widget.petName}의 공유에서 내보낼까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('내보내기'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.removePetMember(widget.petId, member.userId);
      if (!mounted) return;
      setState(() {
        _members = _members.where((m) => m.userId != member.userId).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('내보내기 실패: $e')));
    }
  }

  Future<void> _confirmLeave() async {
    if (_leaving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('공유 나가기'),
        content: Text(
          '${widget.petName}의 공유에서 나갈까요? 이 기기에서는 더 이상 표시되지 않아요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _leaving = true;
    });

    try {
      await _service.leavePet(widget.petId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _leaving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('나가기 실패: $e')));
    }
  }

  Future<void> _openSignUp() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SignUpScreen()),
    );
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.petName} 가족 공유')),
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
    final isAnonymous = AuthService.instance.isAnonymous;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (isAnonymous) ...[
          _buildGuestBanner(cs, tt),
          const SizedBox(height: 16),
        ],
        Text(
          '멤버 (${_members.length})',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < _members.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _buildMemberTile(_members[i], cs, tt),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '초대 코드',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _buildInviteCard(cs, tt),
        if (_me != null && !_isOwner) ...[
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _leaving ? null : _confirmLeave,
            icon: _leaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            label: const Text('공유 나가기'),
          ),
        ],
      ],
    );
  }

  Widget _buildGuestBanner(ColorScheme cs, TextTheme tt) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.shield_moon_outlined,
            color: cs.onTertiaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '게스트로 사용 중',
                  style: tt.labelLarge?.copyWith(
                    color: cs.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '계정을 만들면 다른 기기에서도 공유가 유지돼요.',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: _openSignUp,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('계정 만들기'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(
    PetMember member,
    ColorScheme cs,
    TextTheme tt,
  ) {
    final isMe = member.userId == _currentUid;
    final isOwnerRow = member.role == PetMemberRole.owner;
    final canRemove = _isOwner && !isOwnerRow;

    final label = member.email ?? '게스트';
    final badgeColor = isOwnerRow ? cs.primary : cs.tertiary;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.primaryContainer,
        child: Icon(
          isOwnerRow
              ? Icons.verified_user_outlined
              : Icons.person_outline,
          color: cs.onPrimaryContainer,
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 6),
            Text(
              '(나)',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            member.role.label,
            style: tt.labelSmall?.copyWith(
              color: badgeColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      isThreeLine: false,
      subtitleTextStyle: tt.labelSmall,
      trailing: canRemove
          ? IconButton(
              tooltip: '내보내기',
              icon: Icon(Icons.person_remove_outlined, color: cs.error),
              onPressed: () => _confirmRemove(member),
            )
          : null,
    );
  }

  Widget _buildInviteCard(ColorScheme cs, TextTheme tt) {
    final code = _inviteCode;
    if (code == null) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '가족에게 공유할 초대 코드를 만들어보세요.',
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _creatingInvite ? null : _createInvite,
                icon: _creatingInvite
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_link),
                label: const Text('초대 코드 만들기'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: cs.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '초대 코드',
              style: tt.labelLarge?.copyWith(
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              code,
              style: tt.headlineMedium?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '7일간 유효해요. 가족이 "코드로 참여"에서 입력하면 함께 볼 수 있어요.',
              style: tt.bodySmall?.copyWith(
                color: cs.onPrimaryContainer,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _copyInvite,
                    icon: const Icon(Icons.copy),
                    label: const Text('복사'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _creatingInvite ? null : _createInvite,
                    icon: const Icon(Icons.refresh),
                    label: const Text('새로 만들기'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
