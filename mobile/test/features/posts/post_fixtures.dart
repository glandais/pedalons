import 'package:pedalons/api/generated/export.dart';

import '../../support/content_permissions.dart';

/// Jeux de données de l'éditeur de publication (ledger `MOB-156`).
const TeamPublicationDto fixturePostTeam = TeamPublicationDto(
  accessible: true,
  id: 't1',
  slug: 'n-peloton',
  name: 'N-Peloton',
  visibility: 'PUBLIC',
);

/// Une publication. Par défaut le bloc `permissions` d'un organisateur
/// (docs/LEDGER_*.md MOB-137).
PostDto fixturePost({
  String slug = 'retour-de-sortie',
  String name = 'Retour de sortie',
  String status = 'PUBLISHED',
  bool deleted = false,
  bool signedAsTeam = false,
  String? publishAt,
  String timezone = 'Europe/Paris',
  List<TagDto> tags = const <TagDto>[],
  ContentPermissionsDto? permissions,
}) => PostDto(
  permissions: permissions ?? permissionsFor(member: true, role: 'ORGANIZER'),
  timezone: timezone,
  tags: tags,
  type: 'POST',
  team: fixturePostTeam,
  id: 'p1',
  slug: slug,
  name: name,
  media: const MediaDto(
    markdown: 'Belle matinée.',
    assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
  ),
  // 11:00 à Paris (heure d'été).
  dateTime: '2026-05-03T09:00:00Z',
  status: status,
  visibility: 'TEAM',
  deleted: deleted,
  commentCount: 0,
  signedAsTeam: signedAsTeam,
  publishAt: publishAt,
);
