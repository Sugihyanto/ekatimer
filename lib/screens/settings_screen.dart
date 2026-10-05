// lib/screens/settings_screen.dart

import 'dart:convert';
import 'dart:io' show File, Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/settings_provider.dart';
import '../providers/session_provider.dart';
import '../models/timer_mode.dart';
import '../models/data_import_mode.dart';
import '../models/user_profile.dart';
import '../services/translation_service.dart';
import '../services/csv_data_service.dart';
import '../services/backup_service.dart';
import '../services/database_service.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../widgets/sound_picker.dart';
import '../widgets/vibration_picker.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final t = TranslationService.of(context);

    final isDark =
        settings.themeMode == 'dark' ||
        (settings.themeMode == 'deviceTheme' &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final theme = isDark ? AppTheme.darkTheme : AppTheme.lightTheme;

    final languages = TranslationService.supportedLanguages;
    final selectedLocale = languages.containsKey(settings.locale)
        ? settings.locale
        : 'en';

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(title: Text(t.translate('settings.title'))),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _buildSectionHeader(context, t.translate('settings.profile')),
            _buildListTile(
              context,
              icon: Icons.switch_account_outlined,
              title: t.translate('profiles.active'),
              subtitle: settings.userName,
              trailing: const Icon(Icons.manage_accounts_outlined),
              onTap: () => _showProfilesDialog(context, settings),
            ),
            _buildListTile(
              context,
              icon: Icons.language,
              title: t.translate('settings.language'),
              trailing: DropdownButton<String>(
                isExpanded: true,
                itemHeight: null,
                value: selectedLocale,
                underline: const SizedBox(),
                items: languages.keys.map((code) {
                  return DropdownMenuItem(
                    value: code,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(languages[code] ?? code),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) settings.setLocale(value);
                },
              ),
            ),

            const Divider(),

            _buildSectionHeader(
              context,
              t.translate('settings.timerModeSettings'),
            ),
            _buildListTile(
              context,
              icon: Icons.timer_outlined,
              title: t.translate('settings.defaultTimerMode'),
              trailing: DropdownButton<TimerMode>(
                isExpanded: true,
                itemHeight: null,
                value: settings.defaultTimerMode,
                underline: const SizedBox(),
                items: TimerMode.values.map((mode) {
                  return DropdownMenuItem(
                    value: mode,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(_modeLabel(t, mode)),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) settings.setTimerMode(value);
                },
              ),
            ),

            const Divider(),

            _buildSectionHeader(
              context,
              t.translate('settings.delayBeforeStart'),
            ),
            _buildListTile(
              context,
              icon: Icons.timer_off_outlined,
              title: t.translate('settings.delaySeconds'),
              subtitle: settings.sessionDelaySeconds > 0
                  ? t.translate(
                      'settings.delayCount',
                      args: {'seconds': '${settings.sessionDelaySeconds}'},
                    )
                  : t.translate('settings.disabled'),
              trailing: SizedBox(
                width: 160,
                child: Slider(
                  value: settings.sessionDelaySeconds.toDouble(),
                  min: 0,
                  max: 60,
                  divisions: 12,
                  label: settings.sessionDelaySeconds > 0
                      ? '${settings.sessionDelaySeconds}s'
                      : 'Off',
                  onChanged: (value) => settings.setSessionDelay(value.round()),
                ),
              ),
            ),

            const Divider(),

            _buildSectionHeader(
              context,
              t.translate('settings.soundVibrationSettings'),
            ),
            _buildListTile(
              context,
              icon: Icons.volume_up_outlined,
              title: t.translate('settings.sessionVolume'),
              trailing: SizedBox(
                width: 120,
                child: Slider(
                  value: settings.soundConfig.volume.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 10,
                  label: '${settings.soundConfig.volume}%',
                  onChanged: (value) => settings.setVolume(value.round()),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SoundPicker(
                label: t.translate('settings.startSound'),
                currentSound: settings.soundConfig.startSound,
                onChanged: (sound) => settings.setStartSound(sound),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: VibrationPicker(
                label: t.translate('settings.startVibration'),
                currentVibration: settings.vibrationConfig.startVibration,
                onChanged: (vib) => settings.setStartVibration(vib),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SoundPicker(
                label: t.translate('settings.endSound'),
                currentSound: settings.soundConfig.endSound,
                onChanged: (sound) => settings.setEndSound(sound),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: VibrationPicker(
                label: t.translate('settings.endVibration'),
                currentVibration: settings.vibrationConfig.endVibration,
                onChanged: (vib) => settings.setEndVibration(vib),
              ),
            ),

            const Divider(),

            _buildSectionHeader(
              context,
              t.translate('settings.intervalBellVibration'),
            ),
            _buildIntervalTile(
              context,
              icon: Icons.repeat_one_outlined,
              title: t.translate('settings.intervalSound'),
              subtitle: settings.soundConfig.intervalMinutes > 0
                  ? t.translate(
                      'settings.everyMin',
                      args: {
                        'minutes': '${settings.soundConfig.intervalMinutes}',
                      },
                    )
                  : t.translate('settings.disabled'),
              value: settings.soundConfig.intervalMinutes,
              soundValue: settings.soundConfig.intervalSound,
              onMinutesChanged: (m) => settings.setIntervalMinutes(m),
              onSoundChanged: (s) => settings.setIntervalSound(s),
            ),
            _buildIntervalVibrationTile(context, settings: settings),
            const Divider(),

            const Divider(),

            _buildSectionHeader(context, t.translate('settings.display')),
            _buildListTile(
              context,
              icon: Icons.phone_android_outlined,
              title: t.translate('settings.screenDuring'),
              subtitle: _getScreenControlLabel(t, settings.screenControl),
              trailing: DropdownButton<String>(
                isExpanded: true,
                itemHeight: null,
                value: settings.screenControl,
                underline: const SizedBox(),
                items: ['deviceTimeOut', 'dim', 'on'].map((control) {
                  return DropdownMenuItem(
                    value: control,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(_getScreenControlLabel(t, control)),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) settings.setScreenControl(value);
                },
              ),
            ),
            _buildListTile(
              context,
              icon: Icons.dark_mode_outlined,
              title: t.translate('settings.theme'),
              subtitle: _getThemeModeLabel(t, settings.themeMode),
              trailing: DropdownButton<String>(
                isExpanded: true,
                itemHeight: null,
                value: settings.themeMode,
                underline: const SizedBox(),
                items: ['deviceTheme', 'light', 'dark'].map((mode) {
                  return DropdownMenuItem(
                    value: mode,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(_getThemeModeLabel(t, mode)),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) settings.setThemeMode(value);
                },
              ),
            ),
            // Transparent Widget toggle – Android only
            if (!Platform.isIOS)
              SwitchListTile(
                secondary: const Icon(Icons.widgets_outlined),
                title: Text(t.translate('settings.transparentWidget')),
                // subtitle: Text(
                //   t.translate('settings.transparentWidgetDesc'),
                //   style: const TextStyle(fontSize: 13),
                // ),
                value: settings.transparentWidget,
                onChanged: (value) => settings.setTransparentWidget(value),
              ),

            const Divider(),

            _buildSectionHeader(
              context,
              t.translate('settings.dataManagement'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withAlpha(25)
                        : Colors.black.withAlpha(12),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildDataButton(
                          context,
                          icon: Icons.file_download_outlined,
                          label: t.translate('settings.importCSV'),
                          onTap: () => _importCsv(context),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDataButton(
                          context,
                          icon: Icons.file_upload_outlined,
                          label: t.translate('settings.exportCSV'),
                          onTap: () => _exportCsv(context),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withAlpha(25)
                        : Colors.black.withAlpha(12),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildDataButton(
                          context,
                          icon: Icons.cloud_upload_outlined,
                          label: t.translate('backup.save'),
                          onTap: () => _backupData(context),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDataButton(
                          context,
                          icon: Icons.cloud_download_outlined,
                          label: t.translate('backup.restore'),
                          onTap: () => _restoreBackup(context),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                t.translate('backup.hint'),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.white.withAlpha(100)
                      : Colors.black.withAlpha(100),
                ),
              ),
            ),

            // DIY Convert guide tile
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withAlpha(25)
                        : Colors.black.withAlpha(12),
                  ),
                ),
                child: ListTile(
                  leading: Icon(Icons.info_outline, color: AppColors.primary),
                  title: Text(
                    t.translate('settings.diyConvertTitle'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    t.translate('settings.diyConvertSubtitle'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showCsvFormatGuide(context),
                ),
              ),
            ),

            const Divider(),

            _buildSectionHeader(context, t.translate('settings.quotes')),
            SwitchListTile(
              secondary: const Icon(Icons.format_quote_rounded),
              title: Text(t.translate('settings.showQuotes')),
              subtitle: Text(
                t.translate('settings.showQuotesDesc'),
                style: const TextStyle(fontSize: 13),
              ),
              value: settings.showQuotes,
              onChanged: (value) => settings.setShowQuotes(value),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withAlpha(25)
                        : Colors.black.withAlpha(12),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildDataButton(
                          context,
                          icon: Icons.file_download_outlined,
                          label: t.translate('settings.importQuotes'),
                          onTap: () => _importQuotes(context),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDataButton(
                          context,
                          icon: Icons.delete_outline,
                          label: t.translate('settings.clearQuotes'),
                          onTap: () => _clearQuotes(context),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Text(
                t.translate('settings.importQuotesHint'),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.white.withAlpha(100)
                      : Colors.black.withAlpha(100),
                ),
              ),
            ),

            // Create Quotes guide tile
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withAlpha(25)
                        : Colors.black.withAlpha(12),
                  ),
                ),
                child: ListTile(
                  leading: Icon(Icons.info_outline, color: AppColors.primary),
                  title: Text(
                    t.translate('settings.createQuotesTitle'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    t.translate('settings.createQuotesSubtitle'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showCreateQuotesGuide(context),
                ),
              ),
            ),

            const Divider(),

            _buildSectionHeader(context, t.translate('settings.about')),
            _buildListTile(
              context,
              icon: Icons.info_outline,
              title: AppConstants.appName,
              subtitle: 'Version ${AppConstants.appVersion}',
            ),
            _buildListTile(
              context,
              icon: Icons.gavel_outlined,
              title: t.translate('settings.licenseAttribution'),
              onTap: () => _showLicenseAttributionDialog(context),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Manage-profiles dialog: add/rename/switch/delete, reachable from
  /// the settings row that shows the active profile's name.
  Future<void> _showProfilesDialog(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final t = TranslationService.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(t.translate('profiles.title')),
          content: SizedBox(
            width: 420,
            child: ListView(
              shrinkWrap: true,
              children: settings.profiles.map((profile) {
                final isActive = profile.id == settings.activeProfileId;
                return ListTile(
                  key: ValueKey('profile-${profile.id}'),
                  leading: Icon(
                    isActive
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: isActive ? AppColors.primary : null,
                  ),
                  title: Text(
                    profile.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: isActive,
                  onTap: () async {
                    await settings.selectUserProfile(profile.id);
                    if (!dialogContext.mounted) return;
                    await dialogContext.read<SessionProvider>().loadSessions(
                      profileId: profile.id,
                    );
                    if (dialogContext.mounted) setDialogState(() {});
                  },
                  trailing: PopupMenuButton<String>(
                    tooltip: t.translate('profiles.manage'),
                    onSelected: (action) async {
                      if (action == 'rename') {
                        final newName = await _promptProfileName(
                          dialogContext,
                          initialName: profile.name,
                          title: t.translate('profiles.rename'),
                        );
                        if (newName == null) return;
                        try {
                          await settings.renameUserProfile(profile.id, newName);
                          if (dialogContext.mounted) setDialogState(() {});
                        } catch (error) {
                          if (dialogContext.mounted) {
                            _showProfileError(dialogContext, error);
                          }
                        }
                      } else if (action == 'delete') {
                        await _confirmDeleteProfile(
                          dialogContext,
                          settings,
                          profile,
                        );
                        if (dialogContext.mounted) setDialogState(() {});
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'rename',
                        child: Text(t.translate('profiles.rename')),
                      ),
                      if (settings.profiles.length > 1)
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(t.translate('common.delete')),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                final name = await _promptProfileName(
                  dialogContext,
                  title: t.translate('profiles.add'),
                );
                if (name == null) return;
                try {
                  final profile = await settings.addUserProfile(name);
                  if (!dialogContext.mounted) return;
                  await dialogContext.read<SessionProvider>().loadSessions(
                    profileId: profile.id,
                  );
                  if (dialogContext.mounted) setDialogState(() {});
                } catch (error) {
                  if (dialogContext.mounted) {
                    _showProfileError(dialogContext, error);
                  }
                }
              },
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text(t.translate('profiles.add')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t.translate('common.done')),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _promptProfileName(
    BuildContext context, {
    String initialName = '',
    required String title,
  }) async {
    final t = TranslationService.of(context);
    final controller = TextEditingController(text: initialName);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: t.translate('settings.nameHint'),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            final normalized = value.trim();
            if (normalized.isNotEmpty) {
              Navigator.of(dialogContext).pop(normalized);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t.translate('common.cancel')),
          ),
          FilledButton(
            onPressed: () {
              final normalized = controller.text.trim();
              if (normalized.isNotEmpty) {
                Navigator.of(dialogContext).pop(normalized);
              }
            },
            child: Text(t.translate('common.save')),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  /// Confirmation dialog before deleting a profile. Note: this removes
  /// the profile entry only — deleting its session history is a
  /// separate, explicit step the caller must also trigger.
  Future<void> _confirmDeleteProfile(
    BuildContext context,
    SettingsProvider settings,
    UserProfile profile,
  ) async {
    final t = TranslationService.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.translate('profiles.delete')),
        content: Text(
          t.translate('profiles.deleteConfirm', args: {'name': profile.name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.translate('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(t.translate('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final sessions = context.read<SessionProvider>();
    await sessions.deleteSessionsForProfile(profile.id);
    await settings.deleteUserProfile(profile.id);
    await sessions.loadSessions(profileId: settings.activeProfileId);
  }

  void _showProfileError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error.toString().replaceFirst('Invalid argument(s): ', ''),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.error,
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

  String _getScreenControlLabel(TranslationService t, String control) {
    switch (control) {
      case 'on':
        return t.translate('settings.stayOn');
      case 'dim':
        return t.translate('settings.dim');
      case 'deviceTimeOut':
      default:
        return t.translate('settings.deviceTimeOut');
    }
  }

  String _getThemeModeLabel(TranslationService t, String mode) {
    switch (mode) {
      case 'light':
        return t.translate('settings.light');
      case 'dark':
        return t.translate('settings.dark');
      case 'deviceTheme':
      default:
        return t.translate('settings.deviceTheme');
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    // Check if the font scale is large to adjust layout
    final double textScale = MediaQuery.textScalerOf(context).scale(1);
    final bool isLargeText = textScale > 1.15;

    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: (subtitle != null || (isLargeText && trailing != null))
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (subtitle != null)
                  Text(subtitle, style: const TextStyle(fontSize: 13)),
                if (isLargeText && trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                    child: trailing,
                  ),
              ],
            )
          : null,
      trailing: (isLargeText || trailing == null)
          ? null
          : ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.45,
              ),
              child: trailing,
            ),
      onTap: onTap,
    );
  }

  Widget _buildIntervalTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required int value,
    required String soundValue,
    required ValueChanged<int> onMinutesChanged,
    required ValueChanged<String> onSoundChanged,
  }) {
    final t = TranslationService.of(context);
    final controller = TextEditingController(text: value > 0 ? '$value' : '');
    return ExpansionTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Flexible(child: Text(t.translate('settings.every'))),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: '0',
                    hintStyle: const TextStyle(fontSize: 14),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onSubmitted: (text) {
                    final parsed = int.tryParse(text);
                    if (parsed != null && parsed > 0) {
                      onMinutesChanged(parsed);
                    } else {
                      onMinutesChanged(0);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(t.translate('settings.min'))),
              IconButton(
                icon: const Icon(Icons.check, size: 20),
                tooltip: 'Apply',
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  final text = controller.text;
                  final parsed = int.tryParse(text);
                  if (parsed != null && parsed > 0) {
                    onMinutesChanged(parsed);
                  } else {
                    onMinutesChanged(0);
                    controller.clear();
                  }
                },
              ),
              Flexible(
                child: TextButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    onMinutesChanged(0);
                    controller.clear();
                  },
                  child: Text(
                    t.translate('settings.off'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (value > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: SoundPicker(
              label: 'Sound',
              currentSound: soundValue,
              onChanged: onSoundChanged,
            ),
          ),
        // Show warning when interval is large (>60 min) — likely to exceed session duration
        if (value > 60)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.orange.shade400,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t.translate('settings.intervalTooLongWarning'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade400,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildIntervalVibrationTile(
    BuildContext context, {
    required SettingsProvider settings,
  }) {
    final t = TranslationService.of(context);
    final config = settings.vibrationConfig;
    final controller = TextEditingController(
      text: config.intervalMinutes > 0 ? '${config.intervalMinutes}' : '',
    );
    return ExpansionTile(
      leading: const Icon(Icons.vibration),
      title: Text(t.translate('settings.intervalVibration')),
      subtitle: Text(
        config.intervalMinutes > 0
            ? t.translate(
                'settings.everyMin',
                args: {'minutes': '${config.intervalMinutes}'},
              )
            : t.translate('settings.disabled'),
        style: const TextStyle(fontSize: 13),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Flexible(child: Text(t.translate('settings.every'))),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: '0',
                    hintStyle: const TextStyle(fontSize: 14),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onSubmitted: (text) {
                    final parsed = int.tryParse(text);
                    if (parsed != null && parsed > 0) {
                      settings.setVibrationIntervalMinutes(parsed);
                    } else {
                      settings.setVibrationIntervalMinutes(0);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(t.translate('settings.min'))),
              IconButton(
                icon: const Icon(Icons.check, size: 20),
                tooltip: 'Apply',
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  final text = controller.text;
                  final parsed = int.tryParse(text);
                  if (parsed != null && parsed > 0) {
                    settings.setVibrationIntervalMinutes(parsed);
                  } else {
                    settings.setVibrationIntervalMinutes(0);
                    controller.clear();
                  }
                },
              ),
              Flexible(
                child: TextButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    settings.setVibrationIntervalMinutes(0);
                    controller.clear();
                  },
                  child: Text(
                    t.translate('settings.off'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (config.intervalMinutes > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: VibrationPicker(
              label: t.translate('settings.intervalVibration'),
              currentVibration: config.intervalVibration,
              onChanged: (vib) => settings.setIntervalVibration(vib),
            ),
          ),
        if (config.intervalMinutes > 60)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.orange.shade400,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t.translate('settings.intervalTooLongWarning'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade400,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDataButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primary;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: isDark
            ? Colors.white.withAlpha(12)
            : AppColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: primaryColor, size: 24),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final scaffold = ScaffoldMessenger.of(context);

    try {
      await CsvDataService.exportToCsv();
      if (context.mounted) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text('Data exported successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _backupData(BuildContext context) async {
    final t = TranslationService.of(context);
    final scaffold = ScaffoldMessenger.of(context);
    try {
      final settings = context.read<SettingsProvider>();
      final path = await BackupService.saveBackup(
        profiles: settings.profiles,
        activeProfileId: settings.activeProfileId,
      );
      if (path != null && context.mounted) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text(t.translate('backup.saved')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text('${t.translate('backup.failed')}: $error'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Restores a backup file, merging or overwriting per the user's
  /// choice (see [BackupService.createRestorePlan]). Snapshots the
  /// current profiles/sessions first so that if applying the plan
  /// fails partway (sessions written but the profile-list update
  /// throws), everything is rolled back to that snapshot instead of
  /// leaving sessions and profiles out of sync.
  Future<void> _restoreBackup(BuildContext context) async {
    final t = TranslationService.of(context);
    final scaffold = ScaffoldMessenger.of(context);
    try {
      final backup = await BackupService.pickBackup();
      if (backup == null || !context.mounted) return;
      final mode = await _showImportModeDialog(
        context,
        title: t.translate('backup.restore'),
        message: t.translate(
          'backup.restoreChoice',
          args: {
            'profiles': '${backup.profiles.length}',
            'sessions': '${backup.sessions.length}',
          },
        ),
        mergeDescription: t.translate('backup.mergeDescription'),
        overwriteDescription: t.translate('backup.overwriteDescription'),
      );
      if (mode == null || !context.mounted) return;

      final settings = context.read<SettingsProvider>();
      final originalProfiles = settings.profiles;
      final originalActiveProfileId = settings.activeProfileId;
      final originalSessions = await DatabaseService.getAllSessions();
      final restorePlan = BackupService.createRestorePlan(
        mode: mode,
        incoming: backup,
        existingProfiles: originalProfiles,
        existingActiveProfileId: originalActiveProfileId,
        existingSessions: originalSessions,
      );

      try {
        await BackupService.restoreBackup(restorePlan);
        await settings.replaceUserProfiles(
          restorePlan.profiles,
          activeProfileId: restorePlan.activeProfileId,
        );
      } catch (_) {
        await DatabaseService.replaceAllSessions(originalSessions);
        try {
          await settings.replaceUserProfiles(
            originalProfiles,
            activeProfileId: originalActiveProfileId,
          );
        } catch (_) {}
        rethrow;
      }

      if (!context.mounted) return;
      await context.read<SessionProvider>().loadSessions(
        profileId: restorePlan.activeProfileId,
      );
      if (context.mounted) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text(
              t.translate(
                mode == DataImportMode.merge
                    ? 'backup.merged'
                    : 'backup.restored',
              ),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text('${t.translate('backup.failed')}: $error'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importCsv(BuildContext context) async {
    final t = TranslationService.of(context);
    final scaffold = ScaffoldMessenger.of(context);

    try {
      final sessions = await CsvDataService.pickAndParseCsv();

      if (!context.mounted) return;

      if (sessions == null) {
        // User cancelled file picker
        return;
      }

      if (sessions.isEmpty) {
        scaffold.showSnackBar(
          SnackBar(
            content: const Text('No valid session data found in CSV.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final mode = await _showImportModeDialog(
        context,
        title: t.translate('settings.importCSVTitle'),
        message: t.translate(
          'settings.importCSVChoice',
          args: {'sessions': '${sessions.length}'},
        ),
        mergeDescription: t.translate('backup.mergeDescription'),
        overwriteDescription: t.translate(
          'settings.importCSVOverwriteDescription',
        ),
      );

      if (mode == null || !context.mounted) return;

      final count = await CsvDataService.importSessions(sessions, mode: mode);

      if (!context.mounted) return;

      await context.read<SessionProvider>().loadSessions();

      scaffold.showSnackBar(
        SnackBar(
          content: Text(
            t.translate(
              'settings.importCSVResult',
              args: {'sessions': '$count'},
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text('${t.translate('settings.importCSVFailed')}: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<DataImportMode?> _showImportModeDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String mergeDescription,
    required String overwriteDescription,
  }) {
    final t = TranslationService.of(context);
    return showDialog<DataImportMode>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(message),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  key: const ValueKey('import-mode-merge'),
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(DataImportMode.merge),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.translate('backup.merge'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mergeDescription,
                          style: Theme.of(dialogContext).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  key: const ValueKey('import-mode-overwrite'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error),
                  ),
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(DataImportMode.overwrite),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.translate('backup.overwrite'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          overwriteDescription,
                          style: Theme.of(dialogContext).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('import-mode-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t.translate('common.cancel')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importQuotes(BuildContext context) async {
    final scaffold = ScaffoldMessenger.of(context);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return; // user cancelled
      }

      final pickedFile = result.files.single;

      // Read file content — use explicit UTF-8 decoding
      // to correctly handle non-ASCII characters (Pali diacritics, CJK, etc.)
      String jsonString;
      if (pickedFile.bytes != null) {
        jsonString = utf8.decode(pickedFile.bytes!);
      } else if (pickedFile.path != null) {
        jsonString = await File(pickedFile.path!).readAsString(encoding: utf8);
      } else {
        throw Exception('Could not read file.');
      }

      if (jsonString.trim().isEmpty) {
        throw FormatException('The file is empty.');
      }

      // Validate JSON format
      final decoded = json.decode(jsonString);

      if (decoded is List) {
        // Simple list of strings
        for (final item in decoded) {
          if (item is! String) {
            throw FormatException(
              'Invalid format: each item in the array must be a string.',
            );
          }
        }
        if (decoded.isEmpty) {
          throw FormatException('The quotes array is empty.');
        }
      } else if (decoded is Map) {
        // Language-keyed map, e.g. {"en": [...], "vi": [...]}
        for (final entry in decoded.entries) {
          if (entry.value is! List) {
            throw FormatException(
              'Invalid format: "${entry.key}" must contain a list of quotes.',
            );
          }
          for (final item in entry.value as List) {
            if (item is! String) {
              throw FormatException(
                'Invalid format: each quote in "${entry.key}" must be a string.',
              );
            }
          }
        }
        if (decoded.isEmpty) {
          throw FormatException('The quotes object is empty.');
        }
      } else {
        throw FormatException(
          'Invalid format: file must contain a JSON array of strings '
          'or an object with language keys mapping to arrays of strings.',
        );
      }

      if (!context.mounted) return;

      // Count quotes for confirmation
      int quoteCount = 0;
      if (decoded is List) {
        quoteCount = decoded.length;
      } else {
        for (final list in (decoded as Map).values) {
          quoteCount += (list as List).length;
        }
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import Quotes'),
          content: Text(
            'Found $quoteCount quote${quoteCount == 1 ? '' : 's'} in the file.\n\n'
            'Your custom quotes will replace the built-in quotes '
            'on the session complete screen.\n\n'
            'Import now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Import'),
            ),
          ],
        ),
      );

      if (confirm != true || !context.mounted) return;

      await context.read<SettingsProvider>().setUserQuotes(jsonString);

      if (!context.mounted) return;
      scaffold.showSnackBar(
        SnackBar(
          content: Text(
            '$quoteCount quote${quoteCount == 1 ? '' : 's'} imported',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        scaffold.showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearQuotes(BuildContext context) async {
    final scaffold = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Custom Quotes'),
        content: const Text(
          'Remove all your imported custom quotes? '
          'Only the built-in quotes will be shown.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    await context.read<SettingsProvider>().clearUserQuotes();

    if (!context.mounted) return;
    scaffold.showSnackBar(
      SnackBar(
        content: const Text('Custom quotes cleared'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showCreateQuotesGuide(BuildContext context) {
    final t = TranslationService.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.translate('settings.createQuotesTitle')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.translate('settings.createQuotesDesc'),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const SelectableText(
                        'https://vpnry.github.io/ekatimer/create_quotes.html',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'Copy link',
                    onPressed: () {
                      Clipboard.setData(
                        const ClipboardData(
                          text:
                              'https://vpnry.github.io/ekatimer/create_quotes.html',
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link copied'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: Text(t.translate('settings.close')),
          ),
        ],
      ),
    );
  }

  void _showCsvFormatGuide(BuildContext context) {
    final t = TranslationService.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.translate('settings.diyConvertTitle')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.translate('settings.diyConvertDesc'),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'Here is the Meditation Timer CSV format:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 12),
              _buildSectionLabel(context, 'Column format'),
              const SizedBox(height: 4),
              const Text(
                'id — Auto-generated UUID for each session\n'
                'startTime — Session start time (ISO 8601)\n'
                'endTime — Session end time (ISO 8601)\n'
                'durationSeconds — Actual duration in seconds\n'
                'targetDurationSeconds — Planned duration in seconds (same as durationSeconds)\n'
                'timerMode — Timer mode: timed | endAt | unlimited\n'
                'completed — 1 session completed as planned | 0 stopped early\n'
                'quality — Optional numeric score from 0.0 to 5.0 (one decimal place)\n'
                'notes — Optional session notes',
                style: TextStyle(fontSize: 12, height: 1.6),
              ),
              const SizedBox(height: 16),
              _buildSectionLabel(context, 'Example CSV row'),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  'id,startTime,endTime,durationSeconds,targetDurationSeconds,timerMode,completed,quality,notes\n'
                  'fb004417-34f3-405c-8bdf-4340d5c44347,2015-01-01T00:00:00.000000,2015-01-01T02:12:52.000000,7972,7972,timed,1,4,good session\n'
                  'b9b8a49a-e9ed-4799-895e-bdb4db6776ad,2015-01-01T04:30:07.000000,2015-01-01T05:14:09.000000,2642,2642,timed,1,calm,nice session',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                t.translate('settings.diyConvertHint'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              const Text(
                'You can use AI to help you. Here is an example converter:',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      'https://vpnry.github.io/ekatimer/convert.html',
                      style: TextStyle(fontSize: 12, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'Copy link',
                    onPressed: () {
                      Clipboard.setData(
                        const ClipboardData(
                          text: 'https://vpnry.github.io/ekatimer/convert.html',
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link copied'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: Text(t.translate('settings.close')),
          ),
        ],
      ),
    );
  }

  void _showLicenseAttributionDialog(BuildContext context) {
    final t = TranslationService.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.translate('settings.licenseAttribution')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Meditation Timer ─────────────────────────────────────────
              _buildSectionLabel(context, 'Meditation Timer'),
              const SizedBox(height: 8),
              const Text(
                'Meditation Timer is distributed under the GNU General Public '
                'License v3 (GPLv3).',
              ),
              const SizedBox(height: 8),

              Text(
                'Modified source code is distributed with this release.\n'
                'Upstream Meditation Timer: https://github.com/vpnry/ekatimer',
                style: Theme.of(context).textTheme.bodySmall,
              ),

              const SizedBox(height: 8),
              _LicenseBox(
                'This program is distributed in the hope that it will be useful, '
                'but WITHOUT ANY WARRANTY; without even the implied warranty of '
                'MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.\n\n'
                'This software is provided "AS IS", without any express or implied '
                'warranty of any kind, including but not limited to the warranties '
                'of merchantability, fitness for a particular purpose, and '
                'non-infringement.\n\n'
                'In no event shall the authors or contributors be liable for any '
                'claims or damages arising from the use of this software.',
              ),

              const SizedBox(height: 20),
              const Divider(color: Colors.brown),
              const SizedBox(height: 12),

              // ── Meditation Assistant ──────────────────────────────
              _buildSectionLabel(context, 'Meditation Assistant'),
              const SizedBox(height: 8),
              const Text(
                'Meditation Timer was inspired by Meditation Assistant (GPLv3), '
                'authored by Trevor Slocum, and re-implemented many concepts '
                'from that project.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Source code: https://codeberg.org/tslocum/meditationassistant',
                style: TextStyle(fontSize: 13),
              ),

              const SizedBox(height: 24),
              const Divider(color: Colors.brown),
              const SizedBox(height: 8),

              // ── Audio Attributions ────────────────────────────────
              _buildSectionLabel(context, 'Audio Attributions'),
              const SizedBox(height: 16),
              _buildSectionLabel(context, 'Free Dhamma Gifts'),
              const SizedBox(height: 8),
              const Text(
                'Sadhu.wav',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Text('Author: Ven. Pa-Auk Tawya Sayadaw'),
              const Text(
                'Adapted from the Pa-Auk Forest Monastery\'s Chanting Audio - Dhamma Gift.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 20),
              _buildSectionLabel(context, 'CC0 1.0 Universal (Public Domain)'),
              const SizedBox(height: 8),
              _LicenseBox(
                'bell.wav\n'
                'gardenbird.wav\n'
                'bowl.wav\n'
                'bowlstrong.wav\n'
                'watch.wav',
              ),
              const SizedBox(height: 8),
              const Text(
                'Source: Joseph Sardin (BigSoundBank.com)',
                style: TextStyle(fontSize: 13),
              ),

              const SizedBox(height: 20),

              _buildSectionLabel(context, 'Creative Commons Attribution 4.0'),
              const SizedBox(height: 8),
              const Text(
                'ThreeBowl.wav',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Text('Author: naturenotesuk'),
              const Text(
                'https://freesound.org/s/667491/',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              const Text(
                'gong.wav',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Text('Author: reinsamba'),
              const Text(
                'https://freesound.org/s/46062/',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: Text(t.translate('settings.close')),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _LicenseBox extends StatelessWidget {
  final String text;
  const _LicenseBox(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          height: 1.5,
          color: Colors.black,
        ),
      ),
    );
  }
}
