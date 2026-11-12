import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';
import 'pdl_sheet.dart';

/// C6 — La feuille plein rideau.
///
/// Elle sert quand le contenu est long et qu'il est l'écran : la liste des
/// participants, les 40 parcours d'une équipe. Elle laisse 128 px de contexte
/// en haut — l'écran d'où l'on vient reste visible, donc le retour reste
/// évident — et ne va jamais jusqu'en haut : `maxChildSize: .94`.
///
/// Sur la planche de 874 px, ces 128 px valent exactement `1 − .85` : les deux
/// écritures disent la même chose, la fraction est retenue parce qu'elle tient
/// sur tous les appareils.
///
/// **Elle recouvre la barre d'onglets** : [show] passe par [PdlSheet.show],
/// donc par le navigateur racine.
class PdlFullSheet extends StatelessWidget {
  const PdlFullSheet({
    super.key,
    required this.bodyBuilder,
    this.title,
    this.header,
    this.headerAction,
    this.footer,
    this.initialChildSize = 0.85,
    this.minChildSize = 0.5,
    this.maxChildSize = 0.94,
  });

  /// Le corps reçoit le [ScrollController] de la feuille : c'est lui qui
  /// transforme le défilement du contenu en glissement de la feuille. Le
  /// brancher n'est pas facultatif.
  final Widget Function(BuildContext context, ScrollController controller)
  bodyBuilder;

  final String? title;
  final Widget? header;
  final Widget? headerAction;
  final Widget? footer;

  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) => PdlSheet.show<T>(context: context, builder: builder);

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    Widget? headerChild = header;
    if (headerChild == null && title != null) {
      headerChild = Text(title!, style: t.sectionTitle);
    }

    return DraggableScrollableSheet(
      // `expand: false` : la feuille est déjà dans une route qui occupe
      // l'écran, se laisser étirer par elle la ferait couvrir les 128 px.
      expand: false,
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      builder: (BuildContext context, ScrollController controller) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: PdlRadii.sheetTop,
            border: Border(top: BorderSide(color: c.borderSubtle)),
            boxShadow: PdlShadows.sheet,
          ),
          child: ClipRRect(
            borderRadius: PdlRadii.sheetTop,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const PdlSheetHandle(),
                if (headerChild != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      PdlSpacing.section,
                      PdlSpacing.sectionTightV,
                      PdlSpacing.section,
                      PdlSpacing.sectionTightV,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(child: headerChild),
                        ?headerAction,
                      ],
                    ),
                  ),
                Expanded(child: bodyBuilder(context, controller)),
                ?footer,
              ],
            ),
          ),
        );
      },
    );
  }
}
