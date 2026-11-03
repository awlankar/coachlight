import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

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
    final shown = <int>[
      for (var i = 0; i < steps.length; i++)
        if (_boxOf(steps[i]) != null) i,
    ];
    if (shown.isEmpty) return CoachResult.completed;
    final route = _CoachRoute(
      steps: [for (final i in shown) steps[i]],
      onStep: onStep == null ? null : (i) => onStep(shown[i]),
      labels: labels,
      style: style,
      reduceMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
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
    if (await memory.isSeen(id)) return null;
    if (!context.mounted || !anyVisible(steps)) return null;
    final result =
        await show(context, steps: steps, labels: labels, style: style, onStep: onStep);
    await memory.markSeen(id);
    return result;
  }
}

RenderBox? _boxOf(CoachStep step) {
  final object = step.target.currentContext?.findRenderObject();
  if (object is! RenderBox || !object.attached || !object.hasSize) return null;
  return object;
}

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
  final Completer<CoachResult> result = Completer<CoachResult>();

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

class _CoachOverlay extends StatefulWidget {
  const _CoachOverlay({required this.route});

  final _CoachRoute route;

  @override
  State<_CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<_CoachOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _move = AnimationController(vsync: this, duration: _duration);
  int _index = -1;
  Rect? _from;
  Rect? _to;
  bool _busy = false;
  bool _closing = false;

  List<CoachStep> get _steps => widget.route.steps;
  Duration get _duration => widget.route.reduceMotion ? Duration.zero : widget.route.style.duration;

  Rect? get _hole {
    final from = _from, to = _to;
    if (from == null || to == null) return null;
    return Rect.lerp(from, to, Curves.easeInOut.transform(_move.value));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _goTo(0));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _move.dispose();
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

  Rect? _measure(CoachStep step) {
    final box = _boxOf(step);
    final me = context.findRenderObject();
    if (box == null || me is! RenderBox || !me.hasSize) return null;
    final topLeft = me.globalToLocal(box.localToGlobal(Offset.zero));
    return step.padding.inflateRect(topLeft & box.size);
  }

  Future<void> _goTo(int start) async {
    if (_busy) return;
    _busy = true;
    try {
      for (var i = start; i < _steps.length; i++) {
        final step = _steps[i];
        final target = step.target.currentContext;
        if (target == null || _boxOf(step) == null) continue;
        if (Scrollable.maybeOf(target) != null) {
          await Scrollable.ensureVisible(target,
              alignment: 0.5, duration: _duration, curve: Curves.easeInOut);
          await WidgetsBinding.instance.endOfFrame;
        }
        if (!mounted) return;
        final rect = _measure(step);
        if (rect == null) continue;
        setState(() {
          _from = _hole ?? rect;
          _to = rect;
          _index = i;
        });
        _move.forward(from: 0);
        widget.route.onStep?.call(i);
        return;
      }
      _close(CoachResult.completed);
    } finally {
      _busy = false;
    }
  }

  void _next() {
    if (_index >= _steps.length - 1) {
      _close(CoachResult.completed);
    } else {
      _goTo(_index + 1);
    }
  }

  void _close(CoachResult result) {
    if (_closing || !mounted) return;
    _closing = true;
    final route = widget.route;
    route.finish(result);
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
        final settled = step != null && hole != null && !_move.isAnimating;
        return Stack(children: [
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
          if (settled)
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                key: ValueKey<int>(_index),
                tween: Tween(begin: 0, end: 1),
                duration: _duration,
                builder: (context, t, child) => Opacity(opacity: t, child: child),
                child: CustomMultiChildLayout(
                  delegate: _CardLayout(
                    target: hole,
                    safe: MediaQuery.paddingOf(context),
                    style: style,
                  ),
                  children: [
                    LayoutId(id: _Slot.arrow, child: _Arrow(color: _cardColor(context))),
                    LayoutId(id: _Slot.card, child: _card(context, step)),
                  ],
                ),
              ),
            ),
        ]);
      },
    );
  }

  Color _cardColor(BuildContext context) =>
      widget.route.style.cardColor ?? Theme.of(context).colorScheme.surface;

  Widget _card(BuildContext context, CoachStep step) {
    final theme = Theme.of(context);
    final style = widget.route.style;
    final labels = widget.route.labels;
    final total = _steps.length;
    final last = _index >= total - 1;
    return Semantics(
      container: true,
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: step.title,
      child: Material(
        color: _cardColor(context),
        elevation: 8,
        borderRadius: BorderRadius.circular(style.cardRadius),
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: Text(step.title,
                    style: style.titleStyle ??
                        theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
              ),
              if (step.body.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: Text(step.body, style: style.bodyStyle ?? theme.textTheme.bodyMedium),
                ),
              ],
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: total > 1
                      ? Text(labels.progress(_index + 1, total),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant))
                      : const SizedBox.shrink(),
                ),
                Flexible(
                  flex: 3,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (!last)
                        TextButton(
                            onPressed: () => _close(CoachResult.skipped),
                            child: Text(labels.skip)),
                      FilledButton(
                          autofocus: true,
                          onPressed: _next,
                          child: Text(last ? labels.done : labels.next)),
                    ],
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

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

  static const double _arrow = 14;

  @override
  void performLayout(Size size) {
    final m = style.screenMargin;
    final area = EdgeInsets.fromLTRB(
            safe.left + m, safe.top + m, safe.right + m, safe.bottom + m)
        .deflateRect(Offset.zero & size);
    final above = target.top - style.gap - area.top;
    final below = area.bottom - target.bottom - style.gap;
    final putBelow = below >= above;
    final maxHeight = math.max(96.0, putBelow ? below : above);
    final maxWidth = math.max(0.0, math.min(style.cardMaxWidth, area.width));

    final card = layoutChild(
        _Slot.card, BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight));
    final x = _clamp(target.center.dx - card.width / 2, area.left,
        math.max(area.left, area.right - card.width));
    final wanted = putBelow ? target.bottom + style.gap : target.top - style.gap - card.height;
    final y = _clamp(wanted, area.top, math.max(area.top, area.bottom - card.height));
    positionChild(_Slot.card, Offset(x, y));

    layoutChild(_Slot.arrow, BoxConstraints.tight(const Size(_arrow, _arrow)));
    final r = style.cardRadius;
    final ax = _clamp(target.center.dx - _arrow / 2, x + r,
        math.max(x + r, x + card.width - r - _arrow));
    final adjacent = (y - wanted).abs() < 0.5;
    positionChild(
        _Slot.arrow,
        adjacent
            ? Offset(ax, putBelow ? y - _arrow / 2 : y + card.height - _arrow / 2)
            : const Offset(-1000, -1000));
  }

  @override
  bool shouldRelayout(_CardLayout old) =>
      old.target != target || old.safe != safe || old.style != style;
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: math.pi / 4,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
      );
}

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
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    if (cut != null) shade.addPath(cut, Offset.zero);
    canvas.drawPath(shade, Paint()..color = style.shadeColor);
    if (cut != null && style.ringWidth > 0 && style.ringColor.a > 0) {
      canvas.drawPath(
          cut,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = style.ringWidth
            ..color = style.ringColor);
    }
  }

  @override
  bool shouldRepaint(_ShadePainter old) =>
      old.hole != hole || old.shape != shape || old.radius != radius || old.style != style;
}
