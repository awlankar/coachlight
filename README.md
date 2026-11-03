# coachlight

Spotlight coach marks for Flutter. The screen is dimmed, one widget at a time
is cut out and a small card explains it, with **Next**, **Skip** and a
"1 of 3" counter.

- No dependencies beyond the Flutter SDK
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
`CoachStyle`.

## How it ends

| Result      | When                                              |
| ----------- | ------------------------------------------------- |
| `completed` | Done pressed on the last step                     |
| `skipped`   | Skip pressed                                      |
| `dismissed` | Tap on the dimmed area, or the system back button |

A tap on the highlighted widget moves to the next step.


## Getting it

Until it is on pub.dev, use it from Git:

```yaml
dependencies:
  coachlight:
    git:
      url: https://github.com/<you>/coachlight.git
      ref: v0.1.0
```

## Try the example

```
cd example
flutter create .   # one-time: adds the platform folders
flutter run
```
