import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/notification_service.dart';
import 'supabase_config.dart';
import 'theme/theme_controller.dart';

// ignore_for_file: avoid_print

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('ko_KR');
  await loadSavedSeedColor();
  await loadSavedThemeMode();
  await NotificationService.instance.init();

  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool(kOnboardingDonePrefsKey) ?? false;

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
  );

  final auth = Supabase.instance.client.auth;
  if (auth.currentUser == null) {
    try {
      await auth.signInAnonymously();
    } catch (error, stackTrace) {
      print('anon sign-in FAILED: $error');
      print(stackTrace);
    }
  }

  runApp(PetDiaryApp(showOnboarding: !onboardingDone));
}

class PetDiaryApp extends StatefulWidget {
  final bool showOnboarding;

  const PetDiaryApp({super.key, required this.showOnboarding});

  @override
  State<PetDiaryApp> createState() => _PetDiaryAppState();
}

class _PetDiaryAppState extends State<PetDiaryApp> {
  late bool _showOnboarding = widget.showOnboarding;

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  StreamSubscription<AuthState>? _authSub;
  bool _handlingLoginCallback = false;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _listenAuthChanges();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _handleIncomingUri(initial);
      }
    } catch (error, stackTrace) {
      print('initial deep link FAILED: $error');
      print(stackTrace);
    }

    _linkSub = _appLinks.uriLinkStream.listen(
      _handleIncomingUri,
      onError: (Object error, StackTrace stackTrace) {
        print('deep link stream error: $error');
        print(stackTrace);
      },
    );
  }

  void _handleIncomingUri(Uri uri) {
    if (uri.scheme == 'com.ysj50830.petory' && uri.host == 'login-callback') {
      _handlingLoginCallback = true;
    }
  }

  void _listenAuthChanges() {
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (!_handlingLoginCallback) return;
      final event = state.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.userUpdated ||
          event == AuthChangeEvent.tokenRefreshed) {
        _handlingLoginCallback = false;
        final navigator = _navigatorKey.currentState;
        if (navigator == null) return;
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: themeSeedNotifier,
      builder: (context, seed, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeModeNotifier,
          builder: (context, mode, _) {
            return MaterialApp(
              navigatorKey: _navigatorKey,
              debugShowCheckedModeBanner: false,
              themeMode: mode,
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: seed,
                  brightness: Brightness.light,
                ),
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: seed,
                  brightness: Brightness.dark,
                ),
              ),
              locale: const Locale('ko', 'KR'),
              supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: _showOnboarding
                  ? OnboardingScreen(
                      onFinish: () => setState(() => _showOnboarding = false),
                    )
                  : const HomeScreen(),
            );
          },
        );
      },
    );
  }
}
