# coachlight

Spotlight coach marks for Flutter. The screen is dimmed, one widget at a time
is cut out and a small card explains it, with **Next**, **Skip** and a
"1 of 3" counter.

- No dependencies beyond the Flutter SDK, and no Material or Cupertino import:
  works on Flutter 3.10+ / Dart 3.0+ and on the newest releases
- Steps whose widget is not on screen are skipped automatically
- Scrolls the target into view; re-measures on rotation and resize
- Places the card above or below the target and keeps it on screen
- Works right-to-left, with large text and with screen readers
- Respects the device's "remove animations" setting
- Stores nothing: remembering which tours were seen is up to you
  (`CoachMemory`)

## Use

```dart
final addKey = GlobalKey();

FloatingActionButton(key: addKey, onPressed: add, child: const Icon(Icons.add));

final result = await CoachTour.show(context, steps: [
  CoachStep(target: addKey, title: 'Add', body: 'Create a new item.'),
]);
// result: CoachResult.completed | skipped | dismissed
```

Show a tour only once:

```dart
await CoachTour.showOnce(context,
    id: 'home', memory: myMemory, steps: steps);
```

Translate the buttons with `CoachLabels` and change the look with
`CoachStyle`. The card does not read your app's `ThemeData`; it uses light or
dark defaults from the platform brightness. Set `cardColor`, `accentColor`,
`titleStyle` and `bodyStyle` to match your app.

## How it ends

| Result      | When                                              |
| ----------- | ------------------------------------------------- |
| `completed` | Done pressed on the last step                     |
| `skipped`   | Skip pressed                                      |
| `dismissed` | Tap on the dimmed area, or the system back button |

A tap on the highlighted widget moves to the next step.


## Installation

Add CoachLight to your Flutter project:

```bash
flutter pub add coachlight
```

Or add it directly to your `pubspec.yaml`:

```yaml
dependencies:
  coachlight: ^0.2.0
```

## Try the example

The example demonstrates every feature: rectangle and circle cut-outs, scrolling
to an off-screen target, skipped steps, translated labels, three styles,
right-to-left, light and dark themes, `showOnce` and the result callbacks.

The example app needs Flutter 3.47 or newer (it uses `material_ui`); the
package itself works on older versions.

```
cd example
flutter create --platforms=android,ios,windows .   # one-time, pick your platforms
flutter run
```
