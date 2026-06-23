import 'package:flutter/material.dart';

import '../models/pet.dart';
import '../services/notification_service.dart';
import '../services/pet_session.dart';
import 'care_screen.dart';
import 'diary_screen.dart';
import 'health_tab.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.tapNotifier.addListener(_onNotificationTap);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onNotificationTap());
  }

  @override
  void dispose() {
    NotificationService.instance.tapNotifier.removeListener(_onNotificationTap);
    super.dispose();
  }

  void _switchTab(int next) {
    if (_index == next) return;
    setState(() {
      _index = next;
    });
  }

  void _onNotificationTap() {
    final tap = NotificationService.instance.tapNotifier.value;
    if (tap == null) return;
    NotificationService.instance.consumeTap();
    // 알림 종류에 따라 해당 탭으로 이동.
    switch (tap.type) {
      case 'health':
      case 'medication':
      case 'daily_health':
      case 'vet_visit':
      case 'grooming':
      case 'heat':
        _switchTab(2);
      case 'todo':
        _switchTab(0); // 홈에 오늘 할 일 배너 노출
      default:
        _switchTab(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: _index,
          children: [
            HomeScreen(onNavigateToTab: _switchTab),
            const DiaryScreen(),
            const HealthTab(),
            const CareScreen(),
            ValueListenableBuilder<Pet?>(
              valueListenable: PetSession.instance.selectedPet,
              builder: (context, pet, _) {
                return SettingsScreen(selectedPet: pet);
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _switchTab,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: colorScheme.primary),
            label: '홈',
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book, color: colorScheme.primary),
            label: '일기',
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite, color: colorScheme.primary),
            label: '건강',
          ),
          NavigationDestination(
            icon: const Icon(Icons.pets_outlined),
            selectedIcon: Icon(Icons.pets, color: colorScheme.primary),
            label: '케어',
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: colorScheme.primary),
            label: '설정',
          ),
        ],
      ),
    );
  }
}
