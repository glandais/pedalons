import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_widget/markdown_widget.dart';

import '../../api/pedalons_api_client.dart';
import '../material.dart';
import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';
import '../widgets/authenticated_image.dart';
import 'pdl_image_viewer.dart';
import 'pdl_skeleton.dart';

/// B24 — Corps markdown, feuille de style unique du plan §1.3.5.
///
/// Racine 15 px / interligne 1,6 · `p` marge basse 14 · `h1/h2/h3` 20/700,
/// 18/700, 16/700 · listes retrait 20 · citation filet gauche 3 px ·
/// `pre` sur `surfaceAlt` bordé rayon 8 **à défilement horizontal** · code
/// inline mono 12 · image de 160 px rayon 8 · **table dans un conteneur bordé
/// dont le défilement horizontal est indépendant du défilement vertical de la
/// page**, largeur minimale 430 px, en-têtes 600 sur `surfaceAlt`.
///
/// Le widget ne défile pas : il se dimensionne à son contenu et laisse le
/// défilement au parent. C'est ce qui garde le `ScrollController` de la page
/// attaché au `PrimaryScrollController`, dont iOS a besoin pour le tap sur la
/// barre d'état.
///
/// **Les liens sont actifs** (F-TE-10) : `LinkConfig` reçoit [onLinkTap], et
/// `markdown_widget` n'attache un `TapGestureRecognizer` que si ce rappel est
/// non nul — c'était tout le défaut d'origine. Ce que le rappel fait de l'URL
/// — route interne, navigateur, bandeau d'échec — appartient à
/// `core/utils/link_launcher.dart` : ouvrir une application tierce est une E/S,
/// et `core/pdl` n'en fait pas. Tout appelant réel passe par
/// `core/widgets/markdown_content.dart`, qui le branche.
class PdlMarkdownBody extends StatelessWidget {
  const PdlMarkdownBody({
    super.key,
    required this.data,
    this.selectable = true,
    this.imageBuilder,
    this.onLinkTap,
    this.codeCopiedLabel,
    this.imageCloseLabel,
  });

  /// Markdown déjà résolu — les directives `::asset{…}` sont dépliées par
  /// l'appelant, qui seul connaît les DTO d'images.
  final String data;

  final bool selectable;

  /// Rendu d'image imposé. À défaut, une image authentifiée de 160 px de haut,
  /// rayon 8.
  final Widget Function(String url, Map<String, String> attributes)?
  imageBuilder;

  /// Appelé avec le `href` brut du lien tapé. **Le laisser nul rend les liens
  /// inertes** : `markdown_widget` n'attache alors aucun recognizer. Seule la
  /// galerie de démonstration s'en passe.
  final ValueChanged<String>? onLinkTap;

  /// Confirmation affichée après un appui long sur un bloc de code. Nul : la
  /// copie se fait quand même, sans retour visuel. `core/pdl` ne traduit rien,
  /// le libellé vient de l'appelant.
  final String? codeCopiedLabel;

  /// Étiquette du bouton de fermeture de la visionneuse plein écran. À défaut,
  /// celle de `MaterialLocalizations` — traduite par Flutter, jamais codée en
  /// dur ici.
  final String? imageCloseLabel;

  /// Largeur minimale d'une table avant défilement horizontal.
  static const double tableMinWidth = 430;

  /// Hauteur d'une image de contenu.
  static const double imageHeight = 160;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    final TextStyle body = t.body.copyWith(height: 1.6, color: c.text);
    final TextStyle heading = TextStyle(color: c.textBright, height: 1.35);

    final MarkdownConfig config =
        (dark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig).copy(
          configs: <WidgetConfig>[
            PConfig(textStyle: body),
            H1Config(
              style: heading.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            H2Config(
              style: heading.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            H3Config(
              style: heading.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const ListConfig(marginLeft: 20, marginBottom: 6),
            LinkConfig(
              style: body.copyWith(
                color: c.link,
                decoration: TextDecoration.underline,
                decorationColor: c.link,
              ),
              onTap: onLinkTap,
            ),
            CodeConfig(
              style: t.mono.copyWith(
                fontSize: 12,
                color: c.neutralOnSoft,
                backgroundColor: c.surfaceAlt,
              ),
            ),
            PreConfig(
              textStyle: t.mono.copyWith(fontSize: 12, color: c.text),
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: PdlRadii.mdAll,
                border: Border.all(color: c.borderSubtle),
              ),
              // Le bloc que construit `markdown_widget` défile déjà
              // horizontalement ; ce qui lui manque, c'est **l'appui long =
              // copier**. Sur un téléphone, sélectionner à la main les huit
              // lignes d'une URL d'inscription n'est pas une option.
              wrapper: (Widget child, String code, String _) => _CopyableCode(
                code: code,
                copiedLabel: codeCopiedLabel,
                child: child,
              ),
            ),
            BlockquoteConfig(
              sideColor: c.border,
              textColor: c.textDimmed,
              sideWith: 3,
            ),
            HrConfig(height: 1, color: c.borderSubtle),
            TableConfig(
              headerStyle: t.sub.copyWith(
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
              bodyStyle: t.sub.copyWith(color: c.text),
              headerRowDecoration: BoxDecoration(color: c.surfaceAlt),
              border: TableBorder.all(color: c.borderSubtle),
              // Le défilement de la table lui appartient : imbriqué dans la
              // page, il ne doit pas emporter le défilement vertical.
              wrapper: (Widget table) => Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: PdlRadii.mdAll,
                  border: Border.all(color: c.borderSubtle),
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: tableMinWidth),
                    child: table,
                  ),
                ),
              ),
            ),
            ImgConfig(
              builder:
                  imageBuilder ??
                  (String url, Map<String, String> attributes) =>
                      _MarkdownImage(
                        url: url,
                        alt: attributes['alt'],
                        closeLabel: imageCloseLabel,
                      ),
            ),
          ],
        );

    return MarkdownBlock(
      data: data,
      selectable: selectable,
      config: config,
      // `linesMargin` porte la marge basse de 14 px des paragraphes : elle
      // s'applique entre blocs, ce que `PConfig` ne sait pas faire.
      generator: MarkdownGenerator(
        linesMargin: const EdgeInsets.symmetric(vertical: 7),
      ),
    );
  }
}

/// Un bloc de code que l'appui long copie.
///
/// `Clipboard` est un canal de plateforme, pas une E/S réseau : il ne connaît
/// ni DTO ni route, et reste donc dans `core/pdl`. Le libellé de confirmation,
/// lui, vient de l'appelant.
class _CopyableCode extends StatelessWidget {
  const _CopyableCode({
    required this.code,
    required this.copiedLabel,
    required this.child,
  });

  final String code;
  final String? copiedLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // `opaque` : le geste doit gagner contre la sélection de texte du
      // `SelectionArea` qui enveloppe le corps quand `selectable` est vrai.
      behavior: HitTestBehavior.opaque,
      onLongPress: () async {
        await Clipboard.setData(ClipboardData(text: code));
        await HapticFeedback.mediumImpact();
        if (!context.mounted) return;
        final String? label = copiedLabel;
        if (label == null) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(label), behavior: SnackBarBehavior.floating),
        );
      },
      child: child,
    );
  }
}

/// L'image d'un contenu markdown : 160 px de haut, rayon 8, **plein écran au
/// tap** avec transition [Hero].
///
/// Elle lit le jeton d'accès parce que les images de contenu sont servies
/// derrière l'API : c'est le même écart que `AuthenticatedImage`, déjà employé
/// ici depuis la vague B, et il est documenté dans `core/pdl/README.md`. La
/// règle qui tient est l'autre : **aucun DTO généré n'entre ici** — le `grep`
/// de revue du README reste vide.
class _MarkdownImage extends ConsumerStatefulWidget {
  const _MarkdownImage({required this.url, this.alt, this.closeLabel});

  final String url;
  final String? alt;
  final String? closeLabel;

  @override
  ConsumerState<_MarkdownImage> createState() => _MarkdownImageState();
}

class _MarkdownImageState extends ConsumerState<_MarkdownImage> {
  /// Étiquette [Hero] **propre à cette occurrence** : la même image citée deux
  /// fois dans un article partagerait sinon une étiquette, ce qui fait lever
  /// le `Hero` au lieu d'animer.
  final Object _heroTag = Object();

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final String? token = ref.watch(accessTokenHolderProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openFullScreen(token),
        child: Semantics(
          image: true,
          button: true,
          label: widget.alt?.isNotEmpty ?? false ? widget.alt : null,
          child: Hero(
            tag: _heroTag,
            child: ClipRRect(
              borderRadius: PdlRadii.mdAll,
              child: ColoredBox(
                color: c.surfaceAlt,
                child: SizedBox(
                  height: PdlMarkdownBody.imageHeight,
                  width: double.infinity,
                  child: AuthenticatedImage(
                    imageUrl: widget.url,
                    // `contain`, pas `cover` : une image plus large ou plus
                    // haute que la bande de 160 px ne doit jamais être rognée,
                    // seulement réduite à l'échelle — d'où le fond derrière
                    // pour combler les bandes latérales ou horizontales.
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: PdlMarkdownBody.imageHeight,
                    placeholder: const PdlSkeleton(
                      width: double.infinity,
                      height: PdlMarkdownBody.imageHeight,
                    ),
                    errorWidget: ColoredBox(color: c.surfaceAlt),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openFullScreen(String? token) {
    // Plein écran : on redemande la plus grande variante, pas la vignette de
    // 400 px étirée sur toute la dalle.
    final ImageProvider? provider = AuthenticatedDecorationImage.fromUrl(
      widget.url,
      token,
      size: 1920,
    );
    if (provider == null) return;
    PdlImageViewer.show(
      context,
      imageProvider: provider,
      heroTag: _heroTag,
      closeSemanticLabel:
          widget.closeLabel ??
          MaterialLocalizations.of(context).closeButtonLabel,
    );
  }
}
