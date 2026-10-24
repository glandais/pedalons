import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../keys.dart';
import '../../providers/profile_summary_provider.dart';

/// Quitte une sous-page du profil : on dépile quand une pile existe (ouverte
/// depuis la vue d'ensemble, ou par un lien froid qui a posé ses ancêtres
/// dessous), sinon on retombe sur la vue d'ensemble. Sans pile, c'est un
/// changement de branche (la boîte de réception ouvre ses réglages par `go`) :
/// une flèche qui ne mènerait nulle part serait pire que pas de flèche.
void leaveProfileSubpage(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(Paths.profile());
  }
}

/// Relit le résumé du profil quand la sous-page qu'il enveloppe quitte l'arbre
/// — un compteur a pu y changer (une clé d'accès ajoutée, un appareil
/// désappairé…).
///
/// Attaché à la sous-page et non au `push` de la vue d'ensemble : une
/// sous-page ouverte par un lien froid puis fermée par `pop`, ou par le geste
/// de retour du système, rafraîchit aussi les lignes d'état. Une sous-page
/// recouverte par une autre (« Personnes bloquées » sur « Confidentialité »)
/// reste montée : rien n'est relu avant qu'on la quitte vraiment.
class ProfileSummaryRefreshOnLeave extends StatefulWidget {
  const ProfileSummaryRefreshOnLeave({super.key, required this.child});

  final Widget child;

  @override
  State<ProfileSummaryRefreshOnLeave> createState() =>
      _ProfileSummaryRefreshOnLeaveState();
}

class _ProfileSummaryRefreshOnLeaveState
    extends State<ProfileSummaryRefreshOnLeave> {
  // Pris pendant que l'élément est vivant : `dispose` ne peut plus remonter
  // l'arbre pour le trouver.
  ProviderContainer? _container;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context, listen: false);
  }

  @override
  void dispose() {
    // Hors du démontage : l'arbre est verrouillé pendant `dispose`, et
    // l'invalidation demande au `ProviderScope` de se reconstruire.
    final ProviderContainer? container = _container;
    if (container != null) {
      scheduleMicrotask(() {
        try {
          container.invalidate(profileSummaryProvider);
        } on StateError {
          // Le conteneur est parti avec l'app : plus rien à relire.
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// L'écran d'une sous-page du profil : la barre avec son retour vers
/// « Profil », et une colonne de sections bornée à la largeur de contenu.
///
/// Toutes les sous-pages passent par ici pour que le retour dise la même
/// chose partout (« Retour au profil »), que le résumé du profil soit relu en
/// la quittant ([ProfileSummaryRefreshOnLeave]), et que la vue d'ensemble,
/// l'onglet racine, reste la seule page du profil sans flèche.
class ProfileSubpage extends StatelessWidget {
  const ProfileSubpage({
    super.key,
    required this.title,
    required this.slivers,
    this.intro,
    this.onRefresh,
    this.actions = const <Widget>[],
  });

  final String title;

  /// Une phrase sous la barre, avant la première section : ce que la page
  /// règle, quand le titre ne suffit pas à le dire.
  final String? intro;

  final List<Widget> slivers;
  final Future<void> Function()? onRefresh;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    return ProfileSummaryRefreshOnLeave(
      child: PdlScreenScaffold(
        appBar: PdlAppBar(
          title: title,
          onBack: () => leaveProfileSubpage(context),
          backSemanticLabel: 'profile.backToProfile'.tr(),
          backKey: keys.profile.backButton,
          actions: actions,
        ),
        onRefresh: onRefresh,
        slivers: <Widget>[
          const SliverToBoxAdapter(child: SizedBox(height: PdlSpacing.section)),
          if (intro != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  PdlSpacing.section,
                  0,
                  PdlSpacing.section,
                  PdlSpacing.section,
                ),
                child: Text(intro!, style: t.sub),
              ),
            ),
          ...slivers,
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }
}

/// Une section d'une page du profil : un en-tête facultatif, son contenu
/// (une carte, le plus souvent) et une note facultative dessous.
class ProfileSection extends StatelessWidget {
  const ProfileSection({
    super.key,
    this.title,
    this.count,
    required this.child,
    this.footnote,
  });

  final String? title;
  final String? count;
  final Widget child;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PdlSpacing.section,
        0,
        PdlSpacing.section,
        PdlSpacing.section,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (title != null) PdlSectionHeader(title: title!, count: count),
          child,
          if (footnote != null) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(footnote!, style: t.xs),
            ),
          ],
        ],
      ),
    );
  }
}
