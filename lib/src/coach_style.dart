// coachlight - spotlight coach marks for Flutter.
// Author: Nitin Awlankar
// Licensed under the MIT License; see the LICENSE file.
//
// Visual options of the tour. Every field is optional; null colours and text
// styles fall back to the built-in defaults in coach_defaults.dart.

import 'package:flutter/widgets.dart';

import 'coach_defaults.dart';

/// Look of the tour. Colours left null use built-in light or dark defaults,
/// chosen from the platform brightness.
@immutable
class CoachStyle {
  /// Creates a style; every value has a sensible default.
  const CoachStyle({
    this.shadeColor = const Color(0xB8000000),
    this.ringColor = const Color(0xFFFFFFFF),
    this.ringWidth = 3,
    this.cardColor,
    this.accentColor,
    this.textColor,
    this.mutedColor,
    this.titleStyle,
    this.bodyStyle,
    this.progressStyle,
    this.buttonStyle,
    this.cardMaxWidth = 320,
    this.cardRadius = 16,
    this.screenMargin = 16,
    this.gap = 14,
    this.cardPadding = CoachDefaults.cardPadding,
    this.cardShadow = CoachDefaults.cardShadow,
    this.buttonMinSize = CoachDefaults.buttonMinSize,
    this.buttonRadius = CoachDefaults.buttonRadius,
    this.focusRingWidth = CoachDefaults.focusRingWidth,
    this.arrowSize = CoachDefaults.arrowSize,
    this.duration = const Duration(milliseconds: 280),
  });

  /// Colour laid over everything except the highlighted widget.
  final Color shadeColor;

  /// Outline drawn around the cut-out; use a transparent colour for none.
  final Color ringColor;

  /// Width of the outline.
  final double ringWidth;

  /// Background of the card (defaults to white, or dark grey in dark mode).
  final Color? cardColor;

  /// Colour of the title, the buttons and the focus ring.
  final Color? accentColor;

  /// Colour of the body text (defaults to near-black, or near-white in dark mode).
  final Color? textColor;

  /// Colour of the "1 of 3" counter (defaults to a muted grey).
  final Color? mutedColor;

  /// Title text style (defaults to 16 px semi-bold in [accentColor]).
  final TextStyle? titleStyle;

  /// Body text style (defaults to 14 px in the card's text colour).
  final TextStyle? bodyStyle;

  /// Style of the "1 of 3" counter (defaults to 12 px in [mutedColor]).
  final TextStyle? progressStyle;

  /// Style of the button labels (defaults to 14 px semi-bold; the colour is
  /// set by the button).
  final TextStyle? buttonStyle;

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

  /// Space between the card's edge and its content.
  final EdgeInsetsGeometry cardPadding;

  /// Shadow under the card; use an empty list for none.
  final List<BoxShadow> cardShadow;

  /// Smallest size of a button (keep the height at 44 or more for touch).
  final Size buttonMinSize;

  /// Corner radius of the buttons.
  final double buttonRadius;

  /// Width of the keyboard-focus outline on the buttons.
  final double focusRingWidth;

  /// Size of the arrow that points at the highlighted widget.
  final double arrowSize;
}
