// coachlight - spotlight coach marks for Flutter.
// Author: Nitin Awlankar
// Licensed under the MIT License; see the LICENSE file.
//
// Built-in values used when no CoachStyle option is given. Keeping them
// in one place avoids magic numbers in the widget code.

import 'package:flutter/widgets.dart';

/// Built-in values used when [CoachStyle] leaves something null.
/// Not exported: change the look through `CoachStyle`.
abstract final class CoachDefaults {
  // Light colours.
  /// Card background in light mode.
  static const Color lightSurface = Color(0xFFFFFFFF);
  /// Body text colour in light mode.
  static const Color lightText = Color(0xFF1B1B1F);
  /// Counter text colour in light mode.
  static const Color lightMuted = Color(0xFF5E5E66);
  /// Title and button colour in light mode.
  static const Color lightAccent = Color(0xFF2F4FD8);

  // Dark colours (used when the platform brightness is dark).
  /// Card background in dark mode.
  static const Color darkSurface = Color(0xFF2A2B30);
  /// Body text colour in dark mode.
  static const Color darkText = Color(0xFFEDEDF0);
  /// Counter text colour in dark mode.
  static const Color darkMuted = Color(0xFFB4B4BC);
  /// Title and button colour in dark mode.
  static const Color darkAccent = Color(0xFF9DB4FF);

  // Pure black / white used on top of the accent colour.
  /// Button label colour on the light-mode accent.
  static const Color onLightAccent = Color(0xFFFFFFFF);
  /// Button label colour on the dark-mode accent.
  static const Color onDarkAccent = Color(0xFF000000);

  /// Used for the focus ring of a button that has no focus.
  /// Focus outline colour of a button that has no focus.
  static const Color transparent = Color(0x00000000);

  // Text sizes.
  /// Title font size.
  static const double titleSize = 16;
  /// Body font size.
  static const double bodySize = 14;
  /// Counter font size.
  static const double progressSize = 12;
  /// Button label font size.
  static const double buttonSize = 14;

  // Card.
  /// Space between the card edge and its content.
  static const EdgeInsetsGeometry cardPadding =
      EdgeInsetsDirectional.fromSTEB(18, 16, 12, 10);
  /// Shadow under the card.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x40000000), blurRadius: 18, offset: Offset(0, 6)),
  ];
  /// Space between title and body.
  static const double titleGap = 6;
  /// Space between the text and the button row.
  static const double actionsGap = 10;
  /// Extra end padding of title and body.
  static const double textEndPadding = 6;
  /// Smallest height the card is laid out with.
  static const double minCardHeight = 96;

  // Buttons.
  /// Smallest button size.
  static const Size buttonMinSize = Size(64, 44);
  /// Space between a button edge and its label.
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  /// Button corner radius.
  static const double buttonRadius = 22;
  /// Width of the keyboard-focus outline.
  static const double focusRingWidth = 2;
  /// Space between buttons.
  static const double buttonSpacing = 4;

  // Arrow pointing at the target.
  /// Size of the arrow pointing at the target.
  static const double arrowSize = 14;
  /// Corner radius of the arrow.
  static const double arrowRadius = 2;
  /// Where the arrow is parked when it is hidden.
  static const Offset offscreen = Offset(-1000, -1000);
}
