import 'dart:async'; // Required for the inactivity Timer
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../providers/timer_provider.dart';
import '../providers/session_provider.dart';
import '../providers/settings_provider.dart';
import '../models/timer_mode.dart';
import '../services/translation_service.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';
import '../widgets/timer_display.dart';
import 'complete_screen.dart';

class MeditationScreen extends StatefulWidget {
  const MeditationScreen({super.key});

  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _showStopConfirm = false;
  bool _hasNavigatedToComplete = false;
  String _currentScreenControl = 'deviceTimeOut';

  // Inactivity dimming configurations
  Timer? _dimTimer;
  bool _isAutoDimmed = false;
  static const Duration _autoDimDelay = Duration(
    seconds: 8,
  ); // Time before visual dimming starts

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyScreenControl();
      _resetDimTimer();
    });

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        statusBarColor: Colors.transparent,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dimTimer?.cancel();
    WakelockPlus.disable();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: null,
        statusBarColor: null,
      ),
    );
    super.dispose();
  }

  void _applyWakelock(String control) {
    if (control == 'on' || control == 'dim') {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  void _applyScreenControl() {
    final settings = context.read<SettingsProvider>();
    _currentScreenControl = settings.screenControl;
    _applyWakelock(_currentScreenControl);
  }

  bool get _showDimOverlay => _currentScreenControl == 'dim';

  /// Starts or resets the auto-dim countdown timer
  void _resetDimTimer() {
    _dimTimer?.cancel();
    if (!mounted) return;

    final timerProvider = context.read<TimerProvider>();

    // Start inactivity countdown only when timer is running and 'deviceTimeOut' is selected
    if (_currentScreenControl == 'deviceTimeOut' &&
        !_showStopConfirm &&
        timerProvider.state == TimerState.running &&
        !_isAutoDimmed) {
      _dimTimer = Timer(_autoDimDelay, () {
        if (mounted) {
          setState(() {
            _isAutoDimmed = true;
          });
        }
      });
    }
  }

  /// Safe translation helper returning local fallback if key is missing
  String _getTapToWakeText(TranslationService t) {
    final translated = t.translate('meditation.tapToWake');
    if (translated == 'meditation.tapToWake') {
      return 'Screen is dim now,\nthen turn off based on your device settings';
    }
    return translated;
  }

  @override
  Widget build(BuildContext context) {
    final t = TranslationService.of(context);
    final timerProvider = context.watch<TimerProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final sessionProvider = context.read<SessionProvider>();

    if (_currentScreenControl != settingsProvider.screenControl) {
      _currentScreenControl = settingsProvider.screenControl;
      _applyWakelock(_currentScreenControl);
      _resetDimTimer();
    }

    // Force wake if the timer state is no longer running (paused, completed, etc.)
    if (timerProvider.state != TimerState.running && _isAutoDimmed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isAutoDimmed = false;
          });
        }
      });
    }

    final isDark =
        settingsProvider.themeMode == 'dark' ||
        (settingsProvider.themeMode == 'deviceTheme' &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final theme = isDark ? AppTheme.darkTheme : AppTheme.lightTheme;

    // Show delay countdown, handle skip on tap
    if (timerProvider.state == TimerState.delaying) {
      return Theme(
        data: theme,
        child: _buildDelayScreen(context, timerProvider, t),
      );
    }

    // The session finished on its own (timer ran out or the native alarm
    // fired). Navigation is deferred to after this frame because build()
    // must not push a route while it is still running. The flag is left for
    // _navigateToComplete to set: build() can run again before the callback
    // fires, and claiming it here would make that callback a no-op and the
    // CompleteScreen never appear.
    if (timerProvider.state == TimerState.completed &&
        !_hasNavigatedToComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToComplete(context);
      });
    }

    double progress = 1.0;
    if (timerProvider.totalDurationSeconds > 0) {
      progress =
          timerProvider.remainingSeconds / timerProvider.totalDurationSeconds;
      progress = progress.clamp(0.0, 1.0);
    }

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            _resetDimTimer(); // Reset dimming countdown on physical screen contact
          },
          child: Stack(
            children: [
              SafeArea(
                child: isLandscape
                    ? _buildLandscapeContent(
                        t,
                        timerProvider,
                        sessionProvider,
                        progress,
                      )
                    : _buildPortraitContent(
                        t,
                        timerProvider,
                        sessionProvider,
                        progress,
                      ),
              ),

              if (_showDimOverlay)
                IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: 0.45,
                    duration: const Duration(milliseconds: 800),
                    child: Container(color: Colors.black),
                  ),
                ),

              // Interactive Auto-Dimming Shield Overlay (deviceTimeOut setting dimming)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_isAutoDimmed,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isAutoDimmed = false;
                      });
                      _resetDimTimer();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      color: _isAutoDimmed
                          ? Colors.black.withValues(alpha: 0.96)
                          : Colors.transparent,
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: _isAutoDimmed ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 600),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.nights_stay_outlined,
                                color: Colors.white.withValues(alpha: 0.3),
                                size: 36,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _getTapToWakeText(t),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: 1.2,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              if (_showStopConfirm)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(32),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.shadow.withAlpha(40),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            t.translate('meditation.endSession'),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t.translate(
                              'meditation.meditatingFor',
                              args: {
                                'duration': TimeUtils.formatDurationReadable(
                                  timerProvider.elapsedSeconds,
                                ),
                              },
                            ),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _showStopConfirm = false;
                                    });
                                    _resetDimTimer();
                                  },
                                  child: Text(
                                    t.translate('meditation.continue'),
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    setState(() => _showStopConfirm = false);
                                    await timerProvider.stopSession(
                                      completed: false,
                                    );
                                    if (context.mounted) {
                                      _navigateToComplete(context);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.error,
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.onError,
                                  ),
                                  child: Text(t.translate('meditation.end')),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the delay countdown screen shown before the session starts.
  Widget _buildDelayScreen(
    BuildContext context,
    TimerProvider timerProvider,
    TranslationService t,
  ) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: GestureDetector(
        onTap: () => timerProvider.skipDelay(),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.translate('meditation.startingIn'),
                  style: TextStyle(
                    fontSize: 18,
                    color: theme.colorScheme.onSurface.withAlpha(180),
                  ),
                ),
                const SizedBox(height: 24),
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    // Layered like _buildTimerWithPulse; see the note there.
                    return RepaintBoundary(
                      child: Transform.scale(
                        scale: _pulseAnimation.value,
                        child: RepaintBoundary(child: child),
                      ),
                    );
                  },
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary.withAlpha(30),
                      border: Border.all(
                        color: theme.colorScheme.primary.withAlpha(100),
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${timerProvider.delayRemainingSeconds}',
                        style: TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.w200,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  t.translate('meditation.tapToSkip'),
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withAlpha(120),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool large = false,
  }) {
    final theme = Theme.of(context);
    final bgColor = isDestructive
        ? theme.colorScheme.error.withAlpha(30)
        : theme.colorScheme.primary.withAlpha(30);
    final iconColor = isDestructive
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final borderColor = isDestructive
        ? theme.colorScheme.error.withAlpha(60)
        : theme.colorScheme.primary.withAlpha(60);
    final labelColor = theme.colorScheme.onSurface.withAlpha(180);

    final double buttonSize = large ? 80 : 64;
    final double iconSize = large ? 36 : 28;
    final double fontSize = large ? 14 : 12;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Icon(icon, color: iconColor, size: iconSize),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitContent(
    TranslationService t,
    TimerProvider timerProvider,
    SessionProvider sessionProvider,
    double progress,
  ) {
    return Column(
      children: [
        _buildTopBar(t, timerProvider),
        const Spacer(),
        _buildTimerWithPulse(t, timerProvider, sessionProvider, progress),
        // Show "End at: {time}" below the circle for End At mode
        if (timerProvider.timerMode == TimerMode.endAt &&
            timerProvider.endTime != null)
          _buildEndAtText(t, timerProvider),
        const Spacer(),
        _buildControlButtons(t, timerProvider),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLandscapeContent(
    TranslationService t,
    TimerProvider timerProvider,
    SessionProvider sessionProvider,
    double progress,
  ) {
    final bool hasEndAt =
        timerProvider.timerMode == TimerMode.endAt &&
        timerProvider.endTime != null;

    return Column(
      children: [
        _buildTopBar(t, timerProvider),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Account for ~40px of endAt text below the circle if visible
              final availableHeight =
                  constraints.maxHeight - (hasEndAt ? 40.0 : 0.0) - 16.0;
              // Use up to 180px, but shrink to fit smaller screens
              final circleSize = availableHeight.clamp(120.0, 180.0);

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: _buildControlButton(
                        icon: timerProvider.state == TimerState.paused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        label: timerProvider.state == TimerState.paused
                            ? t.translate('meditation.resume')
                            : t.translate('meditation.pause'),
                        onTap: () {
                          if (timerProvider.state == TimerState.paused) {
                            timerProvider.resumeSession();
                            _resetDimTimer();
                          } else {
                            timerProvider.pauseSession();
                          }
                        },
                        large: true,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTimerWithPulse(
                        t,
                        timerProvider,
                        sessionProvider,
                        progress,
                        circleSize: circleSize,
                      ),
                      if (hasEndAt) _buildEndAtText(t, timerProvider),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: _buildControlButton(
                        icon: Icons.stop_rounded,
                        label: t.translate('meditation.stop'),
                        onTap: () {
                          setState(() {
                            _showStopConfirm = true;
                            _isAutoDimmed = false;
                          });
                          _dimTimer?.cancel();
                        },
                        isDestructive: true,
                        large: true,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(TranslationService t, TimerProvider timerProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _modeLabel(t, timerProvider.timerMode).toUpperCase(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _currentScreenControl == 'on'
                    ? Icons.brightness_high
                    : _currentScreenControl == 'dim'
                    ? Icons.brightness_low
                    : Icons.brightness_auto,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                TimeUtils.formatTimeOfDay(DateTime.now()),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimerWithPulse(
    TranslationService t,
    TimerProvider timerProvider,
    SessionProvider sessionProvider,
    double progress, {
    double circleSize = 280,
  }) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        // The pulse runs for the whole session at the display's refresh rate.
        // With the scaled content and the scale in their own layers, a frame
        // only re-composites a cached picture instead of repainting the whole
        // meditation screen, arc and digits included, on every vsync.
        return RepaintBoundary(
          child: Transform.scale(
            scale: _pulseAnimation.value,
            child: RepaintBoundary(child: child),
          ),
        );
      },
      child: TimerDisplay(
        timeText: timerProvider.displayTime,
        subtitleLabel: timerProvider.timerMode == TimerMode.endAt
            ? t.translate('meditation.elapsed')
            : timerProvider.timerMode == TimerMode.unlimited
            ? t.translate('stats.thisWeek')
            : t.translate('meditation.elapsed'),
        subtitleValue: timerProvider.timerMode == TimerMode.endAt
            ? timerProvider.elapsedDisplay
            : timerProvider.timerMode == TimerMode.unlimited
            ? TimeUtils.formatDurationReadable(
                sessionProvider.thisWeekDurationSeconds,
              )
            : timerProvider.elapsedDisplay,
        isPaused: timerProvider.state == TimerState.paused,
        progress: progress,
        size: circleSize,
      ),
    );
  }

  Widget _buildEndAtText(TranslationService t, TimerProvider timerProvider) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        '${t.translate('meditation.endAt')} ${TimeUtils.formatTimeOfDay(timerProvider.endTime!, amLabel: t.translate('time.am'), pmLabel: t.translate('time.pm'))}',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
        ),
      ),
    );
  }

  Widget _buildControlButtons(
    TranslationService t,
    TimerProvider timerProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildControlButton(
            icon: timerProvider.state == TimerState.paused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded,
            label: timerProvider.state == TimerState.paused
                ? t.translate('meditation.resume')
                : t.translate('meditation.pause'),
            onTap: () {
              if (timerProvider.state == TimerState.paused) {
                timerProvider.resumeSession();
                _resetDimTimer();
              } else {
                timerProvider.pauseSession();
              }
            },
          ),
          const SizedBox(width: 24),
          _buildControlButton(
            icon: Icons.stop_rounded,
            label: t.translate('meditation.stop'),
            onTap: () {
              setState(() {
                _showStopConfirm = true;
                _isAutoDimmed = false;
              });
              _dimTimer?.cancel();
            },
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  String _modeLabel(TranslationService t, TimerMode mode) {
    switch (mode) {
      case TimerMode.timed:
        return t.translate('home.mode.timed');
      case TimerMode.endAt:
        return t.translate('home.mode.endAt');
      case TimerMode.unlimited:
        return t.translate('home.mode.unlimited');
    }
  }

  /// Pushes the CompleteScreen exactly once per session.
  ///
  /// Two callers can race here: the End button calls this directly, and
  /// `stopSession()` also flips the state to `completed`, which makes
  /// build() schedule a call of its own. Without this guard both fire, and
  /// the first CompleteScreen resets TimerProvider in its initState —
  /// zeroing elapsedSeconds before the second one reads it, so the screen
  /// the user actually sees reports a 00:00 session.
  void _navigateToComplete(BuildContext context) async {
    if (_hasNavigatedToComplete) return;
    _hasNavigatedToComplete = true;

    final timerProvider = context.read<TimerProvider>();
    final sessionProvider = context.read<SessionProvider>();
    await sessionProvider.loadSessions();

    if (context.mounted) {
      // Use push instead of pushReplacement to ensure the root _AppEntry route
      // remains safely preserved at the bottom of the navigation stack.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CompleteScreen(
            durationSeconds: timerProvider.elapsedSeconds,
            // `state` is TimerState.completed either way by this point, so
            // it can't tell a natural finish from an early stop — that
            // distinction is what lastSessionCompletedNaturally is for.
            isTimedOut: timerProvider.lastSessionCompletedNaturally,
            sessionId: timerProvider.currentSessionId,
          ),
        ),
      );
    }
  }
}
