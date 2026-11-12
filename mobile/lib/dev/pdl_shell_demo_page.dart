// Écran de démonstration de la vague C — page de DEBUG, comme la galerie.
//
// Il n'est pas routé : il sert à *voir* et à *tester* l'empilement complet
// d'une coquille — barre supérieure, barre d'outils épinglée, liste longue,
// barre d'action, barre d'onglets — sur un seul écran. C'est cet empilement
// que `test/core/pdl/wave_c_test.dart` pompe pour vérifier les trois
// propriétés qui ne se voient pas dans une galerie statique :
//
//  1. la barre d'outils reste visible au défilement ;
//  2. une feuille ouverte depuis la page recouvre la barre d'onglets ;
//  3. rien ne déborde à 130 % d'agrandissement typographique.

import '../core/material.dart';

import '../core/pdl/pdl.dart';
import '../core/theme/pdl_colors.dart';
import '../core/theme/pdl_icons.dart';
import '../core/theme/pdl_tokens.dart';
import '../core/theme/pdl_typography.dart';

/// Les cinq entrées racine, en dur : la démo n'a ni routeur ni traductions.
const List<PdlTabItem> kDemoTabs = <PdlTabItem>[
  PdlTabItem(
    icon: PdlIcons.home,
    activeIcon: PdlIcons.homeActive,
    label: 'Accueil',
  ),
  PdlTabItem(
    icon: PdlIcons.teams,
    activeIcon: PdlIcons.teamsActive,
    label: 'Équipes',
  ),
  PdlTabItem(
    icon: PdlIcons.calendar,
    activeIcon: PdlIcons.calendarActive,
    label: 'Calendrier',
  ),
  PdlTabItem(
    icon: PdlIcons.routes,
    activeIcon: PdlIcons.routesActive,
    label: 'Parcours',
  ),
  PdlTabItem(
    icon: PdlIcons.profile,
    activeIcon: PdlIcons.profileActive,
    label: 'Profil',
  ),
];

/// Coquille complète : C1 + C3 + liste longue + C4 + C2.
class PdlShellDemoPage extends StatefulWidget {
  const PdlShellDemoPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<PdlShellDemoPage> createState() => _PdlShellDemoPageState();
}

class _PdlShellDemoPageState extends State<PdlShellDemoPage> {
  int _tab = 1;
  String _filter = 'Toutes';

  static const List<String> _filters = <String>[
    'Toutes',
    'Route',
    'Gravel',
    'VTT',
    'Mixte',
  ];

  Future<void> _openSortSheet() async {
    final String? picked = await PdlSheet.show<String>(
      context: context,
      builder: (BuildContext sheetContext) => PdlSheet(
        title: 'Trier par',
        headerAction: PdlAppBarAction(
          icon: PdlIcons.close,
          semanticLabel: 'Fermer',
          onPressed: () => Navigator.of(sheetContext).pop(),
        ),
        footer: Padding(
          padding: const EdgeInsets.all(PdlSpacing.section),
          child: PdlButton(
            label: 'Appliquer',
            fullWidth: true,
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ),
        children: <Widget>[
          for (final String option in <String>[
            'Date',
            'Distance',
            'Dénivelé',
            'Nom',
          ])
            PdlSettingRow(
              title: option,
              onTap: () => Navigator.of(sheetContext).pop(option),
            ),
        ],
      ),
    );
    if (picked != null && mounted) setState(() => _filter = picked);
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    return PdlScreenScaffold(
      appBar: PdlAppBar(
        title: 'Le Peloton',
        onBack: widget.onBack,
        backSemanticLabel: 'Retour à la galerie',
        actions: <Widget>[
          PdlAppBarAction(
            icon: PdlIcons.share,
            semanticLabel: 'Partager',
            onPressed: () {},
          ),
        ],
      ),
      toolbar: PdlChipRow(
        children: <Widget>[
          for (final String f in _filters)
            PdlChip(
              label: f,
              selected: f == _filter,
              onTap: () => setState(() => _filter = f),
            ),
        ],
      ),
      slivers: <Widget>[
        SliverList.builder(
          itemCount: 40,
          itemBuilder: (BuildContext context, int index) => Padding(
            padding: const EdgeInsets.fromLTRB(
              PdlSpacing.section,
              0,
              PdlSpacing.section,
              PdlSpacing.feedGap,
            ),
            child: PdlCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Sortie du dimanche ${index + 1}', style: t.cardTitle),
                  const SizedBox(height: 4),
                  Text(
                    'Boucle de $_filter — départ 08:30',
                    style: t.sub.copyWith(color: c.textDimmed),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      actionBar: PdlActionBar(
        children: <Widget>[
          PdlButton(
            label: 'Trier',
            variant: PdlButtonVariant.outline,
            icon: PdlIcons.sort,
            onPressed: _openSortSheet,
          ),
          PdlButton(label: 'Participer', onPressed: () {}),
        ],
      ),
      bottomTabs: PdlBottomTabs(
        items: kDemoTabs,
        selectedIndex: _tab,
        onSelected: (int i) => setState(() => _tab = i),
      ),
    );
  }
}
