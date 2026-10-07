import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../services/translation_service.dart';
import '../providers/timer_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';
import '../models/meditation_session.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/edit_session_dialog.dart';
import '../widgets/sitting_quality_input.dart';
import '../utils/sitting_quality.dart';

class CompleteScreen extends StatefulWidget {
  final int durationSeconds;
  final bool isTimedOut;
  final String? sessionId;

  const CompleteScreen({
    super.key,
    required this.durationSeconds,
    this.isTimedOut = true,
    this.sessionId,
  });

  @override
  State<CompleteScreen> createState() => _CompleteScreenState();
}

class _CompleteScreenState extends State<CompleteScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  String _motivation = '';
  late TextEditingController _qualityController;
  late TextEditingController _notesController;
  bool _qualitySaving = false;
  bool _allowPop = false;
  bool _exitInProgress = false;
  late int _displayedDurationSeconds;

  @override
  void initState() {
    super.initState();
    _displayedDurationSeconds = widget.durationSeconds;
    _qualityController = TextEditingController();
    _notesController = TextEditingController();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    );
    _opacityAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    );
    _controller.forward();

    // Reset the timer immediately when CompleteScreen is shown.
    // This puts TimerProvider into idle state, which _AppEntryState
    // detects via _onTimerStateChanged → clears _hasActiveSession
    // → sets _sessionResetComplete = true.
    // The Navigator stack is NOT touched here; CompleteScreen stays
    // visible for the user to read their stats. The stack is only
    // cleared when the user taps "Back to Home" OR when a widget tap
    // comes in (via _ensureMeditationScreen / _resetToHomeScreen).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TimerProvider>().reset(cancelAlarms: false);
        _loadMotivation();
        _loadExistingQuality();
      }
    });
  }

  Future<void> _loadMotivation() async {
    try {
      final locale = TranslationService.of(context).locale;
      final settings = context.read<SettingsProvider>();

      // Opted out of quotes: leave _motivation empty so the build skips the
      // block entirely, and skip the asset and preference reads it needs.
      if (!settings.showQuotes) return;

      // First, try to load user-imported quotes — these completely replace
      // the built-in quotes when available.
      String? userQuotesJson;
      try {
        userQuotesJson = await settings.getUserQuotes();
      } catch (_) {
        // ignore
      }

      if (userQuotesJson != null) {
        // Use only the user's own quotes
        final allQuotes = <String>[];
        try {
          final userData = json.decode(userQuotesJson);
          if (userData is List) {
            allQuotes.addAll(userData.cast<String>());
          } else if (userData is Map) {
            final localeList = (userData[locale] as List?)?.cast<String>();
            final enList = (userData['en'] as List?)?.cast<String>();
            allQuotes.addAll(localeList ?? enList ?? []);
          }
        } catch (_) {
          // user quotes parse failed, fall through to bundled
        }

        if (allQuotes.isNotEmpty && mounted) {
          setState(() {
            _motivation = allQuotes[Random().nextInt(allQuotes.length)];
          });
          return;
        }
      }

      // Fall back to bundled quotes (only if no user quotes were loaded)
      try {
        final data = await rootBundle.loadString('assets/quotes/quotes.json');
        final bundled = json.decode(data) as Map<String, dynamic>;
        final localeQuotes = (bundled[locale] as List?)?.cast<String>() ?? [];
        final quotes = localeQuotes.isNotEmpty
            ? localeQuotes
            : ((bundled['en'] as List?)?.cast<String>() ?? []);

        if (quotes.isNotEmpty && mounted) {
          setState(() {
            _motivation = quotes[Random().nextInt(quotes.length)];
          });
          return;
        }
      } catch (_) {
        // bundled quotes not available
      }

      // Ultimate fallback
      if (mounted) {
        setState(() {
          _motivation = 'TipitakaPali.org';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _motivation = 'TipitakaPali.org';
        });
      }
    }
  }

  /// The reflection quote, or nothing at all.
  ///
  /// [_motivation] stays empty both when the user has turned quotes off and
  /// when none could be loaded, and in either case the surrounding spacing
  /// goes with it rather than leaving a gap where the card used to be.
  List<Widget> _buildReflection(BuildContext context) {
    if (_motivation.isEmpty) return const [];
    return [
      const SizedBox(height: 24),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withAlpha(30)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.format_quote_rounded,
                size: 20,
                color: AppColors.primary.withAlpha(100),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _motivation,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    _qualityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handlePopInvoked(bool didPop, Object? result) async {
    if (didPop || _exitInProgress) return;

    setState(() => _exitInProgress = true);
    final saved = await _saveQuality(showFeedback: false);
    if (!mounted) return;
    if (!saved) {
      setState(() => _exitInProgress = false);
      return;
    }

    await _enableRoutePop();
    if (!mounted) return;
    await context.read<TimerProvider>().stopSounds();
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  Future<void> _onBackToHome() async {
    if (_exitInProgress) return;

    setState(() => _exitInProgress = true);
    final saved = await _saveQuality(showFeedback: false);
    if (!mounted) return;
    if (!saved) {
      setState(() => _exitInProgress = false);
      return;
    }

    await _enableRoutePop();
    if (!mounted) return;
    await context.read<TimerProvider>().stopSounds();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _enableRoutePop() async {
    if (_allowPop) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
  }

  @override
  Widget build(BuildContext context) {
    final t = TranslationService.of(context);
    final settingsProvider = context.watch<SettingsProvider>();

    final isDark =
        settingsProvider.themeMode == 'dark' ||
        (settingsProvider.themeMode == 'deviceTheme' &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final theme = isDark ? AppTheme.darkTheme : AppTheme.lightTheme;

    return Theme(
      data: theme,
      child: PopScope<Object?>(
        canPop: _allowPop,
        onPopInvokedWithResult: _handlePopInvoked,
        child: Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: SafeArea(
            child: Center(
              // Capped on a tablet: the summary is a short column of labels,
              // and stretched over an iPad's width its rows drift so far apart
              // that a duration stops reading as belonging to its own label.
              child: ContentColumn(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.success.withAlpha(30),
                            border: Border.all(
                              color: AppColors.success,
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 60,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      FadeTransition(
                        opacity: _opacityAnimation,
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _qualitySaving || _exitInProgress
                                    ? null
                                    : _onBackToHome,
                                child: Text(t.translate('complete.backToHome')),
                              ),
                            ),

                            const SizedBox(height: 24),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 20,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white.withAlpha(15)
                                    : Colors.black.withAlpha(8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    t.translate('complete.meditationTime'),
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: AppColors.textSecondaryLight,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    TimeUtils.formatDuration(
                                      _displayedDurationSeconds,
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w300,
                                          fontSize: 48,
                                          letterSpacing: 4,
                                          color: AppColors.primary,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    TimeUtils.formatDurationReadable(
                                      _displayedDurationSeconds,
                                    ),
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: AppColors.textSecondaryLight,
                                        ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            Text(
                              widget.isTimedOut
                                  ? t.translate('complete.sessionComplete')
                                  : t.translate('complete.sessionEnded'),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: 1,
                                    color: AppColors.textSecondaryLight,
                                  ),
                            ),

                            const SizedBox(height: 16),

                            _buildQualityEditor(context, t),

                            const SizedBox(height: 16),

                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _qualitySaving || _exitInProgress
                                    ? null
                                    : () => _onEditSession(context),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: Text(t.translate('editSession.title')),
                              ),
                            ),

                            ..._buildReflection(context),
                          ],
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
    );
  }

  /// The quick quality/notes card shown right after a session ends, so
  /// rating a sit doesn't require opening the full edit-session dialog.
  Widget _buildQualityEditor(BuildContext context, TranslationService t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SittingQualityInput(controller: _qualityController),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: t.translate('quality.note'),
              hintText: t.translate('quality.noteHint'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _qualitySaving ? null : () => _saveQuality(),
              icon: _qualitySaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(t.translate('quality.save')),
            ),
          ),
        ],
      ),
    );
  }

  MeditationSession? _findCurrentSession(SessionProvider provider) {
    if (widget.sessionId != null) {
      for (final session in provider.sessions) {
        if (session.id == widget.sessionId) return session;
      }
      return null;
    }
    return provider.sessions.isNotEmpty ? provider.sessions.first : null;
  }

  /// The just-finished session may not be in SessionProvider yet if this
  /// screen opened before the save completed, so retry once after an
  /// explicit reload before giving up.
  Future<void> _loadExistingQuality() async {
    final provider = context.read<SessionProvider>();
    var session = _findCurrentSession(provider);
    if (session == null) {
      await provider.loadSessions();
      session = _findCurrentSession(provider);
    }
    if (!mounted || session == null) return;
    setState(() => _displayedDurationSeconds = session!.durationSeconds);
    _qualityController.text = session.quality ?? '';
    _notesController.text = session.notes ?? '';
  }

  Future<bool> _saveQuality({bool showFeedback = true}) async {
    if (_qualitySaving) return false;
    if (!SittingQuality.isValidInput(_qualityController.text)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService.of(context).translate('quality.invalid'),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
    setState(() => _qualitySaving = true);

    try {
      final provider = context.read<SessionProvider>();
      var session = _findCurrentSession(provider);
      if (session == null) {
        await provider.loadSessions();
        session = _findCurrentSession(provider);
      }

      if (session == null) {
        if (showFeedback && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                TranslationService.of(
                  context,
                ).translate('editSession.notFound'),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
      }

      final quality = SittingQuality.normalize(_qualityController.text);
      final notes = _notesController.text.trim();
      final normalizedNotes = notes.isEmpty ? null : notes;
      if (quality != session.quality || normalizedNotes != session.notes) {
        await provider.updateSession(
          session.copyWith(
            quality: quality,
            clearQuality: quality == null,
            notes: normalizedNotes,
            clearNotes: normalizedNotes == null,
          ),
        );
      }

      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService.of(context).translate('quality.saved'),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
      return true;
    } finally {
      if (mounted) setState(() => _qualitySaving = false);
    }
  }

  /// Opens the full edit dialog. Silently saves any pending quality/notes
  /// from this screen's quick editor first, so switching to the full
  /// dialog can never lose a rating the user already typed here.
  Future<void> _onEditSession(BuildContext context) async {
    final saved = await _saveQuality(showFeedback: false);
    if (!context.mounted || !saved) return;

    final sessionProvider = context.read<SessionProvider>();

    var session = _findCurrentSession(sessionProvider);
    if (session == null) {
      await sessionProvider.loadSessions();
      session = _findCurrentSession(sessionProvider);
    }

    if (!context.mounted) return;

    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            TranslationService.of(context).translate('editSession.notFound'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final updated = await showEditSessionDialog(context, session);
    if (updated != null && context.mounted) {
      await sessionProvider.updateSession(updated);
      if (!context.mounted) return;
      setState(() => _displayedDurationSeconds = updated.durationSeconds);
      _qualityController.text = updated.quality ?? '';
      _notesController.text = updated.notes ?? '';
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService.of(context).translate('editSession.updated'),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
