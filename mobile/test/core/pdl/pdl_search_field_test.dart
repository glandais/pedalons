import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pdl/pdl.dart';

/// A12 — le champ de recherche et son anti-rebond.
///
/// Le défaut tenu ici est un aller-retour dans le temps : on tape, la liste se
/// vide, on touche « Tout réinitialiser » — et la recherche revient toute
/// seule un tiers de seconde plus tard, parce que le minuteur de la dernière
/// frappe était encore en vol quand la remise à zéro est passée.
void main() {
  /// Un hôte qui **possède** la valeur, comme un écran réel : le champ la
  /// reçoit, la rend, et c'est l'hôte qui décide de la remettre à zéro.
  Widget host({
    required ValueChanged<String?> onChanged,
    required void Function(void Function(String?) setValue) expose,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: _Host(onChanged: onChanged, expose: expose),
      ),
    );
  }

  testWidgets('une remise à zéro extérieure annule la frappe en attente', (
    WidgetTester tester,
  ) async {
    final List<String?> emitted = <String?>[];
    late void Function(String?) setValue;

    await tester.pumpWidget(
      host(
        onChanged: emitted.add,
        expose: (void Function(String?) setter) => setValue = setter,
      ),
    );

    // 1 · une première recherche part, et ne rend rien — c'est elle qui fait
    //     apparaître l'état vide et son « Tout réinitialiser ».
    await tester.enterText(find.byType(TextField), 'introuvable');
    await tester.pump(const Duration(seconds: 1));
    expect(emitted, <String?>['introuvable']);

    // 2 · une dernière lettre, encore dans la fenêtre d'anti-rebond.
    await tester.enterText(find.byType(TextField), 'introuvables');
    await tester.pump(const Duration(milliseconds: 100));

    // 3 · « Tout réinitialiser » : l'hôte repasse la valeur à null.
    setValue(null);
    await tester.pump();

    // Bien après la fin de l'anti-rebond, la frappe abandonnée ne remonte pas.
    await tester.pump(const Duration(seconds: 1));
    expect(emitted, <String?>['introuvable']);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
  });

  testWidgets('une frappe non interrompue part bien, elle', (
    WidgetTester tester,
  ) async {
    final List<String?> emitted = <String?>[];

    await tester.pumpWidget(host(onChanged: emitted.add, expose: (_) {}));

    await tester.enterText(find.byType(TextField), 'col du béal');
    await tester.pump(const Duration(seconds: 1));

    expect(emitted, <String?>['col du béal']);
  });

  testWidgets('le clavier ne corrige ni ne suggère', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(onChanged: (_) {}, expose: (_) {}));

    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
  });
}

class _Host extends StatefulWidget {
  const _Host({required this.onChanged, required this.expose});

  final ValueChanged<String?> onChanged;
  final void Function(void Function(String?) setValue) expose;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String? _value;

  @override
  void initState() {
    super.initState();
    widget.expose((String? next) => setState(() => _value = next));
  }

  @override
  Widget build(BuildContext context) {
    return PdlSearchField(
      value: _value,
      hintText: 'Rechercher',
      onChanged: (String? next) {
        setState(() => _value = next);
        widget.onChanged(next);
      },
    );
  }
}
