import '../../../api/generated/export.dart';
import '../../../core/material.dart';
import '../../../core/pdl/pdl.dart';
import '../../../core/theme/enum_colors.dart';
import '../../../core/theme/pdl_colors.dart';

/// Combien de tags une carte de liste montre avant « +n » (plan des tags,
/// D19 : « 2-3 tags puis +n »). Trois, parce qu'une carte en porte rarement
/// plus et qu'à quatre la rangée passe à la ligne sur un téléphone.
const int kCardTagLimit = 3;

/// Traduit les tags d'un contenu en entrées de [PdlTagRow].
///
/// La couleur est l'**aplat** de la famille : c'est la pastille, jamais un
/// fond — le fond doux est la forme des badges métier (D10).
List<PdlTagEntry> tagEntries(PdlColors c, List<TagDto> tags) => <PdlTagEntry>[
  for (final TagDto tag in tags)
    PdlTagEntry(label: tag.label, color: tagFamily(tag.color).soft(c).fill),
];

/// Les tags d'un contenu (ledger `MOB-39`) : tronqués sur une carte
/// ([maxVisible], en général [kCardTagLimit]), complets sur une fiche.
///
/// La façade DTO de [PdlTagRow] — `core/pdl` ne connaît pas `TagDto`. Elle ne
/// rend rien pour un contenu sans tag ; c'est à l'appelant de ne pas réserver
/// d'espacement autour d'elle dans ce cas (`tags.isNotEmpty`).
class ContentTagRow extends StatelessWidget {
  const ContentTagRow({super.key, required this.tags, this.maxVisible});

  final List<TagDto> tags;
  final int? maxVisible;

  @override
  Widget build(BuildContext context) {
    return PdlTagRow(
      tags: tagEntries(context.pdl, tags),
      maxVisible: maxVisible,
    );
  }
}
