/// Remembers which tours were already seen. Back it with your own storage
/// (database, preferences, a file); the package stores nothing itself.
abstract interface class CoachMemory {
  /// Whether the tour [tourId] was shown before.
  Future<bool> isSeen(String tourId);

  /// Records that the tour [tourId] was shown.
  Future<void> markSeen(String tourId);
}

/// Keeps seen tours in memory only; everything is forgotten on restart.
/// Useful in tests and demos.
class InMemoryCoachMemory implements CoachMemory {
  final Set<String> _seen = <String>{};

  @override
  Future<bool> isSeen(String tourId) async => _seen.contains(tourId);

  @override
  Future<void> markSeen(String tourId) async => _seen.add(tourId);

  /// Forgets every tour so they show again.
  void clear() => _seen.clear();
}
