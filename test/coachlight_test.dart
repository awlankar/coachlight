import 'package:coachlight/coachlight.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final first = GlobalKey();
  final second = GlobalKey();
  final missing = GlobalKey();
  late BuildContext ctx;

  Future<void> host(WidgetTester t) => t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (c) {
            ctx = c;
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ElevatedButton(key: first, onPressed: () {}, child: const Text('A')),
                const SizedBox(height: 40),
                ElevatedButton(key: second, onPressed: () {}, child: const Text('B')),
              ]),
            );
          }),
        ),
      ));

  List<CoachStep> steps() => [
        CoachStep(target: first, title: 'First', body: 'One'),
        CoachStep(target: missing, title: 'Gone'),
        CoachStep(target: second, title: 'Second', shape: CoachShape.circle),
      ];

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

  testWidgets('skip ends the tour', (t) async {
    await host(t);
    final result = CoachTour.show(ctx, steps: steps());
    await t.pumpAndSettle();
    await t.tap(find.text('Skip'));
    await t.pumpAndSettle();
    expect(await result, CoachResult.skipped);
  });

  testWidgets('a tap on the shade dismisses; a tap on the target moves on', (t) async {
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

  testWidgets('ends as dismissed when the screen goes away mid-tour', (t) async {
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
            next: 'Aage', skip: 'Chhodo', done: 'Theek', progress: (a, b) => '$a/$b'));
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
    final r1 = CoachTour.showOnce(ctx, id: 'home', memory: memory, steps: steps());
    await t.pumpAndSettle();
    await t.tap(find.text('Skip'));
    await t.pumpAndSettle();
    expect(await r1, CoachResult.skipped);
    expect(await CoachTour.showOnce(ctx, id: 'home', memory: memory, steps: steps()), isNull);
    memory.clear();
    expect(await memory.isSeen('home'), isFalse);
  });

  testWidgets('card stays on screen in a small window', (t) async {
    t.view.physicalSize = const Size(360, 400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await host(t);
    CoachTour.show(ctx, steps: steps());
    await t.pumpAndSettle();
    final card = t.getRect(
        find.ancestor(of: find.text('First'), matching: find.byType(Material)).first);
    expect(card.left, greaterThanOrEqualTo(0));
    expect(card.right, lessThanOrEqualTo(360));
    expect(card.top, greaterThanOrEqualTo(0));
    expect(card.bottom, lessThanOrEqualTo(400));
    expect(t.takeException(), isNull);
  });
}
