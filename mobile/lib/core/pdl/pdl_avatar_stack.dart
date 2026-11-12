import '../material.dart';

import '../theme/pdl_colors.dart';
import '../theme/pdl_tokens.dart';
import '../theme/pdl_typography.dart';
import 'pdl_avatar.dart';

/// Une personne d'une grappe d'avatars. **Aucun DTO** : l'appelant projette
/// le sien sur ces trois champs.
@immutable
class PdlAvatarEntry {
  const PdlAvatarEntry({
    required this.name,
    this.imageUrl,
    this.isCurrentUser = false,
  });

  final String name;
  final String? imageUrl;
  final bool isCurrentUser;
}

/// B2 — Grappe d'avatars qui se chevauchent.
///
/// Chevauchement de [PdlSpacing.avatarOverlap] (−4), anneau 2 px `surface`
/// pour détacher chaque disque du précédent, et une pastille « +N » quand la
/// grappe dépasse [max].
///
/// La pastille de reste n'est pas un avatar : fond `neutralSoft`, texte
/// `textDimmed` en 600. Elle dit un nombre, elle ne représente personne.
class PdlAvatarStack extends StatelessWidget {
  const PdlAvatarStack({
    super.key,
    required this.people,
    this.max = 5,
    this.size = 26,
    this.onTap,
    this.semanticLabel,
    this.total,
  });

  final List<PdlAvatarEntry> people;

  /// Nombre d'avatars rendus avant la pastille de reste.
  final int max;

  final double size;
  final VoidCallback? onTap;

  /// Libellé d'accessibilité de la grappe entière — `core/pdl` ne traduit
  /// rien, et lire 35 initiales ne renseigne personne.
  final String? semanticLabel;

  /// Tout le monde que la grappe représente, quand [people] n'en est qu'un
  /// aperçu — un groupe ou un voyage n'embarque que ses premiers
  /// participants. La pastille « +N » se compte alors sur lui.
  final int? total;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;

    final int shown = people.length <= max ? people.length : max;
    final int rest = (total ?? people.length) - shown;

    final Widget more = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.neutralSoft,
        shape: BoxShape.circle,
        border: Border.all(color: c.surface, width: 2),
      ),
      child: Text(
        '+$rest',
        // Comme dans `PdlAvatar` : un disque de 26 px ne suit pas
        // l'agrandissement typographique sans déborder.
        textScaler: TextScaler.noScaling,
        style: t.badge.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: c.textDimmed,
          height: 1,
        ),
      ),
    );

    final List<Widget> discs = <Widget>[
      for (int i = 0; i < shown; i++)
        PdlAvatar(
          name: people[i].name,
          imageUrl: people[i].imageUrl,
          isCurrentUser: people[i].isCurrentUser,
          size: size,
          ring: true,
        ),
      if (rest > 0) more,
    ];

    if (discs.isEmpty) return const SizedBox.shrink();

    // Le chevauchement passe par un `Stack` et non par une marge négative :
    // `Padding` refuse les valeurs négatives (`padding.isNonNegative`), et le
    // pas d'avance vaut `size + avatarOverlap`.
    final double step = size + PdlSpacing.avatarOverlap;

    final Widget stack = SizedBox(
      width: size + step * (discs.length - 1),
      height: size,
      child: Stack(
        children: <Widget>[
          for (int i = 0; i < discs.length; i++)
            Positioned(left: step * i, child: discs[i]),
        ],
      ),
    );

    final Widget labelled = Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: stack,
    );

    if (onTap == null) return labelled;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: labelled,
    );
  }
}
