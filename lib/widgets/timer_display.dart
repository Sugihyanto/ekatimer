import 'dart:math';
import 'package:flutter/material.dart';
import '../services/translation_service.dart';

class TimerDisplay extends StatelessWidget {
  final String timeText;
  final String? subtitleLabel;
  final String? subtitleValue;
  final bool isPaused;
  final double progress;
  final double size;

  const TimerDisplay({
    super.key,
    required this.timeText,
    this.subtitleLabel,
    this.subtitleValue,
    this.isPaused = false,
    this.progress = 1.0,
    this.size = 280,
  });

  @override
  Widget build(BuildContext context) {
    // Scale factor relative to the default 280px size, so inner
    // spacings and fonts shrink proportionally on smaller circles.
    final double scale = (size / 280).clamp(0.5, 1.0);
    final double innerPadding = (24 * scale).clamp(12.0, 24.0);
    final double timeFontSize = (64 * scale).clamp(32.0, 64.0);
    final double subtitleFontSize = (14 * scale).clamp(10.0, 14.0);
    final double badgeFontSize = (12 * scale).clamp(10.0, 12.0);
    final double gapSmall = (8 * scale).clamp(4.0, 8.0);
    final double gapLarge = (12 * scale).clamp(6.0, 12.0);
    final double badgeHPadding = (16 * scale).clamp(10.0, 16.0);
    final double badgeVPadding = (6 * scale).clamp(4.0, 6.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withAlpha(15)
                      : Colors.black.withAlpha(10),
                ),
              ),
              if (progress < 1.0)
                SizedBox(
                  width: size,
                  height: size,
                  child: CustomPaint(
                    painter: _ArcPainter(
                      progress: progress,
                      color: Theme.of(context).colorScheme.primary,
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withAlpha(20)
                          : Colors.black.withAlpha(15),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(innerPadding),
                // The badge and subtitle must fit as well as the digits when
                // a landscape circle is small or accessibility text is large.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: size - innerPadding * 2,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedOpacity(
                          opacity: isPaused ? 0.4 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              timeText,
                              style: TextStyle(
                                fontSize: timeFontSize,
                                fontWeight: FontWeight.w200,
                                color: Theme.of(context).colorScheme.onSurface,
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                        ),
                        if (subtitleLabel != null &&
                            subtitleValue != null &&
                            subtitleValue!.isNotEmpty) ...[
                          SizedBox(height: gapSmall),
                          Text(
                            '$subtitleLabel: $subtitleValue',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: subtitleFontSize,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withAlpha(150),
                            ),
                          ),
                        ],
                        if (isPaused) ...[
                          SizedBox(height: gapLarge),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: badgeHPadding,
                              vertical: badgeVPadding,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withAlpha(30),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              TranslationService.of(
                                context,
                              ).translate('meditation.paused'),
                              style: TextStyle(
                                fontSize: badgeFontSize,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _ArcPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const startAngle = -pi / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // change sweep angle to negative to make it go clockwise, possitive angle goes counter-clockwise by default in Flutter

    final sweepAngle = -2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
