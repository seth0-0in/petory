import 'package:flutter/material.dart';

import '../models/pet.dart';
import '../services/pet_session.dart';
import 'cage_management_screen.dart';
import 'care_tips_screen.dart';
import 'emergency_guide_screen.dart';
import 'nearby_vet_sheet.dart';
import 'pet_friendly_places_sheet.dart';
import 'rainbow_bridge_screen.dart';

class CareScreen extends StatelessWidget {
  const CareScreen({super.key});

  static bool _isSmallAnimal(Pet pet) => pet.species == '기타';

  void _openCareTips(BuildContext context, Pet? pet) {
    if (pet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('펫을 먼저 선택해 주세요.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CareTipsScreen(pet: pet)),
    );
  }

  void _openCage(BuildContext context, Pet? pet) {
    if (pet == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CageManagementScreen(petId: pet.id, petName: pet.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('🌿 케어')),
      body: ValueListenableBuilder<Pet?>(
        valueListenable: PetSession.instance.selectedPet,
        builder: (context, pet, _) {
          final showCage = pet != null && _isSmallAnimal(pet);
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _SectionHeader(
                  icon: '📍',
                  title: '주변 찾기',
                  textTheme: textTheme,
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 8),
                _CareTile(
                  icon: Icons.local_hospital_outlined,
                  emoji: '🏥',
                  title: '내 주변 동물병원 찾기',
                  subtitle: '현재 위치 주변의 병원 찾기',
                  colorScheme: colorScheme,
                  onTap: () => showNearbyVetSheet(context),
                ),
                const SizedBox(height: 8),
                _CareTile(
                  icon: Icons.place_outlined,
                  emoji: '🐾',
                  title: '반려동물 동반 장소 찾기',
                  subtitle: '같이 갈 수 있는 카페·공원·식당',
                  colorScheme: colorScheme,
                  onTap: () => showPetFriendlyPlacesSheet(context),
                ),
                const SizedBox(height: 20),
                _SectionHeader(
                  icon: '📘',
                  title: '돌봄 가이드',
                  textTheme: textTheme,
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 8),
                _CareTile(
                  icon: Icons.tips_and_updates_outlined,
                  emoji: '🌿',
                  title: '나이·종별 케어 팁',
                  subtitle: pet == null
                      ? '펫을 선택하면 맞춤 팁이 보여요'
                      : '${pet.name} 맞춤 케어 팁',
                  colorScheme: colorScheme,
                  enabled: pet != null,
                  onTap: () => _openCareTips(context, pet),
                ),
                const SizedBox(height: 8),
                _CareTile(
                  icon: Icons.emergency_outlined,
                  emoji: '🚨',
                  title: '위급상황 대처 가이드',
                  subtitle: '응급 상황 대처 지침을 빠르게 확인',
                  accent: Colors.red.shade600,
                  colorScheme: colorScheme,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EmergencyGuideScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _CareTile(
                  icon: Icons.favorite_outline,
                  emoji: '🌈',
                  title: '무지개다리 정보',
                  subtitle: '펫로스 안내 · 장례 절차 · 추모 공간',
                  accent: Colors.deepPurple.shade400,
                  colorScheme: colorScheme,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RainbowBridgeScreen(),
                      ),
                    );
                  },
                ),
                if (showCage) ...[
                  const SizedBox(height: 20),
                  _SectionHeader(
                    icon: '🏠',
                    title: '소동물 케어',
                    textTheme: textTheme,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 8),
                  _CareTile(
                    icon: Icons.cabin_outlined,
                    emoji: '🏠',
                    title: '케이지 관리',
                    subtitle: '청소·먹이·물 관리 일정',
                    colorScheme: colorScheme,
                    onTap: () => _openCage(context, pet),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String icon;
  final String title;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.textTheme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            title,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CareTile extends StatelessWidget {
  final IconData icon;
  final String emoji;
  final String title;
  final String subtitle;
  final ColorScheme colorScheme;
  final VoidCallback onTap;
  final Color? accent;
  final bool enabled;

  const _CareTile({
    required this.icon,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.colorScheme,
    required this.onTap,
    this.accent,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final iconColor =
        enabled ? (accent ?? colorScheme.primary) : colorScheme.outline;
    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            title,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: enabled
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
