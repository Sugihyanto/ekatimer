import 'package:flutter/material.dart';

import '../utils/responsive.dart';

/// Centres [child] and stops it growing past the width its window size class
/// allows.
///
/// On a phone this is a no-op — it returns [child] untouched rather than
/// wrapping it, so phone layouts keep exactly the render tree they had before
/// any of this existed.
///
/// Safe inside a sliver: with an unbounded height constraint [Center] shrinks to
/// its child's height instead of trying to fill the viewport.
class ContentColumn extends StatelessWidget {
  const ContentColumn({super.key, required this.child, this.maxWidth});

  final Widget child;

  /// Overrides the window size class's own limit. Useful where content is
  /// naturally wider than body text, such as a chart.
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final limit = maxWidth ?? WindowSize.of(context).contentMaxWidth;
    if (!limit.isFinite) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: limit),
        child: child,
      ),
    );
  }
}

/// Two panes side by side, split by a hairline rule.
///
/// Used where an iPad has the width to show a list and whatever it selects at
/// the same time. Callers decide when: this widget always splits, so the choice
/// stays visible at the call site next to the single-column alternative.
class TwoPaneLayout extends StatelessWidget {
  const TwoPaneLayout({
    super.key,
    required this.start,
    required this.end,
    this.startFlex = 2,
    this.endFlex = 3,
    this.startMaxWidth = 420,
  });

  /// The leading pane — the list, the picker, the table of contents.
  final Widget start;

  /// The trailing pane — the detail for whatever [start] has selected.
  final Widget end;

  final int startFlex;
  final int endFlex;

  /// Keeps the leading pane from growing with the window. Past roughly this
  /// width a list of short labels is mostly empty space, and the detail pane is
  /// the one that benefits from the room.
  final double startMaxWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          flex: startFlex,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: startMaxWidth),
            child: start,
          ),
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
        Flexible(flex: endFlex, child: end),
      ],
    );
  }
}
