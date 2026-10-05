import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/timer_provider.dart';
import '../providers/settings_provider.dart';
import '../models/timer_mode.dart';
import '../services/background_settings_service.dart';
import '../services/translation_service.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../services/persistence_service.dart';
import '../services/widget_action_handler.dart';

import '../widgets/edit_fixed_presets_dialog.dart';
import 'meditation_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'alarm_help_screen.dart';

class MeditationHomeScreen extends StatefulWidget {
  const MeditationHomeScreen({super.key});

  @override
  State<MeditationHomeScreen> createState() => _MeditationHomeScreenState();
}

class _MeditationHomeScreenState extends State<MeditationHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  int _selectedDurationMinutes = 60;
  late int _endAtHour;
  late int _endAtMinute;
  TimerMode _selectedMode = TimerMode.timed;
  bool _initializedMode = false;
  bool _startingSession = false;

  List<int> _fixedHourOptions = [60, 90, 120, 180];
  List<int> _recentSliderValues = [15, 30, 45, 60];

  static const int _sliderMin = 1;
  static const int _sliderMax = 600;
  bool _batteryWarningShown = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();
    _initEndAtTime();
    _loadRecentDurations();
    _loadFixedHourPresets();
    _checkBatteryOnStartup();
  }

  Future<void> _checkBatteryOnStartup() async {
    if (_batteryWarningShown || !Platform.isAndroid) return;
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    try {
      final ignored =
          await BackgroundSettingsService.isBatteryOptimizationIgnored();
      if (!mounted) return;
      if (!ignored) {
        _showBatteryWarningDialog();
      }
    } catch (_) {}
    _batteryWarningShown = true;
  }

  // void _showBatteryWarningDialog() {
  //   if (!mounted) return;
  //   final t = TranslationService.of(context);
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (ctx) => AlertDialog(
  //       title: Row(
  //         children: [
  //           Icon(Icons.battery_alert,
  //               color: AppColors.warning, size: 24),
  //           const SizedBox(width: 10),
  //           Expanded(child: Text(t.translate('home.batteryWarning.title'))),
  //         ],
  //       ),
  //       content: Text(t.translate('home.batteryWarning.desc')),
  //       actions: [
  //         TextButton(
  //           onPressed: () {
  //             Navigator.of(ctx).pop();
  //           },
  //           child: Text(t.translate('home.batteryWarning.later')),
  //         ),
  //         FilledButton.icon(
  //           onPressed: () {
  //             Navigator.of(ctx).pop();
  //             BackgroundSettingsService
  //                 .requestIgnoreBatteryOptimization();
  //           },
  //           icon: const Icon(Icons.settings_rounded, size: 18),
  //           label: Text(t.translate('home.batteryWarning.fixNow')),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  void _showBatteryWarningDialog() {
    if (!mounted) return;
    final t = TranslationService.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Launch image in a rounded circle, like Viber
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withAlpha(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/launch_image.png',
                  // Decode at the 100 dp circle's size, not the 512 px source.
                  cacheWidth: (100 * MediaQuery.devicePixelRatioOf(ctx))
                      .round(),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.nightlight_round,
                    size: 52,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                t.translate('home.batteryWarning.title'),
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              // Description
              Text(
                t.translate('home.batteryWarning.desc'),
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondaryLight,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              // Allow button (full width, filled)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    BackgroundSettingsService.requestIgnoreBatteryOptimization();
                  },
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: Text(t.translate('home.batteryWarning.fixNow')),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Maybe later (text button, centered)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  t.translate('home.batteryWarning.later'),
                  style: TextStyle(color: AppColors.textSecondaryLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadRecentDurations() async {
    final saved = await PersistenceService.loadRecentDurations();
    if (saved.length == 4) {
      setState(() {
        _recentSliderValues = saved;
        _selectedDurationMinutes = saved[0];
      });
    }
  }

  Future<void> _loadFixedHourPresets() async {
    final saved = await PersistenceService.loadFixedHourPresets();
    if (saved.length == 4) {
      setState(() {
        _fixedHourOptions = saved;
      });
    }
  }

  Future<void> _showEditFixedPresetsDialog(BuildContext context) async {
    final result = await showDialog<List<int>>(
      context: context,
      builder: (ctx) =>
          EditFixedPresetsDialog(currentOptions: _fixedHourOptions),
    );

    if (result != null) {
      setState(() {
        _fixedHourOptions = result;
      });
      PersistenceService.saveFixedHourPresets(result);
    }
  }

  void _initEndAtTime() {
    final now = DateTime.now();
    final endAt = now.add(const Duration(minutes: 90));
    _endAtHour = endAt.hour;
    _endAtMinute = endAt.minute;
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _updateLastRecent(int minutes) {
    if (_recentSliderValues.length < 4) return;
    _recentSliderValues[3] = minutes;
  }

  void _setSliderMinutes(int minutes) {
    setState(() {
      _selectedDurationMinutes = minutes;
      _updateLastRecent(minutes);
    });
  }

  // Steps from the value the slider shows, so a preset longer than the
  // slider's range steps down from its maximum, as a drag would.
  int _steppedSliderMinutes(int step) =>
      _selectedDurationMinutes.clamp(_sliderMin, _sliderMax) + step;

  Widget _buildMinuteStepButton(TranslationService t, int step) {
    final target = _steppedSliderMinutes(step);
    final inRange = target >= _sliderMin && target <= _sliderMax;
    return IconButton(
      icon: Icon(
        step < 0
            ? Icons.remove_circle_outline_rounded
            : Icons.add_circle_outline_rounded,
      ),
      color: Theme.of(context).colorScheme.primary,
      visualDensity: VisualDensity.compact,
      tooltip: t.translate(
        step < 0 ? 'home.minusOneMinute' : 'home.plusOneMinute',
      ),
      // Recomputed on press: taps that land before the rebuild each step
      // from the latest value instead of all repeating the same target.
      onPressed: inRange
          ? () => _setSliderMinutes(
              _steppedSliderMinutes(step).clamp(_sliderMin, _sliderMax),
            )
          : null,
    );
  }

  void _addRecentSliderValue(int minutes) {
    _recentSliderValues.remove(minutes);
    _recentSliderValues.insert(0, minutes);
    if (_recentSliderValues.length > 4) {
      _recentSliderValues = _recentSliderValues.sublist(0, 4);
    }
    PersistenceService.saveRecentDurations(_recentSliderValues);
  }

  String _formatMinutes(int minutes, TranslationService t) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins == 0) {
        return '$hours${t.translate('home.hours')}';
      }
      return '$hours${t.translate('home.hours')} $mins${t.translate('home.minutes')}';
    }
    return '$minutes ${t.translate('home.minutes')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = TranslationService.of(context);
    // Not watch: this screen shows no timer values, it only hands settings to
    // the timer and starts sessions. Watching rebuilt it on every tick while it
    // sat hidden under the meditation screen.
    final timerProvider = Provider.of<TimerProvider>(context, listen: false);
    final settingsProvider = context.watch<SettingsProvider>();

    timerProvider.intervalMinutes =
        settingsProvider.soundConfig.intervalMinutes;
    timerProvider.vibrationIntervalMinutes =
        settingsProvider.vibrationConfig.intervalMinutes;
    timerProvider.startSound = settingsProvider.soundConfig.startSound;
    timerProvider.endSound = settingsProvider.soundConfig.endSound;
    timerProvider.intervalSound = settingsProvider.soundConfig.intervalSound;
    timerProvider.startVibration =
        settingsProvider.vibrationConfig.startVibration;
    timerProvider.endVibration = settingsProvider.vibrationConfig.endVibration;
    timerProvider.intervalVibration =
        settingsProvider.vibrationConfig.intervalVibration;
    timerProvider.sessionDelaySeconds = settingsProvider.sessionDelaySeconds;
    timerProvider.volume = settingsProvider.soundConfig.volume;

    // Consume selectedWidgetMode here to support both cold starts and warm-start resumes.
    if (WidgetActionHandler.selectedWidgetMode != null) {
      _selectedMode = TimerMode.fromString(
        WidgetActionHandler.selectedWidgetMode!,
      );
      WidgetActionHandler.selectedWidgetMode = null; // consume once
      _initializedMode = true;
    } else if (!_initializedMode) {
      _selectedMode = settingsProvider.defaultTimerMode;
      _initializedMode = true;
    }

    final isDark =
        settingsProvider.themeMode == 'dark' ||
        (settingsProvider.themeMode == 'deviceTheme' &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    SystemChrome.setSystemUIOverlayStyle(
      isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: AppTheme.lightTheme.scaffoldBackgroundColor,
            ),
    );

    return Theme(
      data: isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
      child: Scaffold(
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  floating: true,
                  leading: IconButton(
                    icon: const Icon(Icons.info_outline_rounded),
                    onPressed: () =>
                        _navigateTo(context, const AlarmHelpScreen()),
                    tooltip: t.translate('alarmHelp.title'),
                  ),
                  // The full product name is wider than the former short
                  // mark. Scale it down on narrow phones so it never crowds
                  // the leading and action buttons in the app bar.
                  title: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t.translate('app.splash.subtitle'),
                          style: const TextStyle(fontWeight: FontWeight.w300),
                        ),
                        Text(
                          t.translate('app.splash.timer'),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.bar_chart_rounded),
                      onPressed: () =>
                          _navigateTo(context, const StatsScreen()),
                      tooltip: t.translate('home.statistics'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_rounded),
                      onPressed: () =>
                          _navigateTo(context, const SettingsScreen()),
                      tooltip: t.translate('home.settings'),
                    ),
                  ],
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Column(
                      children: [
                        _buildModeSelector(context),
                        const SizedBox(height: 24),
                        if (_selectedMode == TimerMode.timed)
                          _buildDurationPicker(context)
                        else if (_selectedMode == TimerMode.endAt)
                          _buildEndAtPicker(context)
                        else
                          _buildUnlimitedInfo(context),
                        const SizedBox(height: 24),
                        _buildStartButton(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector(BuildContext context) {
    final t = TranslationService.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withAlpha(15)
            : Colors.black.withAlpha(8),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: TimerMode.values.map((mode) {
          final isSelected = _selectedMode == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedMode = mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getModeIcon(mode),
                      size: 20,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _modeLabel(t, mode),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDurationPicker(BuildContext context) {
    final t = TranslationService.of(context);
    final isSelectedFixed = _fixedHourOptions.contains(
      _selectedDurationMinutes,
    );

    return Column(
      children: [
        GestureDetector(
          onTap: () => _showEditFixedPresetsDialog(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  t.translate('home.editPresetDuration'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: AppColors.primary),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4 fixed hour buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(_fixedHourOptions.length, (index) {
            final minutes = _fixedHourOptions[index];
            final label = '${minutes ~/ 60}h';
            final displayMinutes = minutes % 60;
            final displayLabel = displayMinutes == 0
                ? label
                : '$label ${displayMinutes}m';
            final isSelected =
                _selectedDurationMinutes == minutes && isSelectedFixed;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedDurationMinutes = minutes;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withAlpha(15)
                      : Colors.black.withAlpha(8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                ),
                child: Text(
                  displayLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(_recentSliderValues.length, (index) {
            final minutes = _recentSliderValues[index];
            final isSelected =
                _selectedDurationMinutes == minutes &&
                !_fixedHourOptions.contains(minutes);
            return GestureDetector(
              onTap: () => setState(() {
                _selectedDurationMinutes = minutes;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withAlpha(180)
                      : Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withAlpha(12)
                      : Colors.black.withAlpha(6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary.withAlpha(180)
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  _formatMinutes(minutes, t),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 16),

        // Slider. On a phone-width track 1–600 minutes moves several minutes
        // per pixel of drag, so − and + give exact one-minute steps.
        Row(
          children: [
            _buildMinuteStepButton(t, -1),
            Text(
              '1',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryLight,
                fontSize: 11,
              ),
            ),
            Expanded(
              child: Slider(
                value: _selectedDurationMinutes.toDouble().clamp(
                  _sliderMin.toDouble(),
                  _sliderMax.toDouble(),
                ),
                min: _sliderMin.toDouble(),
                max: _sliderMax.toDouble(),
                divisions: _sliderMax - _sliderMin,
                label: _formatMinutes(_selectedDurationMinutes, t),
                onChanged: (value) => _setSliderMinutes(value.round()),
              ),
            ),
            Text(
              '600',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryLight,
                fontSize: 11,
              ),
            ),
            _buildMinuteStepButton(t, 1),
          ],
        ),
        Text(
          _formatMinutes(_selectedDurationMinutes, t),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEndAtPicker(BuildContext context) {
    final t = TranslationService.of(context);
    final hourController = FixedExtentScrollController(initialItem: _endAtHour);
    final minuteController = FixedExtentScrollController(
      initialItem: _endAtMinute,
    );

    return Column(
      children: [
        Text(
          t.translate('home.endAtTime'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withAlpha(15)
                : Colors.black.withAlpha(8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 64,
                  height: 120,
                  child: ListWheelScrollView(
                    itemExtent: 48,
                    diameterRatio: 1.2,
                    useMagnifier: true,
                    magnification: 1.1,
                    controller: hourController,
                    onSelectedItemChanged: (index) {
                      setState(() => _endAtHour = index);
                    },
                    children: List.generate(24, (index) {
                      final isSelected = index == _endAtHour;
                      return Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            index.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: isSelected ? 28 : 20,
                              fontWeight: FontWeight.w300,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondaryLight.withAlpha(100),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    ':',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w300,
                      fontSize: 28,
                    ),
                  ),
                ),
                SizedBox(
                  width: 64,
                  height: 120,
                  child: ListWheelScrollView(
                    itemExtent: 48,
                    diameterRatio: 1.2,
                    useMagnifier: true,
                    magnification: 1.1,
                    controller: minuteController,
                    onSelectedItemChanged: (index) {
                      setState(() => _endAtMinute = index);
                    },
                    children: List.generate(60, (index) {
                      final isSelected = index == _endAtMinute;
                      return Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            index.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: isSelected ? 28 : 20,
                              fontWeight: FontWeight.w300,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondaryLight.withAlpha(100),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _endAtHour >= 12
                      ? t.translate('time.pm')
                      : t.translate('time.am'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnlimitedInfo(BuildContext context) {
    final t = TranslationService.of(context);
    return Column(
      children: [
        Icon(
          Icons.all_inclusive,
          size: 48,
          color: AppColors.primary.withAlpha(150),
        ),
        const SizedBox(height: 12),
        Text(
          t.translate('home.noTimeLimit'),
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w300),
        ),
        const SizedBox(height: 4),
        Text(
          t.translate('home.meditateFreely'),
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondaryLight),
        ),
      ],
    );
  }

  Widget _buildStartButton(BuildContext context) {
    final t = TranslationService.of(context);
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(50),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),
          Material(
            elevation: 8,
            shape: const CircleBorder(),
            color: AppColors.primary,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _startingSession ? null : () => _startSession(context),
              child: Container(
                width: 160,
                height: 160,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(16),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.play_arrow_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedMode == TimerMode.timed
                            ? _formatMinutes(_selectedDurationMinutes, t)
                            : _selectedMode == TimerMode.endAt
                            ? '${t.translate('home.until')} ${_endAtHour > 12 ? _endAtHour - 12 : (_endAtHour == 0 ? 12 : _endAtHour)}:${_endAtMinute.toString().padLeft(2, '0')} ${_endAtHour >= 12 ? t.translate('time.pm') : t.translate('time.am')}'
                            : t.translate('home.begin'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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

  IconData _getModeIcon(TimerMode mode) {
    switch (mode) {
      case TimerMode.timed:
        return Icons.timelapse_rounded;
      case TimerMode.endAt:
        return Icons.schedule_rounded;
      case TimerMode.unlimited:
        return Icons.all_inclusive;
    }
  }

  void _startSession(BuildContext context) async {
    // Startup awaits native audio/alarm work. Ignore another tap until the
    // same meditation route has finished, otherwise two timers/routes open.
    if (_startingSession) return;
    setState(() => _startingSession = true);
    try {
      final timerProvider = context.read<TimerProvider>();

      if (_selectedMode == TimerMode.timed) {
        _addRecentSliderValue(_selectedDurationMinutes);

        timerProvider.configure(
          mode: _selectedMode,
          durationMinutes: _selectedDurationMinutes,
        );
      } else if (_selectedMode == TimerMode.endAt) {
        timerProvider.configure(
          mode: _selectedMode,
          endAtHour: _endAtHour,
          endAtMinute: _endAtMinute,
        );
      } else {
        timerProvider.configure(mode: _selectedMode);
      }

      await timerProvider.startSession();

      if (context.mounted) {
        await Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MeditationScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _startingSession = false);
    }
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}
