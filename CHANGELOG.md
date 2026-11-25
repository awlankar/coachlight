## 0.2.0

- Removed the dependency on `package:flutter/material.dart` (deprecated in Flutter 3.47). The package now uses only `package:flutter/widgets.dart`, so it needs no design library and works on every Flutter and Dart 3 release.
- The card no longer reads the app's `ThemeData`. It uses built-in light and dark colours chosen from the platform brightness; set `CoachStyle.cardColor`, `accentColor`, `titleStyle` and `bodyStyle` to match your app.
- New `CoachStyle` options: `accentColor`, `textColor`, `mutedColor`, `progressStyle`, `buttonStyle`, `cardPadding`, `cardShadow`, `buttonMinSize`, `buttonRadius`, `focusRingWidth`, `arrowSize`. All built-in values now live in one internal defaults file.
- Widened SDK range to Dart `>=3.0.0` and Flutter `>=3.10.0`.

## 0.1.1

- Updated README installation instructions for pub.dev.

## 0.1.0

- First version: spotlight steps, Next / Skip / Done, progress text,
  auto-scroll to the target, rotation-safe, RTL-aware, screen-reader labels,
  respects "reduce animations".
