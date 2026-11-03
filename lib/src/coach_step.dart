import 'package:flutter/widgets.dart';

/// Shape of the cut-out around a highlighted widget.
enum CoachShape {
  /// A rounded rectangle; see [CoachStep.radius].
  rectangle,

  /// A circle around the widget's centre.
  circle,
}

/// One highlighted widget and the text that explains it.
@immutable
class CoachStep {
  /// Creates a step pointing at the widget that carries [target].
  const CoachStep({
    required this.target,
    required this.title,
    this.body = '',
    this.shape = CoachShape.rectangle,
    this.padding = const EdgeInsets.all(6),
    this.radius = 12,
  });

  /// Key attached to the widget to highlight. A step whose widget is not
  /// laid out when its turn comes is skipped.
  final GlobalKey target;

  /// Short heading shown in the card.
  final String title;

  /// Optional one-line explanation under the title.
  final String body;

  /// Shape of the cut-out.
  final CoachShape shape;

  /// Space between the widget and the edge of the cut-out.
  final EdgeInsets padding;

  /// Corner radius used with [CoachShape.rectangle].
  final double radius;
}
