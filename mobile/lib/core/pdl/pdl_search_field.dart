import 'dart:async';

import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';

/// Débounce appliqué avant d'émettre une nouvelle recherche.
///
/// La recherche est le seul contrôle qui s'applique à la frappe ; sans ce
/// délai, une frappe rapide déclencherait dix requêtes au lieu d'une.
const Duration kSearchDebounce = Duration(milliseconds: 350);

/// A12 — Champ de recherche et de saisie courte.
///
/// 44 px de haut, rayon 8, fond `surfaceAlt`, bordure `border` — la
/// transcription de `.search`. Il remplace l'ancien `RouteSearchBar` de
/// `features/routes`, dont il ne garde que le champ : le bouton de filtres est
/// devenu [PdlFilterButton], et l'assemblage des deux appartient à l'écran.
///
/// Les libellés sont des **paramètres** : `core/pdl` ne traduit rien, c'est
/// l'appelant qui possède ses clés de localisation.
class PdlSearchField extends StatefulWidget {
  const PdlSearchField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.hintText,
    this.debounce = kSearchDebounce,
    this.readOnly = false,
    this.errorText,
    this.onTap,
    this.autofocus = false,
    this.clearTooltip,
    this.textInputAction = TextInputAction.search,
    this.prefixIcon = PdlIcons.search,
    this.onSubmitted,
  });

  /// Valeur courante. Peut changer **de l'extérieur** — retrait d'une chip,
  /// réinitialisation des filtres —, auquel cas le champ se recale.
  final String? value;

  /// Appelé après [debounce], avec `null` quand la saisie est vide.
  final ValueChanged<String?> onChanged;

  final String hintText;
  final Duration debounce;

  /// Champ non saisissable qui se contente d'ouvrir autre chose ([onTap]).
  final bool readOnly;

  /// Message d'erreur rendu sous le champ ; la bordure passe en `danger`.
  final String? errorText;

  final VoidCallback? onTap;
  final bool autofocus;

  /// Info-bulle et libellé d'accessibilité du bouton d'effacement.
  final String? clearTooltip;

  final TextInputAction textInputAction;

  /// Icône de tête. `null` en retire une : une **saisie courte** — le nom
  /// affiché du profil — n'est pas une recherche, et la loupe le prétendrait.
  final IconData? prefixIcon;

  /// Validation depuis le clavier. Le débounce en cours est vidé d'abord, pour
  /// que l'appelant reçoive la dernière frappe avant d'agir.
  final ValueChanged<String?>? onSubmitted;

  @override
  State<PdlSearchField> createState() => _PdlSearchFieldState();
}

class _PdlSearchFieldState extends State<PdlSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value ?? '',
  );
  Timer? _debounce;

  @override
  void didUpdateWidget(PdlSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String incoming = widget.value ?? '';
    if (incoming != (oldWidget.value ?? '')) {
      // **Une remise à zéro venue de l'extérieur annule la frappe en attente.**
      // « Tout réinitialiser » dans une liste vide se tape à la seconde qui
      // suit la dernière lettre : sans cette ligne, le minuteur encore en vol
      // rendait la recherche qu'on vient d'effacer, un tiers de seconde plus
      // tard, sans que rien n'ait été touché.
      _debounce?.cancel();
      if (incoming != _controller.text) _controller.text = incoming;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    // Rebuild pour que le bouton d'effacement apparaisse avec le texte.
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(widget.debounce, () {
      final String trimmed = value.trim();
      widget.onChanged(trimmed.isEmpty ? null : trimmed);
    });
  }

  void _onSubmitted(String value) {
    final String trimmed = value.trim();
    final String? emitted = trimmed.isEmpty ? null : trimmed;
    _debounce?.cancel();
    widget.onChanged(emitted);
    widget.onSubmitted?.call(emitted);
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {});
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final bool hasError = widget.errorText != null;

    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: PdlRadii.mdAll,
      borderSide: BorderSide(color: hasError ? c.danger : c.border),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: PdlMetrics.tapTarget,
          child: TextField(
            controller: _controller,
            onChanged: _onChanged,
            onSubmitted: _onSubmitted,
            onTap: widget.onTap,
            readOnly: widget.readOnly,
            autofocus: widget.autofocus,
            textInputAction: widget.textInputAction,
            // **Ni correction ni suggestion.** Le clavier proposait sa
            // réécriture d'un nom de parcours ou de coéquipier, et la validait
            // tout seul en quittant le champ — y compris après une remise à
            // zéro, qui se retrouvait annulée par un mot que personne n'avait
            // choisi. Un champ de recherche cherche ce qui a été tapé.
            autocorrect: false,
            enableSuggestions: false,
            style: t.body,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: t.body.copyWith(color: c.textPlaceholder),
              filled: true,
              fillColor: c.surfaceAlt,
              isDense: true,
              // Sans icône de tête, le texte se collerait au bord : c'est la
              // loupe qui tient la gouttière de gauche quand elle est là.
              contentPadding: widget.prefixIcon == null
                  ? const EdgeInsets.symmetric(horizontal: PdlSpacing.chipGap)
                  : EdgeInsets.zero,
              prefixIcon: widget.prefixIcon == null
                  ? null
                  : Icon(widget.prefixIcon, size: 20, color: c.textPlaceholder),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 40,
                minHeight: PdlMetrics.tapTarget,
              ),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(PdlIcons.close, size: 18, color: c.textDimmed),
                      onPressed: _clear,
                      tooltip: widget.clearTooltip,
                      constraints: const BoxConstraints.tightFor(
                        width: PdlMetrics.tapTarget,
                        height: PdlMetrics.tapTarget,
                      ),
                      padding: EdgeInsets.zero,
                    ),
              suffixIconConstraints: const BoxConstraints.tightFor(
                width: PdlMetrics.tapTarget,
                height: PdlMetrics.tapTarget,
              ),
              border: border,
              enabledBorder: border,
              errorBorder: border,
              focusedErrorBorder: border,
              focusedBorder: OutlineInputBorder(
                borderRadius: PdlRadii.mdAll,
                borderSide: BorderSide(
                  color: hasError ? c.danger : c.primary,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              widget.errorText!,
              style: t.xs.copyWith(color: c.dangerOnSoft),
            ),
          ),
      ],
    );
  }
}
