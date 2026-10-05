// lib/services/widget_action_handler.dart

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/timer_mode.dart';
import '../providers/timer_provider.dart';
import 'persistence_service.dart';

/// Handles widget tap actions from home screen widgets.
///
/// Architecture:
///   • ONE shared MethodChannel instance — no competing handler registrations.
///   • Native stores data persistently; Dart is the only one to call
///     getWidgetAction (which clears it).  Calling it twice safely returns nil
///     the second time.
///   • setupListener registers once.  The [isInitialCheckInProgress] gate
///     prevents the push-notification path from racing with
///     _checkForActiveSession on cold launch.
///   • On warm launches (app already in foreground/background) the gate is
///     false and the listener is the sole consumer.
class WidgetActionHandler {
  WidgetActionHandler._();

  // ── Shared channel ────────────────────────────────────────────────────────

  // Cross-language API: the Android value must match MainActivity.kt exactly.
  // The iOS widget uses its existing platform-specific channel name.
  static final MethodChannel _channel = MethodChannel(
    Platform.isAndroid
        ? 'org.tipitakapali.ekatimer/widget'
        : 'org.ekatimer.ios.gmlpub/widget',
  );

  // ── Public state ──────────────────────────────────────────────────────────

  /// Non-null when a widget tap requested endAt mode with no valid future
  /// timestamp — the home screen reads this to pre-select the End At picker.
  static String? selectedWidgetMode;

  // ── Listener state ────────────────────────────────────────────────────────

  static BuildContext? _ctx;
  static VoidCallback? _onSessionStarted;
  static bool Function()? _isInitialCheckInProgress;
  static bool _registered = false;

  /// Register the widgetActionAvailable handler.  Call once from initState,
  /// before _checkForActiveSession fires.
  ///
  /// [isInitialCheckInProgress] — returns true while the cold-launch session
  /// check is running.  When true, the listener skips acting so it cannot race
  /// with _checkForActiveSession both trying to call getWidgetAction.
  static void setupListener(
    BuildContext context, {
    required VoidCallback onSessionStarted,
    required bool Function() isInitialCheckInProgress,
  }) {
    if (Platform.isAndroid) return;

    _ctx = context;
    _onSessionStarted = onSessionStarted;
    _isInitialCheckInProgress = isInitialCheckInProgress;

    if (_registered) return; // setMethodCallHandler only once per process
    _registered = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'widgetActionAvailable') {
        // Gate: if the cold-launch check is still running, it will call
        // handleWidgetAction itself at step 3.  Acting here too would mean
        // two concurrent calls to getWidgetAction — the second always gets nil.
        if (_isInitialCheckInProgress?.call() == true) return null;

        final ctx = _ctx;
        if (ctx == null || !ctx.mounted) return null;

        final handled = await handleWidgetAction(ctx);
        if (handled && ctx.mounted) {
          _onSessionStarted?.call();
        }
      }
      return null;
    });
  }

  /// Update the stored context and callbacks after a rebuild.
  static void updateContext(
    BuildContext context, {
    required VoidCallback onSessionStarted,
    required bool Function() isInitialCheckInProgress,
  }) {
    _ctx = context;
    _onSessionStarted = onSessionStarted;
    _isInitialCheckInProgress = isInitialCheckInProgress;
  }

  // ── Action handlers ───────────────────────────────────────────────────────

  /// Poll native for a pending widget action and act on it.
  ///
  /// Returns true  → session started; caller should show MeditationScreen.
  /// Returns false → no action, or endAt with no timestamp (home screen,
  ///                 picker pre-selected via [selectedWidgetMode]).
  static Future<bool> handleWidgetAction(BuildContext context) async {
    return Platform.isAndroid ? _handleAndroid(context) : _handleIos(context);
  }

  // A launcher shortcut must not silently discard an in-progress session.
  // This also covers a cold launch after Android reclaimed the app process.
  static Future<bool> _preserveExistingSession(TimerProvider timer) async {
    if (timer.state == TimerState.running ||
        timer.state == TimerState.paused ||
        timer.state == TimerState.delaying) {
      return true;
    }
    if (timer.state == TimerState.idle) {
      final saved = await PersistenceService.loadActiveSession();
      if (saved != null) {
        await timer.restoreSession(saved);
        return true;
      }
    }
    return false;
  }

  static Future<bool> _handleIos(BuildContext context) async {
    if (!context.mounted) return false;
    final timerProvider = context.read<TimerProvider>();

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getWidgetAction',
      );
      if (result == null || result.isEmpty) return false;

      // If launched from an alarm, don't start a new session.
      if (result['fromAlarm'] == true) return false;

      final timerMode = result['timerMode'] as String?;
      final timerDuration = result['timerDuration'] as int?;
      if (timerMode == null) return false;

      final mode = TimerMode.fromString(timerMode);

      if (await _preserveExistingSession(timerProvider)) return true;

      // Reset the timer state machine to ensure it is clean before configuration.
      timerProvider.reset();

      if (mode == TimerMode.endAt) {
        final endAtTs = result['endAt'] as int?;
        final nowSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (endAtTs != null && endAtTs > nowSecs) {
          // Valid future end-time → jump straight into the countdown.
          final remainingMinutes = ((endAtTs - nowSecs) / 60).ceil();
          timerProvider.configure(
            mode: mode,
            durationMinutes: remainingMinutes,
          );
          await timerProvider.startSession();
          return true;
        }
        // No valid timestamp → open home screen with End At picker pre-selected.
        timerProvider.configure(mode: mode, durationMinutes: timerDuration);
        selectedWidgetMode = timerMode;
        return false;
      }

      // timed / open / unlimited — start immediately.
      timerProvider.configure(mode: mode, durationMinutes: timerDuration ?? 60);
      await timerProvider.startSession();
      return true;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('WidgetActionHandler._handleIos error: $e');
      return false;
    }
  }

  static Future<bool> _handleAndroid(BuildContext context) async {
    if (!context.mounted) return false;
    final timerProvider = context.read<TimerProvider>();

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getWidgetAction',
      );
      if (result == null || result.isEmpty) return false;

      // If launched from an alarm, don't start a new session.
      if (result['fromAlarm'] == true) return false;

      final timerMode = result['timerMode'] as String?;
      final timerDuration = result['timerDuration'] as int?;
      if (timerMode == null) return false;

      final mode = TimerMode.fromString(timerMode);

      if (await _preserveExistingSession(timerProvider)) return true;

      // Reset the timer state machine to ensure it is clean before configuration.
      timerProvider.reset();

      if (mode == TimerMode.endAt) {
        timerProvider.configure(mode: mode, durationMinutes: timerDuration);
        selectedWidgetMode = timerMode;
        return false;
      }

      timerProvider.configure(mode: mode, durationMinutes: timerDuration ?? 60);
      await timerProvider.startSession();
      return true;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('WidgetActionHandler._handleAndroid error: $e');
      return false;
    }
  }

  // ── Raw data peek (non-clearing) ─────────────────────────────────────────

  /// Force all Android widgets to refresh so they pick up the latest
  /// transparency preference.
  ///
  /// [transparent] is passed directly to native so it doesn't rely on
  /// SharedPreferences file compatibility between Flutter and native.
  static Future<void> updateAllWidgets({required bool transparent}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('updateAllWidgets', {
        'transparent': transparent,
      });
    } on MissingPluginException {
      // ignore – method not registered on older native side
    } catch (e) {
      debugPrint('WidgetActionHandler.updateAllWidgets error: $e');
    }
  }

  /// Fetch widget action data for inspection (e.g. checking `fromAlarm`).
  ///
  /// Peeking leaves the action available for handleWidgetAction on both platforms.
  static Future<Map<String, dynamic>?> getWidgetActionData() async {
    try {
      // Use peekWidgetAction so the data is NOT cleared — handleWidgetAction
      // can still read it via getWidgetAction in the same launch sequence.
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'peekWidgetAction',
      );
      if (result == null || result.isEmpty) return null;
      return result.cast<String, dynamic>();
    } on MissingPluginException {
      return null;
    } catch (e) {
      debugPrint('WidgetActionHandler.getWidgetActionData error: $e');
      return null;
    }
  }
}
