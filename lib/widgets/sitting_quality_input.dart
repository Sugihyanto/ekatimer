import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/translation_service.dart';
import '../theme/colors.dart';
import '../utils/sitting_quality.dart';
import 'quality_rating_label.dart';

class SittingQualityInput extends StatefulWidget {
  final TextEditingController controller;

  const SittingQualityInput({super.key, required this.controller});

  @override
  State<SittingQualityInput> createState() => _SittingQualityInputState();
}

class _SittingQualityInputState extends State<SittingQualityInput> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant SittingQualityInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _clearRating() => widget.controller.clear();

  @override
  Widget build(BuildContext context) {
    final t = TranslationService.of(context);
    final theme = Theme.of(context);
    final rawValue = widget.controller.text;
    final rating = SittingQuality.rating(rawValue);
    final hasInput = rawValue.trim().isNotEmpty;
    final isValid = SittingQuality.isValidInput(rawValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.star_outline_rounded,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t.translate('quality.title'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            if (hasInput)
              TextButton(
                onPressed: _clearRating,
                child: Text(t.translate('quality.clear')),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('quality-number-input'),
          controller: widget.controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            TextInputFormatter.withFunction((oldValue, newValue) {
              return SittingQuality.isValidKeystroke(newValue.text)
                  ? newValue
                  : oldValue;
            }),
          ],
          decoration: InputDecoration(
            hintText: t.translate('quality.hint'),
            suffixIcon: const Icon(
              Icons.star_rounded,
              size: 20,
              color: AppColors.primary,
            ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            errorText: hasInput && !isValid
                ? t.translate('quality.invalid')
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 6),
        // Only the star preview sits below the field. The empty state needs
        // no caption here: the same 'quality.hint' text is already the
        // field's placeholder, and showing it twice read as a stray
        // duplicate rather than as guidance.
        if (rating != null)
          QualityRatingLabel(
            key: const ValueKey('quality-rating-preview'),
            rating: rating,
            iconSize: 14,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        const SizedBox(height: 4),
        Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          // Draw the expansion tile's ink above a colored parent card.
          child: Material(
            type: MaterialType.transparency,
            child: ExpansionTile(
              key: const ValueKey('quality-notes-info'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              visualDensity: VisualDensity.compact,
              leading: const Icon(Icons.info_outline_rounded, size: 20),
              title: Text(
                t.translate('quality.notesTitle'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    t.translate('quality.notesBody'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
