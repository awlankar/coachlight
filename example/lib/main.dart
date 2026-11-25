// coachlight - spotlight coach marks for Flutter.
// Author: Nitin Awlankar
// Licensed under the MIT License; see the LICENSE file.
//
// Example app that shows every feature of the package:
//  * rectangle and circle cut-outs
//  * a target far down a scroll view (the tour scrolls to it)
//  * a step whose widget does not exist (it is skipped)
//  * Next / Skip / Done, the "1 of 3" counter and tapping the target
//  * translated labels (CoachLabels)
//  * three looks (CoachStyle): defaults, matching the app theme, custom
//  * right-to-left layout and light / dark app themes
//  * showOnce with a memory, replaying, and the onStep / result callbacks

import 'package:coachlight/coachlight.dart';
import 'package:material_ui/material_ui.dart';

/// Starts the example app.
void main() => runApp(const ExampleApp());

/// Which [CoachStyle] the tour uses.
enum StylePreset {
  /// The built-in look: light or dark by platform brightness.
  standard,

  /// Colours taken from the app's own [ThemeData].
  matchTheme,

  /// Every option set by hand.
  custom,
}

/// Owns the settings that must live above the Navigator: theme and direction.
/// The tour is shown in a route, so it picks these up only from here.
class ExampleApp extends StatefulWidget {
  /// Creates the example app.
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  bool _dark = false;
  bool _rtl = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'coachlight example',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.indigo),
        darkTheme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            brightness: Brightness.dark),
        themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
        // Wrapping the Navigator means the tour card is mirrored too.
        builder: (context, child) => Directionality(
          textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        ),
        home: ExamplePage(
          dark: _dark,
          rtl: _rtl,
          onDark: (value) => setState(() => _dark = value),
          onRtl: (value) => setState(() => _rtl = value),
        ),
      );
}

/// The demo screen: an options card, a few controls and a long list.
class ExamplePage extends StatefulWidget {
  /// Creates the demo page.
  const ExamplePage({
    super.key,
    required this.dark,
    required this.rtl,
    required this.onDark,
    required this.onRtl,
  });

  /// Whether the dark app theme is on.
  final bool dark;

  /// Whether the layout is right-to-left.
  final bool rtl;

  /// Called when the dark theme switch changes.
  final ValueChanged<bool> onDark;

  /// Called when the right-to-left switch changes.
  final ValueChanged<bool> onRtl;

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  // One GlobalKey per widget the tour points at.
  final _search = GlobalKey();
  final _options = GlobalKey();
  final _star = GlobalKey();
  final _add = GlobalKey();

  // Never attached to any widget, so the step that uses it is skipped.
  final _missing = GlobalKey();

  // Remembers which tours were seen. In-memory only: forgotten on restart.
  // Use your own storage (CoachMemory) to remember across launches.
  final _memory = InMemoryCoachMemory();

  StylePreset _preset = StylePreset.standard;
  bool _spanish = false;
  String _status = 'No tour shown yet.';

  @override
  void initState() {
    super.initState();
    // Wait for the first frame so the targets are laid out, then show the
    // tour once. Press "Forget seen tours" to see it again.
    WidgetsBinding.instance.addPostFrameCallback((_) => _run(once: true));
  }

  // --- tour configuration -------------------------------------------------

  List<CoachStep> _steps() => [
        CoachStep(
          target: _search,
          title: _spanish ? 'Buscar' : 'Find things',
          body: _spanish ? 'Escribe para filtrar.' : 'Type here to filter the list.',
        ),
        CoachStep(
          target: _options,
          title: _spanish ? 'Opciones' : 'Try the options',
          body: _spanish
              ? 'Cambia idioma, tema, dirección y estilo.'
              : 'Change language, theme, direction and style, then replay.',
          // Roomier cut-out and softer corners than the default.
          padding: const EdgeInsets.all(10),
          radius: 20,
        ),
        CoachStep(
          target: _star,
          title: _spanish ? 'Favorito' : 'Scrolled into view',
          body: _spanish
              ? 'Este elemento estaba fuera de la pantalla.'
              : 'This item was off screen; the tour scrolled to it.',
          // A circle suits a small icon.
          shape: CoachShape.circle,
        ),
        // Its widget does not exist, so this step is skipped silently.
        CoachStep(target: _missing, title: 'Never shown'),
        CoachStep(
          target: _add,
          title: _spanish ? 'Añadir' : 'Last step',
          body: _spanish
              ? 'Toca "Entendido" o el botón para terminar.'
              : 'Tap Got it, or tap the highlighted button, to finish.',
          shape: CoachShape.circle,
        ),
      ];

  CoachLabels _labels() => _spanish
      ? CoachLabels(
          next: 'Siguiente',
          skip: 'Omitir',
          done: 'Entendido',
          dismiss: 'Cerrar consejos',
          progress: (step, total) => '$step de $total',
        )
      : const CoachLabels();

  CoachStyle _style() {
    switch (_preset) {
      case StylePreset.standard:
        return const CoachStyle();
      case StylePreset.matchTheme:
        // The card does not read ThemeData by itself; map it explicitly.
        final scheme = Theme.of(context).colorScheme;
        return CoachStyle(
          cardColor: scheme.surface,
          accentColor: scheme.primary,
          textColor: scheme.onSurface,
          mutedColor: scheme.onSurfaceVariant,
        );
      case StylePreset.custom:
        return const CoachStyle(
          shadeColor: Color(0xCC1A0033),
          ringColor: Colors.amber,
          ringWidth: 4,
          cardColor: Color(0xFFFFF8E1),
          accentColor: Color(0xFFE65100),
          textColor: Color(0xFF3E2723),
          mutedColor: Color(0xFF8D6E63),
          cardRadius: 28,
          cardMaxWidth: 360,
          cardPadding: EdgeInsets.all(22),
          gap: 20,
          buttonRadius: 12,
          arrowSize: 18,
          duration: Duration(milliseconds: 500),
          titleStyle: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFFE65100)),
        );
    }
  }

  // --- running the tour ---------------------------------------------------

  /// Shows the tour. With [once] it uses showOnce, which does nothing when the
  /// tour was already seen.
  Future<void> _run({required bool once}) async {
    final steps = _steps();
    final labels = _labels();
    final style = _style();
    // Called whenever a step appears; the index is into [steps].
    void onStep(int index) {
      if (mounted) setState(() => _status = 'Showing step ${index + 1} of ${steps.length}');
    }

    final CoachResult? result;
    if (once) {
      result = await CoachTour.showOnce(context,
          id: 'home',
          memory: _memory,
          steps: steps,
          labels: labels,
          style: style,
          onStep: onStep);
    } else {
      result = await CoachTour.show(context,
          steps: steps, labels: labels, style: style, onStep: onStep);
    }
    if (!mounted) return;
    setState(() => _status = result == null
        ? 'Already seen, so showOnce showed nothing.'
        : 'Tour ended: ${result.name}');
  }

  // --- screen -------------------------------------------------------------

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('coachlight'),
          actions: [
            IconButton(
              tooltip: 'Replay tour',
              icon: const Icon(Icons.replay),
              onPressed: () => _run(once: false),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          key: _add,
          tooltip: 'Add',
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
        // A plain scroll view builds every child, so the star below exists
        // even while it is off screen. A lazy ListView would not build it and
        // the tour would skip that step.
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: _spanish ? 'Buscar' : 'Search',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              _optionsCard(),
              const SizedBox(height: 12),
              Text(_status, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton(
                    onPressed: () => _run(once: false), child: const Text('Show tour')),
                OutlinedButton(
                    onPressed: () => _run(once: true),
                    child: const Text('Show once')),
                TextButton(
                  onPressed: () {
                    _memory.clear();
                    setState(() => _status = 'Forgotten: "Show once" works again.');
                  },
                  child: const Text('Forget seen tours'),
                ),
              ]),
              const Divider(height: 32),
              Text('A long list: the tour scrolls to the star.',
                  style: Theme.of(context).textTheme.titleSmall),
              for (var i = 1; i <= 25; i++)
                ListTile(
                  title: Text('Item $i'),
                  // The 23rd item carries the star the tour points at.
                  trailing: i == 23
                      ? Icon(Icons.star, key: _star, color: Colors.amber)
                      : null,
                ),
              // Space so the last item is not hidden by the floating button.
              const SizedBox(height: 72),
            ],
          ),
        ),
      );

  Widget _optionsCard() => Card(
        key: _options,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Options', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final preset in StylePreset.values)
                ChoiceChip(
                  label: Text(switch (preset) {
                    StylePreset.standard => 'Default style',
                    StylePreset.matchTheme => 'Match app theme',
                    StylePreset.custom => 'Custom style',
                  }),
                  selected: _preset == preset,
                  onSelected: (_) => setState(() => _preset = preset),
                ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Spanish labels'),
              value: _spanish,
              onChanged: (value) => setState(() => _spanish = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dark app theme'),
              value: widget.dark,
              onChanged: widget.onDark,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Right-to-left'),
              value: widget.rtl,
              onChanged: widget.onRtl,
            ),
          ]),
        ),
      );
}
