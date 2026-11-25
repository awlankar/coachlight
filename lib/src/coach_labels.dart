// coachlight - spotlight coach marks for Flutter.
// Author: Nitin Awlankar
// Licensed under the MIT License; see the LICENSE file.
//
// Texts shown by the tour, kept separate so apps can translate them.

import 'package:flutter/foundation.dart';

/// Texts used by the tour, so apps can translate them.
@immutable
class CoachLabels {
  /// English defaults; pass your own for other languages.
  const CoachLabels({
    this.next = 'Next',
    this.skip = 'Skip',
    this.done = 'Got it',
    this.dismiss = 'Close tips',
    this.progress = defaultProgress,
  });

  /// Moves to the next step.
  final String next;

  /// Ends the tour early ([CoachResult.skipped]).
  final String skip;

  /// Closes the last step ([CoachResult.completed]).
  final String done;

  /// Screen-reader label of the dimmed area; tapping it closes the tour.
  final String dismiss;

  /// "1 of 3"; receives the 1-based step number and the step count.
  final String Function(int step, int total) progress;

  /// The default [progress] text.
  static String defaultProgress(int step, int total) => '$step of $total';
}
