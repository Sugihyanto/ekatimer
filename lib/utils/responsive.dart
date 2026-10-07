import 'package:flutter/widgets.dart';

/// Material 3's window size classes, which is how this app decides between the
/// phone layout and the iPad one.
///
/// The thresholds are Material's: 600 and 840 logical pixels of width. They are
/// deliberately width-only, because what breaks on a large screen is line
/// length and the span a control is stretched across — not the device. A phone
/// in landscape, an iPad sharing the screen with another app, and a Stage
/// Manager window dragged narrow all deserve the same treatment as a phone, and
/// all three report a small width.
enum WindowSize {
  /// Phones in portrait, and an iPad pane narrowed to a sidebar width.
  compact,

  /// Phones in landscape, iPad mini in portrait, a half-screen iPad.
  medium,

  /// iPads in landscape, and the 12.9" iPad in portrait.
  ///
  /// The only class that gets a second pane. An 11" iPad in portrait is 834pt
  /// and so stays a single column, which is what Apple's own apps do — two
  /// panes in that width leave both too cramped to read.
  expanded;

  static const double _mediumMinWidth = 600;
  static const double _expandedMinWidth = 840;

  static WindowSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static WindowSize fromWidth(double width) {
    if (width >= _expandedMinWidth) return WindowSize.expanded;
    if (width >= _mediumMinWidth) return WindowSize.medium;
    return WindowSize.compact;
  }

  /// Whether this width can carry a list and its detail side by side.
  bool get canSplit => this == WindowSize.expanded;

  /// The widest a single column of content may grow to.
  ///
  /// Phones are left alone — they are already narrow, and constraining them
  /// would only change layouts that are known to work. Anything wider is capped
  /// so that a duration slider, a row of chips or a paragraph of settings help
  /// does not stretch across a 1366pt iPad, where the eye loses the start of
  /// the line before it reaches the end.
  double get contentMaxWidth => switch (this) {
    WindowSize.compact => double.infinity,
    WindowSize.medium => 560,
    WindowSize.expanded => 640,
  };
}

extension WindowSizeContext on BuildContext {
  /// The window size class of the nearest [MediaQuery].
  WindowSize get windowSize => WindowSize.of(this);
}
