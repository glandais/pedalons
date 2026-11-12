import '../material.dart';

import '../theme/pdl_tokens.dart';
import 'pdl_card.dart';
import 'pdl_skeleton.dart';

/// Les trois gabarits de chargement, un par forme de liste.
enum PdlSkeletonCardVariant {
  /// Carte à bandeau média de 208 px — fil, parcours, voyages.
  media,

  /// Ligne compacte de 100 px — listes denses, agenda.
  compact,

  /// Ligne de personne de 56 px — participants, membres.
  person,
}

/// B21 — Squelette de carte : la composition de `PdlCard` et `PdlSkeleton`.
///
/// Le squelette **emprunte la forme du contenu attendu** : un bandeau, deux
/// lignes de titre, une ligne de méta. C'est ce qui évite le saut de mise en
/// page à l'arrivée des données.
///
/// **Cinq squelettes, pas deux** (brief §5 contre maquette) : deux squelettes
/// ressemblent à une fin de liste, et le coût d'en rendre cinq est nul.
/// [PdlSkeletonCardList] applique ce nombre par défaut.
class PdlSkeletonCard extends StatelessWidget {
  const PdlSkeletonCard({
    super.key,
    this.variant = PdlSkeletonCardVariant.media,
  });

  final PdlSkeletonCardVariant variant;

  /// Hauteur du gabarit, telle que la charte la fixe.
  double get height => switch (variant) {
    PdlSkeletonCardVariant.media => PdlMetrics.media16x9,
    PdlSkeletonCardVariant.compact => 100,
    PdlSkeletonCardVariant.person => PdlMetrics.thumbSm,
  };

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      PdlSkeletonCardVariant.media => const _MediaSkeleton(),
      PdlSkeletonCardVariant.compact => const _CompactSkeleton(),
      PdlSkeletonCardVariant.person => const _PersonSkeleton(),
    };
  }
}

class _MediaSkeleton extends StatelessWidget {
  const _MediaSkeleton();

  @override
  Widget build(BuildContext context) {
    return const PdlCard(
      padding: PdlCardPadding.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PdlSkeleton(
            width: double.infinity,
            height: PdlMetrics.media16x9,
            borderRadius: BorderRadius.zero,
          ),
          Padding(
            padding: EdgeInsets.all(PdlSpacing.card),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                PdlSkeleton.text(width: 120, height: 12),
                SizedBox(height: 8),
                PdlSkeleton.text(width: 220, height: 16),
                SizedBox(height: 8),
                PdlSkeleton.text(width: double.infinity, height: 12),
                SizedBox(height: 6),
                PdlSkeleton.text(width: 160, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactSkeleton extends StatelessWidget {
  const _CompactSkeleton();

  @override
  Widget build(BuildContext context) {
    return const PdlCard(
      padding: PdlCardPadding.tight,
      child: SizedBox(
        height: 100 - 2 * PdlSpacing.cardTight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            PdlSkeleton(
              width: PdlMetrics.thumbSm,
              height: PdlMetrics.thumbSm,
              borderRadius: PdlRadii.mdAll,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  PdlSkeleton.text(width: 180, height: 15),
                  SizedBox(height: 8),
                  PdlSkeleton.text(width: 120, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonSkeleton extends StatelessWidget {
  const _PersonSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: PdlMetrics.thumbSm,
      child: Row(
        children: <Widget>[
          PdlSkeleton.circle(size: 40),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                PdlSkeleton.text(width: 140, height: 15),
                SizedBox(height: 6),
                PdlSkeleton.text(width: 90, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La liste de squelettes d'un premier chargement.
///
/// [count] vaut **5** : c'est l'arbitrage §1.0.4 du plan, contre les deux
/// squelettes de la maquette.
class PdlSkeletonCardList extends StatelessWidget {
  const PdlSkeletonCardList({
    super.key,
    this.variant = PdlSkeletonCardVariant.media,
    this.count = 5,
    this.gap = PdlSpacing.feedGap,
  });

  final PdlSkeletonCardVariant variant;
  final int count;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < count; i++) ...<Widget>[
          if (i > 0) SizedBox(height: gap),
          PdlSkeletonCard(variant: variant),
        ],
      ],
    );
  }
}
