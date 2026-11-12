import 'package:flutter/services.dart';

import '../material.dart';
import '../pdl/pdl.dart';
import '../theme/pdl_colors.dart';
import '../theme/pdl_icons.dart';
import '../theme/pdl_typography.dart';
import 'authenticated_image.dart';

/// La barre supérieure d'un écran de détail à vignette.
///
/// F-DE-1 : `FlexibleSpaceBar(title:)` posait un titre `onSurface` — noir en
/// clair — **directement** sur la photo de couverture. Sur une vignette
/// enneigée, ou simplement claire, il n'y avait plus de titre ; sur une
/// vignette sombre, plus de flèche de retour. La règle de la charte est sans
/// appel : jamais de texte posé sur une photo ou une tuile.
///
/// La correction est celle du plan §1.5 : l'image est surmontée d'un
/// [PdlScrim.top] de 150 px et d'un [PdlScrim.bottom] de 90 px, le titre et
/// les actions passent en blanc ([PdlAppBarVariant.overlay]), et la barre
/// système bascule en [SystemUiOverlayStyle.light] — sans quoi l'heure noire
/// de l'appareil disparaît à son tour.
///
/// Sans vignette il n'y a rien à voiler : la barre retombe sur le rendu plein
/// de la charte, titre `text` sur `surface`.
class MediaSliverAppBar extends StatelessWidget {
  const MediaSliverAppBar({
    super.key,
    required this.title,
    required this.imageUrl,
    this.heroTag,
    this.expandedHeight = 200,
    this.actions = const <Widget>[],
    this.onBack,
    this.backSemanticLabel,
  });

  final String title;

  /// Vignette de couverture. `null` ⇒ barre pleine, sans voile.
  final String? imageUrl;

  /// Étiquette de transition partagée avec la carte d'origine.
  final Object? heroTag;

  final double expandedHeight;
  final List<Widget> actions;

  /// Retour explicite ; à défaut, celui du navigateur.
  final VoidCallback? onBack;
  final String? backSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final String? url = imageUrl;
    final bool overlay = url != null;
    final PdlAppBarVariant variant = overlay
        ? PdlAppBarVariant.overlay
        : PdlAppBarVariant.solid;

    Widget image = AuthenticatedImage(
      imageUrl: url ?? '',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorWidget: const SizedBox.shrink(),
    );
    if (heroTag != null) image = Hero(tag: heroTag!, child: image);

    return SliverAppBar(
      expandedHeight: overlay ? expandedHeight : null,
      pinned: true,
      backgroundColor: overlay ? Colors.transparent : c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      // Sur une vignette, la barre système est claire : sinon l'heure noire de
      // l'appareil se perd dans une photo sombre.
      systemOverlayStyle: overlay ? SystemUiOverlayStyle.light : null,
      automaticallyImplyLeading: false,
      leading: PdlAppBarAction(
        icon: PdlIcons.back,
        variant: variant,
        semanticLabel: backSemanticLabel,
        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
      ),
      actions: actions,
      title: overlay ? null : Text(title),
      flexibleSpace: overlay
          ? FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(
                start: 56,
                bottom: 14,
                end: 16,
              ),
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.pdlText.barTitle.copyWith(color: c.onPrimary),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  image,
                  // Haut : sous la barre supérieure translucide.
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: PdlScrim.top(),
                  ),
                  // Bas : sous le titre, qui vient s'y poser en se rétractant.
                  const Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: PdlScrim.bottom(),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
