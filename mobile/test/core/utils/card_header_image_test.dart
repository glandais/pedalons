import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/utils/card_header_image.dart';

/// Règle R10 des cartes (KIT §9, docs/LEDGER_*.md MOB-139) : la photo, sinon
/// la carte du tracé, sinon le dégradé ; la vignette du tracé seulement sous
/// une photo.
void main() {
  MediaDto media(List<AssetDto> images) => MediaDto(
    markdown: '',
    assets: AssetsDto(images: images, attachments: const <AssetDto>[]),
  );
  AssetDto image(String id, {String? imageUrl}) => AssetDto(
    id: id,
    fileName: '$id.jpg',
    contentType: 'image/jpeg',
    url: '/api/download/team/$id',
    imageUrl: imageUrl,
  );

  test('firstPhotoUrl : la première image affichable', () {
    expect(firstPhotoUrl(null), isNull);
    expect(firstPhotoUrl(media(const <AssetDto>[])), isNull);
    expect(
      firstPhotoUrl(
        media(<AssetDto>[
          image('a'),
          image('b', imageUrl: 'https://x/b/{size}'),
          image('c', imageUrl: 'https://x/c/{size}'),
        ]),
      ),
      'https://x/b/{size}',
    );
  });

  test('une photo prend le bandeau, le tracé passe en vignette', () {
    final CardHeaderImage h = cardHeaderImage(photo: 'photo', trackMap: 'map');
    expect(h.banner, 'photo');
    expect(h.trackThumbnail, 'map');
  });

  test('sans photo, le tracé prend le bandeau et la vignette disparaît', () {
    final CardHeaderImage h = cardHeaderImage(trackMap: 'map');
    expect(h.banner, 'map');
    expect(h.trackThumbnail, isNull);
  });

  test('ni photo ni tracé : rien, la carte pose son dégradé', () {
    final CardHeaderImage h = cardHeaderImage();
    expect(h.banner, isNull);
    expect(h.trackThumbnail, isNull);
  });
}
