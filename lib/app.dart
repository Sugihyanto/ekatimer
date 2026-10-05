// lib/app.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/timer_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/session_provider.dart';
import 'services/persistence_service.dart';
import 'services/widget_action_handler.dart';
import 'services/alarm_service.dart';
import 'services/translation_service.dart';
import 'theme/app_theme.dart';
import 'theme/colors.dart';
import 'screens/home_screen.dart';
import 'screens/meditation_screen.dart';

class MeditationTimerApp extends StatefulWidget {
  const MeditationTimerApp({super.key});

  @override
  State<MeditationTimerApp> createState() => _MeditationTimerAppState();
}

class _MeditationTimerAppState extends State<MeditationTimerApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isInitialized = false;
  Map<String, Map<String, String>> _translations = {};
  String _locale = 'en';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (!mounted) return;

    try {
      _translations = await TranslationService.loadTranslations();
    } catch (_) {
      _translations = {};
    }

    if (!mounted) return;

    final settingsProvider = context.read<SettingsProvider>();
    await settingsProvider.loadSettings();

    if (!mounted) return;

    _locale = TranslationService.resolveLocale(settingsProvider.locale);

    switch (settingsProvider.themeMode) {
      case 'light':
        _themeMode = ThemeMode.light;
      case 'dark':
        _themeMode = ThemeMode.dark;
      default:
        _themeMode = ThemeMode.system;
    }

    final sessionProvider = context.read<SessionProvider>();
    await sessionProvider.loadSessions();

    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const _SplashScreen(),
      );
    }

    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        switch (settings.themeMode) {
          case 'light':
            _themeMode = ThemeMode.light;
          case 'dark':
            _themeMode = ThemeMode.dark;
          default:
            _themeMode = ThemeMode.system;
        }

        if (settings.locale != _locale && _translations.isNotEmpty) {
          _locale = TranslationService.resolveLocale(settings.locale);
        }

        return TranslationService(
          translations: _translations,
          locale: _locale,
          child: MaterialApp(
            title: 'Meditation Timer',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: _themeMode,
            locale: ui.Locale(_locale),
            home: const _AppEntry(),
          ),
        );
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.self_improvement,
              size: 80,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Meditation Timer',
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w300),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> with WidgetsBindingObserver {
  bool _checkingSession = true;
  bool _hasActiveSession = false;

  // True while _checkForActiveSession() is running.
  bool _initialCheckInProgress = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final alarmService = AlarmService();
    alarmService.onAlarmFired = (requestCode) {
      final timerProvider = context.read<TimerProvider>();
      timerProvider.onNativeAlarmFired(requestCode);
    };

    WidgetActionHandler.setupListener(
      context,
      onSessionStarted: () {
        if (mounted) {
          setState(() => _hasActiveSession = true);
          _ensureMeditationScreen();
        }
      },
      isInitialCheckInProgress: () => _initialCheckInProgress,
    );

    context.read<TimerProvider>().addListener(_onTimerStateChanged);

    _checkForActiveSession();
  }

  @override
  void didUpdateWidget(covariant _AppEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetActionHandler.updateContext(
      context,
      onSessionStarted: () {
        if (mounted) {
          setState(() => _hasActiveSession = true);
          _ensureMeditationScreen();
        }
      },
      isInitialCheckInProgress: () => _initialCheckInProgress,
    );
  }

  void _onTimerStateChanged() {
    if (!mounted) return;
    final timerProvider = context.read<TimerProvider>();

    // When timer goes idle after an active session, clear the active flag
    // so the home screen appears beneath the Navigator stack.
    // The Navigator stack is NOT touched here — CompleteScreen stays
    // visible for the user to read their stats. The stack is cleared
    // when the user taps "Back to Home" or when a widget tap arrives
    // (via _ensureMeditationScreen).
    if (_hasActiveSession && timerProvider.state == TimerState.idle) {
      setState(() => _hasActiveSession = false);
    }
  }

  /// Pushes HomeScreen and removes every other route from the stack.
  /// Called both when a session ends naturally and when the user stops early.

  void _ensureMeditationScreen() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        // Pop all pushed screens (stale completion screens, settings, etc.)
        // back to the root route (_AppEntry).
        // Since _hasActiveSession is set to true, the root route will automatically
        // rebuild and render the MeditationScreen. This keeps _AppEntry alive,
        // preserving your app lifecycle and widget listeners.
        Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (_) {}
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_initialCheckInProgress &&
        !_checkingSession &&
        mounted) {
      // Defer to the next frame so the widget tree is stable before we
      // call context.read<TimerProvider>() inside handleWidgetAction.
      // Without this deferral, a concurrent rebuild triggered by
      // _onTimerStateChanged → setState can leave the context in a
      // "deactivated widget" state, causing Provider.read to throw.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleResumeWidgetAction();
      });
    }
  }

  Future<void> _handleResumeWidgetAction() async {
    if (!mounted) return;
    try {
      final handled = await WidgetActionHandler.handleWidgetAction(context);
      if (handled && mounted) {
        setState(() => _hasActiveSession = true);
        _ensureMeditationScreen();
      } else if (!handled &&
          WidgetActionHandler.selectedWidgetMode != null &&
          mounted) {
        // Defer the pop using Future.delayed(Duration.zero) instead of addPostFrameCallback.
        // This executes the pop immediately in a new event loop turn, without waiting
        // for a rendering frame to be scheduled (since no setState was called here).
        Future.delayed(Duration.zero, () {
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });
      }
    } catch (e) {
      debugPrint('_handleResumeWidgetAction error: $e');
    }
  }

  @override
  void dispose() {
    context.read<TimerProvider>().removeListener(_onTimerStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkForActiveSession() async {
    final timerProvider = context.read<TimerProvider>();
    // Preserve the alarm marker before handleWidgetAction consumes the intent.
    final widgetData = await WidgetActionHandler.getWidgetActionData();

    // ── 1. Handle widget-tap quick-start FIRST ────────────────────────────
    if (mounted) {
      final handledWidgetAction = await WidgetActionHandler.handleWidgetAction(
        context,
      );
      if (handledWidgetAction && mounted) {
        setState(() {
          _hasActiveSession = true;
          _initialCheckInProgress = false;
          _checkingSession = false;
        });
        return;
      }
    }

    // ── 2. Skip restore if launched from an alarm ─────────────────────────
    if (widgetData?['fromAlarm'] == true) {
      if (mounted) {
        setState(() {
          _initialCheckInProgress = false;
          _checkingSession = false;
        });
      }
      return;
    }

    // ── 3. Restore an interrupted session ─────────────────────────────────
    final hasSession = await timerProvider.hasActiveSession();
    if (hasSession && mounted) {
      final sessionData = await PersistenceService.loadActiveSession();
      if (sessionData != null && mounted) {
        await timerProvider.restoreSession(sessionData);
        setState(() {
          _hasActiveSession = true;
          _initialCheckInProgress = false;
          _checkingSession = false;
        });
        return;
      }
    }

    // ── 4. No action — normal home screen ─────────────────────────────────
    if (mounted) {
      setState(() {
        _initialCheckInProgress = false;
        _checkingSession = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const _SplashScreen();
    }

    if (_hasActiveSession) {
      return const MeditationScreen();
    }

    return const MeditationHomeScreen();
  }
}
