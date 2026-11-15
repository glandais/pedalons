import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/places/domain/place_form.dart';

/// Le formulaire d'un lieu (ledger `MOB-168`) : les bornes de `PlaceRequest`
/// et la requête complète — le PUT réécrit tout le lieu.
void main() {
  PlaceForm form({
    String name = 'Parking de la gare',
    String address = '',
    String link = '',
  }) => PlaceForm.initial().copyWith(name: name, address: address, link: link);

  test('un nouveau lieu sert au départ comme à l\'arrivée', () {
    final PlaceForm initial = PlaceForm.initial();
    expect(initial.startPlace, isTrue);
    expect(initial.endPlace, isTrue);
    expect(initial.location, isNull);
    expect(initial.isValid, isFalse, reason: 'le nom est requis');
  });

  group('validité', () {
    test('le nom : 1 à 200 caractères, dont un non blanc', () {
      expect(form(name: '').nameValid, isFalse);
      expect(form(name: '   ').nameValid, isFalse);
      expect(form(name: 'A').nameValid, isTrue);
      expect(form(name: 'A' * 200).nameValid, isTrue);
      expect(form(name: 'A' * 201).nameValid, isFalse);
    });

    test('l\'adresse et le lien : vides, ou de 3 à 200 caractères', () {
      for (final String ok in <String>['', '   ', 'abc', 'a' * 200]) {
        expect(form(address: ok).addressValid, isTrue, reason: '«$ok»');
        expect(form(link: ok).linkValid, isTrue, reason: '«$ok»');
      }
      for (final String bad in <String>['a', 'ab', 'a' * 201]) {
        expect(form(address: bad).addressValid, isFalse, reason: '«$bad»');
        expect(form(link: bad).linkValid, isFalse, reason: '«$bad»');
        expect(form(address: bad).isValid, isFalse);
        expect(form(link: bad).isValid, isFalse);
      }
    });
  });

  group('toRequest', () {
    test('une adresse et un lien vides partent absents, le nom rogné', () {
      final PlaceRequest request = form(
        name: '  Parking de la gare ',
        address: '   ',
      ).toRequest();

      expect(request.name, 'Parking de la gare');
      expect(request.address, isNull);
      expect(request.link, isNull);
      expect(request.geometry, isNull);
      expect(request.startPlace, isTrue);
      expect(request.endPlace, isTrue);
      // Ce que le serveur lit : `null`, c'est-à-dire aucune valeur.
      final Map<String, Object?> json = request.toJson();
      expect(json['address'], isNull);
      expect(json['link'], isNull);
      expect(json['geometry'], isNull);
    });

    test('la requête complète, la position en [longitude, latitude]', () {
      final PlaceRequest request =
          form(
                address: ' 1 place de la Gare, Annecy ',
                link: 'https://maps.example.org/gare',
              )
              .copyWith(
                endPlace: false,
                location: () => <double>[6.1294, 45.8992],
              )
              .toRequest();

      expect(request.address, '1 place de la Gare, Annecy');
      expect(request.link, 'https://maps.example.org/gare');
      expect(request.startPlace, isTrue);
      expect(request.endPlace, isFalse);
      expect(request.geometry!.type, PlaceRequestGeometryTypeType.point);
      expect(request.geometry!.coordinates, <double>[6.1294, 45.8992]);
    });
  });

  group('fromPlace', () {
    const PlaceDetailDto place = PlaceDetailDto(
      id: 'p1',
      name: 'Col de la Forclaz',
      address: 'Montmin',
      link: 'https://maps.example.org/forclaz',
      startPlace: false,
      endPlace: true,
      geometry: GeoJsonPoint(
        type: GeoJsonPointTypeType.point,
        coordinates: <double>[6.24, 45.81],
      ),
    );

    test('un formulaire intact renvoie le lieu entier — le PUT réécrit '
        'tout', () {
      final PlaceRequest request = PlaceForm.fromPlace(place).toRequest();

      expect(request.name, 'Col de la Forclaz');
      expect(request.address, 'Montmin');
      expect(request.link, 'https://maps.example.org/forclaz');
      expect(request.startPlace, isFalse);
      expect(request.endPlace, isTrue);
      expect(request.geometry!.coordinates, <double>[6.24, 45.81]);
    });

    test('effacer la position l\'envoie absente ; ne rien dire la garde', () {
      final PlaceForm loaded = PlaceForm.fromPlace(place);

      expect(loaded.copyWith(name: 'Autre').location, <double>[6.24, 45.81]);
      expect(
        loaded.copyWith(location: () => null).toRequest().geometry,
        isNull,
      );
    });

    test('un lieu sans adresse ni lien : des champs vides, valides', () {
      final PlaceForm bare = PlaceForm.fromPlace(
        const PlaceDetailDto(
          id: 'p2',
          name: 'Mairie',
          startPlace: true,
          endPlace: true,
        ),
      );

      expect(bare.address, '');
      expect(bare.link, '');
      expect(bare.isValid, isTrue);
    });
  });
}
