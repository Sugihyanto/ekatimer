import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../utils/time_utils.dart';
import '../services/translation_service.dart';
import '../utils/sitting_quality.dart';
import 'quality_rating_label.dart';

class SessionCard extends StatefulWidget {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final bool completed;
  final String? quality;
  final String? notes;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const SessionCard({
    super.key,
    required this.id,
    required this.startTime,
    this.endTime,
    required this.durationSeconds,
    this.completed = true,
    this.quality,
    this.notes,
    this.onTap,
    this.onDelete,
    this.onEdit,
  });

  @override
  State<SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<SessionCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeCategory = TimeUtils.getTimeOfDayCategory(widget.startTime);
    // Older sessions recorded before endTime was tracked have none
    // stored; derive a display value from start + duration instead.
    final displayedEndTime =
        widget.endTime ??
        widget.startTime.add(Duration(seconds: widget.durationSeconds));
    final qualityRating = SittingQuality.rating(widget.quality);
    final notes = widget.notes?.trim();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getTimeColor(timeCategory).withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getTimeIcon(timeCategory),
                  color: _getTimeColor(timeCategory),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            TimeUtils.formatDate(widget.startTime),
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        if (widget.onEdit != null)
                          IconButton(
                            key: const ValueKey('session-edit-button'),
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: theme.colorScheme.onSurface.withAlpha(100),
                            ),
                            visualDensity: VisualDensity.compact,
                            onPressed: widget.onEdit,
                          ),
                        if (widget.onDelete != null)
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: theme.colorScheme.onSurface.withAlpha(100),
                            ),
                            visualDensity: VisualDensity.compact,
                            onPressed: widget.onDelete,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${TimeUtils.formatTimeOfDay(widget.startTime)} → ${TimeUtils.formatTimeOfDay(displayedEndTime)}',
                              key: const ValueKey('session-start-end'),
                              maxLines: 1,
                              softWrap: false,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withAlpha(
                                  150,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (!widget.completed) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              TranslationService.of(
                                context,
                              ).translate('history.stopped'),
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          TimeUtils.formatDurationReadable(
                            widget.durationSeconds,
                          ),
                          key: const ValueKey('session-duration'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(150),
                          ),
                        ),
                        if (qualityRating != null)
                          QualityRatingLabel(
                            key: const ValueKey('session-quality'),
                            rating: qualityRating,
                            iconSize: 13,
                            gap: 3,
                            starSpacing: 0,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    if (notes != null && notes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        notes,
                        key: const ValueKey('session-notes'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(180),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTimeIcon(String category) {
    switch (category) {
      case 'Morning':
        return Icons.wb_sunny;
      case 'Afternoon':
        return Icons.wb_cloudy;
      case 'Evening':
        return Icons.nights_stay;
      case 'Night':
        return Icons.bedtime;
      default:
        return Icons.schedule;
    }
  }

  Color _getTimeColor(String category) {
    switch (category) {
      case 'Morning':
        return const Color(0xFFFFB347);
      case 'Afternoon':
        return const Color(0xFF5B8DEF);
      case 'Evening':
        return const Color(0xFF9B59B6);
      case 'Night':
        return const Color(0xFF2C3E50);
      default:
        return AppColors.primary;
    }
  }
}
