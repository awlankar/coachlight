import 'package:flutter/widgets.dart';

/// Look of the tour. Colours left null follow the app's theme.
@immutable
class CoachStyle {
  /// Creates a style; every value has a sensible default.
  const CoachStyle({
    this.shadeColor = const Color(0xB8000000),
    this.ringColor = const Color(0xFFFFFFFF),
    this.ringWidth = 3,
    this.cardColor,
    this.titleStyle,
    this.bodyStyle,
    this.cardMaxWidth = 320,
    this.cardRadius = 16,
    this.screenMargin = 16,
    this.gap = 14,
    this.duration = const Duration(milliseconds: 280),
  });

  /// Colour laid over everything except the highlighted widget.
  final Color shadeColor;

  /// Outline drawn around the cut-out; use a transparent colour for none.
  final Color ringColor;

  /// Width of the outline.
  final double ringWidth;

  /// Background of the card (defaults to the theme's surface colour).
  final Color? cardColor;

  /// Title text style (defaults to the theme's titleMedium in primary).
  final TextStyle? titleStyle;

  /// Body text style (defaults to the theme's bodyMedium).
  final TextStyle? bodyStyle;

  /// Widest the card may be.
  final double cardMaxWidth;

  /// Corner radius of the card.
  final double cardRadius;

  /// Smallest distance between the card and the screen edges.
  final double screenMargin;

  /// Distance between the cut-out and the card.
  final double gap;

  /// Fade and move animation length. Ignored when the device asks for
  /// reduced motion.
  final Duration duration;
}
