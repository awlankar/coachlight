// coachlight - spotlight coach marks for Flutter.
// Author: Nitin Awlankar
// Licensed under the MIT License; see the LICENSE file.
//
// Public entry point (CoachTour) and the private overlay that draws the
// dimmed screen, the cut-out around the target and the explanation card.
// Only package:flutter/widgets.dart is used, so no design library is needed.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'coach_defaults.dart';
import 'coach_labels.dart';
import 'coach_memory.dart';
import 'coach_step.dart';
import 'coach_style.dart';

/// How a tour ended.
enum CoachResult {
  /// The last step was closed with the done button.
  completed,

  /// The skip button was pressed.
  skipped,

  /// Closed by tapping the dimmed area or with the system back button.
  dismissed,
}

/// Shows spotlight tours over the current screen.
abstract final class CoachTour {
  /// Whether at least one of [steps] points at a widget that is laid out.
  static bool anyVisible(List<CoachStep> steps) => steps.any((s) => _boxOf(s) != null);

  /// Shows [steps] one after another and completes when the tour closes.
  ///
  /// Steps whose widget is not laid out are left out; when none is,
  /// [CoachResult.completed] is returned without showing anything.
  /// [onStep] receives the index (in [steps]) of each step as it appears.
  static Future<CoachResult> show(
    BuildContext context, {
    required List<CoachStep> steps,
    CoachLabels labels = const CoachLabels(),
    CoachStyle style = const CoachStyle(),
    ValueChanged<int>? onStep,
  }) async {
    // Indices (into [steps]) of the steps whose widget is on screen right now.
    final shown = <int>[
      for (var i = 0; i < steps.length; i++)
        if (_boxOf(steps[i]) != null) i,
    ];
    // Nothing to point at: finish at once instead of showing an empty overlay.
    if (shown.isEmpty) return CoachResult.completed;
    // The route only knows the visible steps, so the callback maps its index
    // back to the caller's original index.
    final route = _CoachRoute(
      steps: [for (final i in shown) steps[i]],
      onStep: onStep == null ? null : (i) => onStep(shown[i]),
      labels: labels,
      style: style,
      reduceMotion: MediaQuery.maybeOf(context)?.disableAnimations ?? false,
    );
    // Completes however the tour ends, even if the navigator itself goes away.
    unawaited(Navigator.of(context).push<CoachResult>(route).then(route.finish));
    return route.result.future;
  }

  /// Shows the tour [id] unless [memory] says it was seen, then marks it as
  /// seen however it ended. Returns null when nothing was shown.
  static Future<CoachResult?> showOnce(
    BuildContext context, {
    required String id,
    required CoachMemory memory,
    required List<CoachStep> steps,
    CoachLabels labels = const CoachLabels(),
    CoachStyle style = const CoachStyle(),
    ValueChanged<int>? onStep,
  }) async {
    // Already shown before: do nothing.
    if (await memory.isSeen(id)) return null;
    // The widget may have gone away while the memory was read, or no target is
    // laid out yet. In both cases the tour is not marked as seen.
    if (!context.mounted || !anyVisible(steps)) return null;
    final result =
        await show(context, steps: steps, labels: labels, style: style, onStep: onStep);
    // Mark it as seen however the tour ended (done, skipped or dismissed).
    await memory.markSeen(id);
    return result;
  }
}

/// The laid-out render box of the step's target, or null when the widget is
/// not built, not attached or not yet sized.
RenderBox? _boxOf(CoachStep step) {
  final object = step.target.currentContext?.findRenderObject();
  if (object is! RenderBox || !object.attached || !object.hasSize) return null;
  return object;
}

/// Route that hosts the tour above the current screen. A PopupRoute keeps the
/// screen below visible and handles the system back button for us.
class _CoachRoute extends PopupRoute<CoachResult> {
  _CoachRoute({
    required this.steps,
    required this.onStep,
    required this.labels,
    required this.style,
    required this.reduceMotion,
  });

  final List<CoachStep> steps;
  final ValueChanged<int>? onStep;
  final CoachLabels labels;
  final CoachStyle style;
  final bool reduceMotion;
  // Completes with how the tour ended; what CoachTour.show returns.
  final Completer<CoachResult> result = Completer<CoachResult>();

  // Completes [result] once; later calls are ignored. Without a value the
  // tour counts as dismissed.
  void finish([CoachResult? value]) {
    if (!result.isCompleted) result.complete(value ?? CoachResult.dismissed);
  }

  @override
  Color? get barrierColor => null; // the overlay paints its own shade

  @override
  bool get barrierDismissible => false; // taps are handled by the overlay

  @override
  String? get barrierLabel => labels.dismiss;

  @override
  Duration get transitionDuration => reduceMotion ? Duration.zero : style.duration;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) =>
      _CoachOverlay(route: this);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget child) =>
      FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child);
}

/// The page of the route: shade, cut-out, arrow and card.
class _CoachOverlay extends StatefulWidget {
  const _CoachOverlay({required this.route});

  final _CoachRoute route;

  @override
  State<_CoachOverlay> createState() => _CoachOverlayState();
}

/// Owns the tour position and animates the cut-out between steps.
/// WidgetsBindingObserver is used to re-measure when the window changes.
class _CoachOverlayState extends State<_CoachOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Drives the cut-out from its old rectangle to the new one.
  late final AnimationController _move = AnimationController(vsync: this, duration: _duration);
  // Index of the current step; -1 until the first step is ready.
  int _index = -1;
  // Cut-out rectangles (in this overlay's coordinates) the animation runs between.
  Rect? _from;
  Rect? _to;
  // True while moving to a step (scrolling, measuring), so taps cannot overlap.
  bool _busy = false;
  // Set once the tour is closing, so it is only closed once.
  bool _closing = false;

  List<CoachStep> get _steps => widget.route.steps;
  Duration get _duration => widget.route.reduceMotion ? Duration.zero : widget.route.style.duration;

  // The cut-out rectangle at the current point of the animation.
  Rect? get _hole {
    final from = _from, to = _to;
    if (from == null || to == null) return null;
    return Rect.lerp(from, to, Curves.easeInOut.transform(_move.value));
  }

  @override
  void initState() {
    super.initState();
    // Listen for rotation, resize and keyboard changes (see didChangeMetrics).
    WidgetsBinding.instance.addObserver(this);
    // Wait for the first frame so the targets have been measured, then start.
    WidgetsBinding.instance.addPostFrameCallback((_) => _goTo(0));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _move.dispose();
    // The route can be removed without a pop; make sure the future completes.
    widget.route.finish(); // removed without a pop (e.g. the app closed)
    super.dispose();
  }

  // Rotation, window resize, keyboard: re-measure once the page has laid out.
  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _index < 0) return;
      final rect = _measure(_steps[_index]);
      if (rect != null) setState(() => _from = _to = rect);
    });
  }

  /// Where the step's target is, in this overlay's coordinates, including the
  /// step's padding. Null when the target cannot be measured.
  Rect? _measure(CoachStep step) {
    final box = _boxOf(step);
    final me = context.findRenderObject();
    if (box == null || me is! RenderBox || !me.hasSize) return null;
    final topLeft = me.globalToLocal(box.localToGlobal(Offset.zero));
    return step.padding.inflateRect(topLeft & box.size);
  }

  /// Shows the first step at or after [start] that can be displayed. Steps whose
  /// widget disappeared are skipped; when none is left the tour completes.
  Future<void> _goTo(int start) async {
    // Ignore requests while a step change is already in progress.
    if (_busy) return;
    _busy = true;
    try {
      for (var i = start; i < _steps.length; i++) {
        final step = _steps[i];
        final target = step.target.currentContext;
        // Target not on screen any more: skip this step.
        if (target == null || _boxOf(step) == null) continue;
        // Inside a scrollable: scroll the target to the middle of the viewport first.
        if (Scrollable.maybeOf(target) != null) {
          await Scrollable.ensureVisible(target,
              alignment: 0.5, duration: _duration, curve: Curves.easeInOut);
          // Let the scroll settle so the measurement below is accurate.
          await WidgetsBinding.instance.endOfFrame;
        }
        // The tour may have been closed while scrolling.
        if (!mounted) return;
        final rect = _measure(step);
        if (rect == null) continue;
        setState(() {
          // Start the move from where the cut-out is now (or jump on the first step).
          _from = _hole ?? rect;
          _to = rect;
          _index = i;
        });
        // Animate the cut-out and tell the caller which step is showing.
        _move.forward(from: 0);
        widget.route.onStep?.call(i);
        return;
      }
      _close(CoachResult.completed);
    } finally {
      _busy = false;
    }
  }

  /// Moves on, or completes the tour after the last step.
  void _next() {
    if (_index >= _steps.length - 1) {
      _close(CoachResult.completed);
    } else {
      _goTo(_index + 1);
    }
  }

  /// Ends the tour with [result]. Safe to call more than once.
  void _close(CoachResult result) {
    if (_closing || !mounted) return;
    _closing = true;
    final route = widget.route;
    route.finish(result);
    // Normal case: pop. If another route is on top, remove ours quietly.
    if (route.isCurrent) {
      Navigator.of(context).pop(result);
    } else {
      route.navigator?.removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.route.style;
    final step = _index >= 0 ? _steps[_index] : null;
    return AnimatedBuilder(
      animation: _move,
      builder: (context, _) {
        final hole = _hole;
        // The card is shown only after the cut-out has stopped moving.
        final settled = step != null && hole != null && !_move.isAnimating;
        return Stack(children: [
          // Full-screen layer: paints the shade and receives the taps.
          Positioned.fill(
            child: Semantics(
              button: true,
              label: widget.route.labels.dismiss,
              onTap: () => _close(CoachResult.dismissed),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // A tap on the highlighted widget moves on; elsewhere closes.
                onTapUp: (d) => hole != null && hole.contains(d.localPosition)
                    ? _next()
                    : _close(CoachResult.dismissed),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _ShadePainter(
                    hole: hole,
                    shape: step?.shape ?? CoachShape.rectangle,
                    radius: step?.radius ?? 0,
                    style: style,
                  ),
                ),
              ),
            ),
          ),
          // Fade the card in again for every step (the key restarts the animation).
          if (settled)
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                key: ValueKey<int>(_index),
                tween: Tween(begin: 0, end: 1),
                duration: _duration,
                builder: (context, t, child) => Opacity(opacity: t, child: child),
                // Places the card and the arrow next to the cut-out (see _CardLayout).
                child: CustomMultiChildLayout(
                  delegate: _CardLayout(
                    target: hole,
                    safe: MediaQuery.maybeOf(context)?.padding ?? EdgeInsets.zero,
                    style: style,
                  ),
                  children: [
                    LayoutId(
                        id: _Slot.arrow,
                        child: _Arrow(color: _palette(context).surface)),
                    LayoutId(id: _Slot.card, child: _card(context, step)),
                  ],
                ),
              ),
            ),
        ]);
      },
    );
  }

  // Colours for the current style and the platform's light or dark mode.
  _Palette _palette(BuildContext context) => _Palette.resolve(
      widget.route.style, MediaQuery.maybeOf(context)?.platformBrightness);

  /// The explanation card: title, optional body, step counter and buttons.
  Widget _card(BuildContext context, CoachStep step) {
    final style = widget.route.style;
    final labels = widget.route.labels;
    final palette = _palette(context);
    final total = _steps.length;
    final last = _index >= total - 1;
    return Semantics(
      // Announce the card as its own screen section to screen readers.
      container: true,
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: step.title,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(style.cardRadius),
          boxShadow: style.cardShadow,
        ),
        // There is no Material ancestor to supply a text style, so set a base one;
        // otherwise text would use Flutter's fallback style.
        child: DefaultTextStyle(
          style: TextStyle(
            color: palette.text,
            fontSize: CoachDefaults.bodySize,
            fontWeight: FontWeight.normal,
            decoration: TextDecoration.none,
          ),
          // Scrolls when large text or a small window makes the card too tall.
          child: SingleChildScrollView(
            padding: style.cardPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: CoachDefaults.textEndPadding),
                  child: Text(step.title,
                      style: style.titleStyle ??
                          TextStyle(
                              color: palette.accent,
                              fontSize: CoachDefaults.titleSize,
                              fontWeight: FontWeight.w600)),
                ),
                if (step.body.isNotEmpty) ...[
                  const SizedBox(height: CoachDefaults.titleGap),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: CoachDefaults.textEndPadding),
                    child: Text(step.body, style: style.bodyStyle),
                  ),
                ],
                const SizedBox(height: CoachDefaults.actionsGap),
                // Bottom row: step counter on the left, buttons on the right.
                Row(children: [
                  Expanded(
                    child: total > 1
                        ? Text(labels.progress(_index + 1, total),
                            style: style.progressStyle ??
                                TextStyle(
                                    color: palette.muted,
                                    fontSize: CoachDefaults.progressSize))
                        : const SizedBox.shrink(),
                  ),
                  Flexible(
                    // Buttons get more room than the counter and wrap on narrow cards.
                    flex: 3,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: CoachDefaults.buttonSpacing,
                      runSpacing: CoachDefaults.buttonSpacing,
                      children: [
                        if (!last)
                          _CoachButton(
                            style: style,
                            label: labels.skip,
                            onPressed: () => _close(CoachResult.skipped),
                            foreground: palette.accent,
                            focusColor: palette.accent,
                          ),
                        _CoachButton(
                          style: style,
                          label: last ? labels.done : labels.next,
                          onPressed: _next,
                          foreground: palette.onAccent,
                          background: palette.accent,
                          focusColor: palette.text,
                          // Focus the main button so Enter or Space moves to the next step.
                          autofocus: true,
                        ),
                      ],
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Colours of the card, resolved from [CoachStyle] and the platform
/// brightness. The package does not depend on any design library, so it does
/// not read the app's theme; set the colours in [CoachStyle] to match it.
class _Palette {
  const _Palette({
    required this.surface,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
  });

  factory _Palette.resolve(CoachStyle style, Brightness? brightness) {
    final dark = brightness == Brightness.dark;
    final accent = style.accentColor ??
        (dark ? CoachDefaults.darkAccent : CoachDefaults.lightAccent);
    return _Palette(
      surface: style.cardColor ??
          (dark ? CoachDefaults.darkSurface : CoachDefaults.lightSurface),
      text: style.textColor ?? (dark ? CoachDefaults.darkText : CoachDefaults.lightText),
      muted: style.mutedColor ?? (dark ? CoachDefaults.darkMuted : CoachDefaults.lightMuted),
      accent: accent,
      onAccent: accent.computeLuminance() > 0.5
          ? CoachDefaults.onDarkAccent
          : CoachDefaults.onLightAccent,
    );
  }

  final Color surface;
  final Color text;
  final Color muted;
  final Color accent;
  final Color onAccent;
}

/// A small keyboard- and screen-reader-friendly button built on widgets only.
class _CoachButton extends StatefulWidget {
  const _CoachButton({
    required this.style,
    required this.label,
    required this.onPressed,
    required this.foreground,
    required this.focusColor,
    this.background,
    this.autofocus = false,
  });

  final CoachStyle style;
  final String label;
  final VoidCallback onPressed;
  final Color foreground;
  final Color focusColor;
  final Color? background;
  final bool autofocus;

  @override
  State<_CoachButton> createState() => _CoachButtonState();
}

class _CoachButtonState extends State<_CoachButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    // Screen-reader side of the button: label, role and tap action.
    return Semantics(
      button: true,
      focusable: true,
      excludeSemantics: true,
      label: widget.label,
      onTap: widget.onPressed,
      // Adds keyboard focus, Enter/Space activation and a pointer cursor.
      child: FocusableActionDetector(
        autofocus: widget.autofocus,
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        actions: <Type, Action<Intent>>{
          // Enter and Space reach the button as an ActivateIntent.
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onPressed();
            return null;
          }),
        },
        // Taps and clicks; opaque so the whole padded area is tappable.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(
                minWidth: widget.style.buttonMinSize.width,
                minHeight: widget.style.buttonMinSize.height),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.background,
                borderRadius: BorderRadius.circular(widget.style.buttonRadius),
                border: Border.all(
                  color: _focused ? widget.focusColor : CoachDefaults.transparent,
                  width: widget.style.focusRingWidth,
                ),
              ),
              child: Padding(
                padding: CoachDefaults.buttonPadding,
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    widget.label,
                    style: (widget.style.buttonStyle ??
                            const TextStyle(
                              fontSize: CoachDefaults.buttonSize,
                              fontWeight: FontWeight.w600,
                            ))
                        .copyWith(color: widget.foreground),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ids of the two children placed by [_CardLayout].
enum _Slot { arrow, card }

/// [value] limited to [low]..[high]; callers pass high >= low.
double _clamp(double value, double low, double high) =>
    value < low ? low : (value > high ? high : value);

/// Puts the card below the cut-out when there is room, otherwise above, and
/// keeps it inside the safe area. The arrow sits on the card edge facing the
/// cut-out and is hidden when the card had to overlap the target.
class _CardLayout extends MultiChildLayoutDelegate {
  _CardLayout({required this.target, required this.safe, required this.style});

  final Rect target;
  final EdgeInsets safe;
  final CoachStyle style;

  @override
  // Usable area: the screen minus the safe area (notches, bars) and margin.
  void performLayout(Size size) {
    final m = style.screenMargin;
    final area = EdgeInsets.fromLTRB(
            safe.left + m, safe.top + m, safe.right + m, safe.bottom + m)
        .deflateRect(Offset.zero & size);
    // Free space above and below the cut-out.
    final above = target.top - style.gap - area.top;
    final below = area.bottom - target.bottom - style.gap;
    // Prefer below; use above only when it has more room.
    final putBelow = below >= above;
    // Never smaller than a minimum so the card stays usable.
    final maxHeight = math.max(CoachDefaults.minCardHeight, putBelow ? below : above);
    final maxWidth = math.max(0.0, math.min(style.cardMaxWidth, area.width));

    // Lay the card out within the chosen space; its size is needed to position it.
    final card = layoutChild(
        _Slot.card, BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight));
    // Centre the card on the target horizontally, then keep it inside the area.
    final x = _clamp(target.center.dx - card.width / 2, area.left,
        math.max(area.left, area.right - card.width));
    // Ideal top edge: just below or just above the cut-out, one gap away.
    final wanted = putBelow ? target.bottom + style.gap : target.top - style.gap - card.height;
    // Clamp vertically so the card never leaves the screen.
    final y = _clamp(wanted, area.top, math.max(area.top, area.bottom - card.height));
    positionChild(_Slot.card, Offset(x, y));

    // The arrow is a small rotated square half-hidden behind the card edge.
    layoutChild(_Slot.arrow, BoxConstraints.tight(Size.square(style.arrowSize)));
    final r = style.cardRadius;
    // Keep the arrow within the card's straight edge, away from the rounded corners.
    final ax = _clamp(target.center.dx - style.arrowSize / 2, x + r,
        math.max(x + r, x + card.width - r - style.arrowSize));
    // The arrow is only shown when the card actually touches its ideal spot;
    // when the card had to move (and may overlap the target) it is parked offscreen.
    final adjacent = (y - wanted).abs() < 0.5;
    positionChild(
        _Slot.arrow,
        adjacent
            ? Offset(ax, putBelow ? y - style.arrowSize / 2 : y + card.height - style.arrowSize / 2)
            : CoachDefaults.offscreen);
  }

  @override
  // Lay out again only when something that affects the result changed.
  bool shouldRelayout(_CardLayout old) =>
      old.target != target || old.safe != safe || old.style != style;
}

/// Little pointer between the card and the highlighted widget.
class _Arrow extends StatelessWidget {
  const _Arrow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: math.pi / 4,
        child: DecoratedBox(
          decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(CoachDefaults.arrowRadius)),
        ),
      );
}

/// Paints the dimmed screen with a hole around the target, plus an outline.
class _ShadePainter extends CustomPainter {
  const _ShadePainter({
    required this.hole,
    required this.shape,
    required this.radius,
    required this.style,
  });

  final Rect? hole;
  final CoachShape shape;
  final double radius;
  final CoachStyle style;

  // The cut-out as a path: a circle or a rounded rectangle; null before the
  // first step is measured.
  Path? _holePath() {
    final h = hole;
    if (h == null) return null;
    return switch (shape) {
      CoachShape.circle =>
        Path()..addOval(Rect.fromCircle(center: h.center, radius: h.longestSide / 2)),
      CoachShape.rectangle =>
        Path()..addRRect(RRect.fromRectAndRadius(h, Radius.circular(radius))),
    };
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cut = _holePath();
    // Even-odd fill: the full-screen rectangle minus the cut-out leaves a hole.
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    if (cut != null) shade.addPath(cut, Offset.zero);
    // Paint the shade, then the outline around the cut-out.
    canvas.drawPath(shade, Paint()..color = style.shadeColor);
    if (cut != null && style.ringWidth > 0) {
      canvas.drawPath(
          cut,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = style.ringWidth
            ..color = style.ringColor);
    }
  }

  @override
  // Repaint only when something that affects the drawing changed.
  bool shouldRepaint(_ShadePainter old) =>
      old.hole != hole || old.shape != shape || old.radius != radius || old.style != style;
}
