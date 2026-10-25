import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/models/map_style_dto.dart';
import 'package:pedalons/core/config/config_provider.dart';

void main() {
  const MapStyleDto colorful = MapStyleDto(
    id: 'colorful',
    label: 'Coloré',
    group: 'vector',
    url: 'https://tiles.example/colorful.json',
    darkVariant: 'https://tiles.example/eclipse.json',
  );
  const MapStyleDto satellite = MapStyleDto(
    id: 'satellite',
    label: 'Satellite',
    group: 'satellite',
    url: 'https://tiles.example/satellite.json',
  );
  const List<MapStyleDto> styles = <MapStyleDto>[colorful, satellite];

  group('resolveMapStyle', () {
    test('sert la variante sombre quand elle existe', () {
      expect(
        resolveMapStyle(styles, 'colorful', Brightness.dark)!.url,
        colorful.darkVariant,
      );
      expect(
        resolveMapStyle(styles, 'colorful', Brightness.light)!.url,
        colorful.url,
      );
    });

    test('un style sans variante sombre reste utilisable en sombre', () {
      // Escamoter le fond satellite en mode sombre serait pire que de le
      // rendre tel quel.
      final ResolvedMapStyle? r = resolveMapStyle(
        styles,
        'satellite',
        Brightness.dark,
      );
      expect(r!.url, satellite.url);
      expect(r.style.id, 'satellite');
    });

    test('un identifiant mémorisé disparu retombe sur le premier style servi', () {
      // Le contrat peut retirer un fond entre deux versions du serveur : mieux
      // vaut une carte que rien.
      expect(
        resolveMapStyle(styles, 'fond-retire', Brightness.light)!.style.id,
        'colorful',
      );
      expect(
        resolveMapStyle(styles, null, Brightness.light)!.style.id,
        'colorful',
      );
    });

    test('aucun style servi ne rend rien plutôt qu\'une URL inventée', () {
      expect(
        resolveMapStyle(const <MapStyleDto>[], 'colorful', Brightness.light),
        isNull,
      );
    });
  });

  group('compareSemver', () {
    test('ordonne les versions par composante', () {
      expect(compareSemver('1.2.3', '1.2.3'), 0);
      expect(compareSemver('1.2.3', '1.2.4'), lessThan(0));
      expect(compareSemver('1.3.0', '1.2.9'), greaterThan(0));
      expect(compareSemver('2.0.0', '10.0.0'), lessThan(0));
    });

    test('ignore les qualificatifs de pré-version et de build', () {
      // Le plancher porte sur la version livrée, pas sur une RC.
      expect(compareSemver('1.2.3-rc.1', '1.2.3'), 0);
      expect(compareSemver('1.2.3+42', '1.2.3'), 0);
    });

    test('complète une version incomplète par des zéros', () {
      expect(compareSemver('1.2', '1.2.0'), 0);
      expect(compareSemver('1', '1.0.1'), lessThan(0));
    });

    test('une composante illisible vaut zéro plutôt que de lever', () {
      expect(compareSemver('1.x.3', '1.0.3'), 0);
    });
  });
}
