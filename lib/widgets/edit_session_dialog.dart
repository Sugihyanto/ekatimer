// lib/widgets/edit_session_dialog.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/meditation_session.dart';
import '../services/translation_service.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../utils/sitting_quality.dart';
import 'sitting_quality_input.dart';

/// Shows a modal bottom sheet to edit a session's date, start time, and duration.
Future<MeditationSession?> showEditSessionDialog(
  BuildContext context,
  MeditationSession session,
) {
  return showModalBottomSheet<MeditationSession?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _EditSessionDialog(session: session),
  );
}

class _EditSessionDialog extends StatefulWidget {
  final MeditationSession session;

  const _EditSessionDialog({required this.session});

  @override
  State<_EditSessionDialog> createState() => _EditSessionDialogState();
}

class _EditSessionDialogState extends State<_EditSessionDialog> {
  late DateTime _selectedDate;
  late int _startHour;
  late int _startMinute;
  late int _startSecond;
  late int _durationHours;
  late int _durationMinutes;
  late int _durationSeconds;
  late TextEditingController _qualityController;
  late String _notes;
  late TextEditingController _notesController;

  late FixedExtentScrollController _startHourCtrl;
  late FixedExtentScrollController _startMinuteCtrl;
  late FixedExtentScrollController _startSecondCtrl;
  late FixedExtentScrollController _durationHourCtrl;
  late FixedExtentScrollController _durationMinuteCtrl;
  late FixedExtentScrollController _durationSecondCtrl;

  bool _showStartTimePicker = false;
  bool _showDurationPicker = false;

  @override
  void initState() {
    super.initState();
    final session = widget.session;

    _selectedDate = DateTime(
      session.startTime.year,
      session.startTime.month,
      session.startTime.day,
    );
    _startHour = session.startTime.hour;
    _startMinute = session.startTime.minute;
    _startSecond = session.startTime.second;

    _durationHours = session.durationSeconds ~/ 3600;
    _durationMinutes = (session.durationSeconds % 3600) ~/ 60;
    _durationSeconds = session.durationSeconds % 60;
    _qualityController = TextEditingController(text: session.quality ?? '');
    _notes = session.notes ?? '';
    _notesController = TextEditingController(text: _notes);
    _notesController.addListener(() {
      _notes = _notesController.text;
    });

    _startHourCtrl = FixedExtentScrollController(initialItem: _startHour);
    _startMinuteCtrl = FixedExtentScrollController(initialItem: _startMinute);
    _startSecondCtrl = FixedExtentScrollController(initialItem: _startSecond);
    _durationHourCtrl = FixedExtentScrollController(
      initialItem: _durationHours,
    );
    _durationMinuteCtrl = FixedExtentScrollController(
      initialItem: _durationMinutes,
    );
    _durationSecondCtrl = FixedExtentScrollController(
      initialItem: _durationSeconds,
    );
  }

  @override
  void dispose() {
    _qualityController.dispose();
    _notesController.dispose();
    _startHourCtrl.dispose();
    _startMinuteCtrl.dispose();
    _startSecondCtrl.dispose();
    _durationHourCtrl.dispose();
    _durationMinuteCtrl.dispose();
    _durationSecondCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = TranslationService.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = isDark ? AppTheme.darkTheme : AppTheme.lightTheme;

    // showModalBottomSheet's useSafeArea only guards the top, left and right
    // edges, so the sheet still runs underneath the system navigation bar and
    // its Cancel/Save row ends up unreachable. viewInsets covers the keyboard
    // and viewPadding the navigation bar; the larger of the two applies,
    // because when the keyboard is open it already covers the nav bar and
    // adding both would leave a large empty gap.
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = math.max(
      mediaQuery.viewInsets.bottom,
      mediaQuery.viewPadding.bottom,
    );

    return Theme(
      data: theme,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: bottomInset + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Center(
                child: Text(
                  t.translate('editSession.title'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 20),

              // ── Date ──
              _buildSectionLabel(context, t.translate('editSession.date')),
              const SizedBox(height: 8),
              _buildDateTile(context),
              const SizedBox(height: 20),

              // ── Start Time ──
              _buildSectionLabel(context, t.translate('editSession.startTime')),
              const SizedBox(height: 8),
              _buildExpandableTimeTile(
                context,
                value:
                    '${_startHour.toString().padLeft(2, '0')}:${_startMinute.toString().padLeft(2, '0')}:${_startSecond.toString().padLeft(2, '0')}',
                isExpanded: _showStartTimePicker,
                onTap: () => setState(
                  () => _showStartTimePicker = !_showStartTimePicker,
                ),
              ),
              if (_showStartTimePicker) ...[
                const SizedBox(height: 8),
                _buildLabelRow(context, 'HH', 'mm', 'ss'),
                _buildWheelRow(context, [
                  _buildWheel(context, 0, 23, _startHourCtrl, (v) {
                    setState(() => _startHour = v);
                  }),
                  _buildWheel(context, 0, 59, _startMinuteCtrl, (v) {
                    setState(() => _startMinute = v);
                  }),
                  _buildWheel(context, 0, 59, _startSecondCtrl, (v) {
                    setState(() => _startSecond = v);
                  }),
                ]),
              ],
              const SizedBox(height: 20),

              // ── Duration ──
              _buildSectionLabel(context, t.translate('editSession.duration')),
              const SizedBox(height: 8),
              _buildExpandableTimeTile(
                context,
                value:
                    '${_durationHours.toString().padLeft(2, '0')}:${_durationMinutes.toString().padLeft(2, '0')}:${_durationSeconds.toString().padLeft(2, '0')}',
                isExpanded: _showDurationPicker,
                onTap: () =>
                    setState(() => _showDurationPicker = !_showDurationPicker),
              ),
              if (_showDurationPicker) ...[
                const SizedBox(height: 8),
                _buildLabelRow(context, 'HH', 'mm', 'ss'),
                _buildWheelRow(context, [
                  _buildWheel(context, 0, 99, _durationHourCtrl, (v) {
                    setState(() => _durationHours = v);
                  }),
                  _buildWheel(context, 0, 59, _durationMinuteCtrl, (v) {
                    setState(() => _durationMinutes = v);
                  }),
                  _buildWheel(context, 0, 59, _durationSecondCtrl, (v) {
                    setState(() => _durationSeconds = v);
                  }),
                ]),
              ],
              const SizedBox(height: 24),

              // ── Preview ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withAlpha(10)
                      : Colors.black.withAlpha(5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_durationHours.toString().padLeft(2, '0')}:${_durationMinutes.toString().padLeft(2, '0')}:${_durationSeconds.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w300,
                            letterSpacing: 2,
                            color: AppColors.primary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_selectedDate.year}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.day.toString().padLeft(2, '0')}  '
                      '${_startHour.toString().padLeft(2, '0')}:${_startMinute.toString().padLeft(2, '0')}:${_startSecond.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Quality of sitting ──
              SittingQualityInput(controller: _qualityController),
              const SizedBox(height: 20),

              // ── Notes ──
              _buildSectionLabel(context, t.translate('editSession.notes')),
              const SizedBox(height: 8),
              _buildNotesField(context),
              const SizedBox(height: 24),

              // ── Buttons ──
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(t.translate('common.cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _onSave,
                      child: Text(t.translate('common.save')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesField(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = TranslationService.of(context);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(20)
              : Colors.black.withAlpha(12),
        ),
      ),
      child: TextField(
        controller: _notesController,
        maxLines: 3,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: t.translate('editSession.notesHint'),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          hintStyle: TextStyle(
            color: isDark
                ? Colors.white.withAlpha(60)
                : Colors.black.withAlpha(60),
          ),
        ),
        style: const TextStyle(fontSize: 15),
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildExpandableTimeTile(
    BuildContext context, {
    required String value,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withAlpha(10)
              : Colors.black.withAlpha(5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isExpanded
                ? AppColors.primary.withAlpha(80)
                : (isDark
                      ? Colors.white.withAlpha(20)
                      : Colors.black.withAlpha(12)),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2,
                ),
              ),
            ),
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelRow(BuildContext context, String c1, String c2, String c3) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: Text(
                c1,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Center(
              child: Text(
                c2,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Center(
              child: Text(
                c3,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTile(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _pickDate,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withAlpha(10)
              : Colors.black.withAlpha(5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withAlpha(20)
                : Colors.black.withAlpha(12),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${_selectedDate.year}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.day.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textSecondaryLight),
          ],
        ),
      ),
    );
  }

  Widget _buildWheelRow(BuildContext context, List<Widget> wheels) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: wheels.map((w) => Expanded(child: w)).toList()),
    );
  }

  Widget _buildWheel(
    BuildContext context,
    int min,
    int max,
    FixedExtentScrollController controller,
    ValueChanged<int> onChanged,
  ) {
    final items = List.generate(max - min + 1, (i) => min + i);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 120,
      child: Stack(
        children: [
          // Highlight bar
          Center(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withAlpha(15)
                    : AppColors.primary.withAlpha(12),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          // Wheel
          ListWheelScrollView(
            controller: controller,
            itemExtent: 36,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (index) => onChanged(items[index]),
            children: items.map((v) {
              return Center(
                child: Text(
                  v.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final baseline = DateTime(2000);
    // An existing record may be older than the default range or imported
    // with a future date. Always let the user open it and correct its date.
    final originalDate = DateUtils.dateOnly(widget.session.startTime);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: originalDate.isBefore(baseline) ? originalDate : baseline,
      lastDate: originalDate.isAfter(today) ? originalDate : today,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(
              ctx,
            ).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  void _onSave() {
    if (!SittingQuality.isValidInput(_qualityController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            TranslationService.of(context).translate('quality.invalid'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final totalDurationSeconds =
        _durationHours * 3600 + _durationMinutes * 60 + _durationSeconds;

    if (totalDurationSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Duration must be greater than 0'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selectedStartTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startHour,
      _startMinute,
      _startSecond,
    );

    final original = widget.session;
    final originalWholeSecond = DateTime(
      original.startTime.year,
      original.startTime.month,
      original.startTime.day,
      original.startTime.hour,
      original.startTime.minute,
      original.startTime.second,
    );
    final startChanged = selectedStartTime != originalWholeSecond;
    final durationChanged = totalDurationSeconds != original.durationSeconds;
    final newStartTime = startChanged ? selectedStartTime : original.startTime;
    // Editing Quality/notes must not discard pauses or timestamp precision.
    // Recompute the end only when the user changes a time field.
    final newEndTime = startChanged || durationChanged
        ? newStartTime.add(Duration(seconds: totalDurationSeconds))
        : original.endTime;
    final quality = SittingQuality.normalize(_qualityController.text);
    final notes = _notes.trim().isNotEmpty ? _notes.trim() : null;

    final updated = widget.session.copyWith(
      startTime: newStartTime,
      endTime: newEndTime,
      durationSeconds: totalDurationSeconds,
      quality: quality,
      clearQuality: quality == null,
      notes: notes,
      clearNotes: notes == null,
    );

    Navigator.of(context).pop(updated);
  }
}
