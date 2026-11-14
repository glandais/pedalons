import 'package:pedalons/api/generated/export.dart';

import '../../support/content_permissions.dart';

/// Jeux de données du lot 5 pour les annonces.
///
/// Un `AdDto` coûte treize champs obligatoires ; deux copies de ce coût
/// divergent dès qu'un champ s'ajoute au contrat.
const MediaDto kEmptyMedia = MediaDto(
  markdown: '',
  assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
);

const TeamPublicationDto kAdTeam = TeamPublicationDto(
  accessible: true,
  id: 't1',
  slug: 'n-peloton',
  name: 'N-Peloton',
  visibility: 'PUBLIC',
);

AdDto fixtureAd({
  String slug = 'velo-a-vendre',
  String name = 'Vélo à vendre',
  String adType = 'SALE',
  String status = 'PUBLISHED',
  num? price = 1200,
  String? rentalPeriod,
  String? excerpt = 'Un vélo en très bon état.',
  String? locationDescription,
  AdDtoLocationGeometry? locationGeometry,
  List<String> images = const <String>[],
  String createdById = 'u-seller',
  String createdByDisplayName = 'Jeanne Martin',
  MediaDto media = kEmptyMedia,
  bool deleted = false,
  ContentPermissionsDto permissions = kNoPermissions,
}) => AdDto(
  permissions: permissions,
  tags: const [],
  team: kAdTeam,
  id: 'ad-$slug',
  slug: slug,
  name: name,
  media: media,
  images: images,
  status: status,
  visibility: 'TEAM',
  adType: adType,
  createdAt: '2026-03-14T09:00:00Z',
  updatedAt: '2026-03-14T09:00:00Z',
  createdById: createdById,
  createdByDisplayName: createdByDisplayName,
  deleted: deleted,
  excerpt: excerpt,
  thumbnailUrl: images.isEmpty ? null : images.first,
  price: price,
  rentalPeriod: rentalPeriod,
  locationDescription: locationDescription,
  locationGeometry: locationGeometry,
);

/// Le droit que le backend calcule pour l'auteur d'une annonce ou pour
/// l'administration de l'équipe (docs/LEDGER_*.md MOB-137).
const ContentPermissionsDto kAdOwnerPermissions = ContentPermissionsDto(
  canEdit: true,
  canDelete: true,
  indexable: false,
);

/// L'annonce telle que son formulaire la lit (`GET …/edit`, ledger
/// `MOB-158`).
AdEditDto fixtureAdEdit({
  String slug = 'velo-a-vendre',
  String name = 'Vélo à vendre',
  String adType = 'SALE',
  String status = 'PUBLISHED',
  num? price = 1200,
  String? rentalPeriod,
  String? locationDescription = 'Lyon 7e',
  List<double>? coordinates,
  List<TagDto> tags = const <TagDto>[],
}) => AdEditDto(
  team: kAdTeam,
  id: 'ad-$slug',
  slug: slug,
  name: name,
  media: kEmptyMedia.copyWith(markdown: 'Très bon état.'),
  status: status,
  visibility: 'TEAM',
  adType: adType,
  createdAt: '2026-03-14T09:00:00Z',
  updatedAt: '2026-03-14T09:00:00Z',
  createdById: 'u-seller',
  deleted: false,
  tags: tags,
  price: price,
  rentalPeriod: rentalPeriod,
  locationDescription: locationDescription,
  locationGeometry: coordinates == null
      ? null
      : AdEditDtoLocationGeometry(
          type: AdEditDtoLocationGeometryTypeType.point,
          coordinates: coordinates,
        ),
);

/// [count] annonces distinctes, pour remplir une page.
List<AdDto> fixtureAds(int count, {int from = 0}) => <AdDto>[
  for (int i = from; i < from + count; i++)
    fixtureAd(slug: 'annonce-$i', name: 'Annonce $i', price: 100 + i),
];
