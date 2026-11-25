// coachlight - spotlight coach marks for Flutter.
// Author: Nitin Awlankar
// Licensed under the MIT License; see the LICENSE file.
//
// Widget tests for CoachTour. They use a plain WidgetsApp, so no design
// library is needed to run them.

import 'package:coachlight/coachlight.dart';
import 'package:coachlight/src/coach_defaults.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final first = GlobalKey();
  final second = GlobalKey();
  final missing = GlobalKey();
  late BuildContext ctx;

  // Pumps a minimal app with two target widgets and stores its context in [ctx].
  Future<void> host(WidgetTester t) => t.pumpWidget(WidgetsApp(
        color: const Color(0xFFFFFFFF),
        pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
            PageRouteBuilder<T>(
                settings: settings,
                pageBuilder: (context, animation, secondaryAnimation) =>
                    builder(context)),
        home: Builder(builder: (c) {
          ctx = c;
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _Target(key: first, label: 'A'),
              const SizedBox(height: 40),
              _Target(key: second, label: 'B'),
            ]),
          );
        }),
      ));

  // Steps used by most tests: the middle one points at a widget that is not
  // built, so it must be skipped.
  List<CoachStep> steps() => [
        CoachStep(target: first, title: 'First', body: 'One'),
        CoachStep(target: missing, title: 'Gone'),
        CoachStep(target: second, title: 'Second', shape: CoachShape.circle),
      ];

  // Happy path: visible steps are shown in order and the tour completes.
  testWidgets('walks through visible steps and completes', (t) async {
    await host(t);
    final seen = <int>[];
    final result = CoachTour.show(ctx, steps: steps(), onStep: seen.add);
    await t.pumpAndSettle();
    expect(find.text('First'), findsOneWidget);
    expect(find.text('One'), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);
    await t.tap(find.text('Next'));
    await t.pumpAndSettle();
    expect(find.text('Gone'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    await t.tap(find.text('Got it'));
    await t.pumpAndSettle();
    expect(await result, CoachResult.completed);
    expect(seen, [0, 2]);
    expect(find.text('Second'), findsNothing);
  });

  testWidgets('Enter activates the focused button', (t) async {
    await host(t);
    CoachTour.show(ctx, steps: steps());
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('skip ends the tour', (t) async {
    await host(t);
    final result = CoachTour.show(ctx, steps: steps());
    await t.pumpAndSettle();
    await t.tap(find.text('Skip'));
    await t.pumpAndSettle();
    expect(await result, CoachResult.skipped);
  });

  testWidgets('a tap on the shade dismisses; a tap on the target moves on',
      (t) async {
    await host(t);
    final result = CoachTour.show(ctx, steps: steps());
    await t.pumpAndSettle();
    await t.tapAt(t.getCenter(find.byKey(first)));
    await t.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);
    await t.tapAt(const Offset(4, 4));
    await t.pumpAndSettle();
    expect(await result, CoachResult.dismissed);
  });

  testWidgets('back button dismisses', (t) async {
    await host(t);
    final result = CoachTour.show(ctx, steps: steps());
    await t.pumpAndSettle();
    final nav = t.state<NavigatorState>(find.byType(Navigator));
    nav.maybePop();
    await t.pumpAndSettle();
    expect(await result, CoachResult.dismissed);
  });

  testWidgets('ends as dismissed when the screen goes away mid-tour',
      (t) async {
    await host(t);
    final result = CoachTour.show(ctx, steps: steps());
    await t.pumpAndSettle();
    await t.pumpWidget(const SizedBox());
    expect(await result, CoachResult.dismissed);
  });

  testWidgets('nothing visible: completes without showing', (t) async {
    await host(t);
    final result = await CoachTour.show(ctx,
        steps: [CoachStep(target: missing, title: 'Gone')]);
    expect(result, CoachResult.completed);
    expect(find.text('Gone'), findsNothing);
  });

  testWidgets('custom labels', (t) async {
    await host(t);
    CoachTour.show(ctx,
        steps: steps(),
        labels: CoachLabels(
            next: 'Aage',
            skip: 'Chhodo',
            done: 'Theek',
            progress: (a, b) => '$a/$b'));
    await t.pumpAndSettle();
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('Chhodo'), findsOneWidget);
    await t.tap(find.text('Aage'));
    await t.pumpAndSettle();
    expect(find.text('Theek'), findsOneWidget);
  });

  testWidgets('showOnce shows a tour only once', (t) async {
    await host(t);
    final memory = InMemoryCoachMemory();
    final r1 =
        CoachTour.showOnce(ctx, id: 'home', memory: memory, steps: steps());
    await t.pumpAndSettle();
    await t.tap(find.text('Skip'));
    await t.pumpAndSettle();
    expect(await r1, CoachResult.skipped);
    expect(
        await CoachTour.showOnce(ctx,
            id: 'home', memory: memory, steps: steps()),
        isNull);
    memory.clear();
    expect(await memory.isSeen('home'), isFalse);
  });

  // Small window: the card must stay fully inside the screen.
  testWidgets('card stays on screen in a small window', (t) async {
    t.view.physicalSize = const Size(360, 400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await host(t);
    CoachTour.show(ctx, steps: steps());
    await t.pumpAndSettle();
    final card = t.getRect(find
        .ancestor(of: find.text('First'), matching: find.byType(DecoratedBox))
        .first);
    expect(card.left, greaterThanOrEqualTo(0));
    expect(card.right, lessThanOrEqualTo(360));
    expect(card.top, greaterThanOrEqualTo(0));
    expect(card.bottom, lessThanOrEqualTo(400));
    expect(t.takeException(), isNull);
  });

  // Decoration of the card: the nearest DecoratedBox around the title text.
  BoxDecoration cardDecoration(WidgetTester t) {
    final box = t.widget<DecoratedBox>(
        find.ancestor(of: find.text('First'), matching: find.byType(DecoratedBox)).first);
    return box.decoration as BoxDecoration;
  }

  // CoachStyle options must reach the widgets that draw them.
  testWidgets('style options are applied', (t) async {
    await host(t);
    const accent = Color(0xFFFF0000);
    const card = Color(0xFF00FF00);
    const text = Color(0xFF0000FF);
    const muted = Color(0xFF123456);
    CoachTour.show(ctx,
        steps: steps(),
        style: const CoachStyle(
          accentColor: accent,
          cardColor: card,
          textColor: text,
          mutedColor: muted,
          cardShadow: [],
          buttonMinSize: Size(120, 60),
        ));
    await t.pumpAndSettle();

    // Card background and shadow.
    expect(cardDecoration(t).color, card);
    expect(cardDecoration(t).boxShadow, isEmpty);
    // Title uses the accent colour, the counter the muted colour.
    expect(t.widget<Text>(find.text('First')).style?.color, accent);
    expect(t.widget<Text>(find.text('1 of 2')).style?.color, muted);
    // Body text inherits the base text colour set on the card.
    final base = t.widget<DefaultTextStyle>(
        find.ancestor(of: find.text('One'), matching: find.byType(DefaultTextStyle)).first);
    expect(base.style.color, text);
    // The button honours the minimum size.
    final button = t.getSize(
        find.ancestor(of: find.text('Next'), matching: find.byType(GestureDetector)).first);
    expect(button.width, greaterThanOrEqualTo(120));
    expect(button.height, greaterThanOrEqualTo(60));
  });

  testWidgets('light defaults are used without a style', (t) async {
    await host(t);
    CoachTour.show(ctx, steps: steps());
    await t.pumpAndSettle();
    expect(cardDecoration(t).color, CoachDefaults.lightSurface);
    expect(t.widget<Text>(find.text('First')).style?.color, CoachDefaults.lightAccent);
  });

  testWidgets('dark platform brightness switches to the dark defaults', (t) async {
    t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
    await host(t);
    CoachTour.show(ctx, steps: steps());
    await t.pumpAndSettle();
    expect(cardDecoration(t).color, CoachDefaults.darkSurface);
    expect(t.widget<Text>(find.text('First')).style?.color, CoachDefaults.darkAccent);
  });

  testWidgets('a custom card colour wins over the dark default', (t) async {
    t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
    await host(t);
    CoachTour.show(ctx,
        steps: steps(), style: const CoachStyle(cardColor: Color(0xFF00FF00)));
    await t.pumpAndSettle();
    expect(cardDecoration(t).color, const Color(0xFF00FF00));
  });

  testWidgets('Space activates the focused button', (t) async {
    await host(t);
    CoachTour.show(ctx, steps: steps());
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await t.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('Shift+Tab moves focus to Skip and Enter skips', (t) async {
    await host(t);
    final result = CoachTour.show(ctx, steps: steps());
    await t.pumpAndSettle();
    // Focus starts on the main button; Skip is the previous focus target.
    await t.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(await result, CoachResult.skipped);
  });

  testWidgets('large text scale keeps the card on screen', (t) async {
    t.view.physicalSize = const Size(360, 400);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await host(t);
    CoachTour.show(ctx, steps: steps());
    await t.pumpAndSettle();
    final card = t.getRect(
        find.ancestor(of: find.text('First'), matching: find.byType(DecoratedBox)).first);
    expect(card.left, greaterThanOrEqualTo(0));
    expect(card.right, lessThanOrEqualTo(360));
    expect(card.top, greaterThanOrEqualTo(0));
    expect(card.bottom, lessThanOrEqualTo(400));
    // No overflow errors even though the text is three times larger.
    expect(t.takeException(), isNull);
  });
}

// Simple fixed-size widget used as a highlight target.
class _Target extends StatelessWidget {
  const _Target({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 80,
        height: 40,
        child: Center(child: Text(label, style: const TextStyle())),
      );
}
