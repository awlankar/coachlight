import 'package:coachlight/coachlight.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: ExamplePage()));

/// Minimal example: highlights the search field, then the add button.
class ExamplePage extends StatefulWidget {
  /// Creates the example page.
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  final _search = GlobalKey();
  final _add = GlobalKey();
  final _memory = InMemoryCoachMemory();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tour());
  }

  Future<void> _tour() => CoachTour.showOnce(context, id: 'home', memory: _memory, steps: [
        CoachStep(target: _search, title: 'Search', body: 'Find anything by name.'),
        CoachStep(
            target: _add,
            title: 'Add',
            body: 'Create a new item.',
            shape: CoachShape.circle),
      ]);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('coachlight')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
              key: _search,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search), hintText: 'Search')),
        ),
        floatingActionButton: FloatingActionButton(
            key: _add, onPressed: () {}, child: const Icon(Icons.add)),
      );
}
