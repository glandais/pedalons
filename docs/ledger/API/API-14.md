---
id: API-14
title: "Logo des services GPS"
status: done
group: "Petites évolutions d'API"
done: 2026-10-02
---

## Livré

| ID | Livré | Écrans |
|---|---|---|
| `API-14` | **Logo des services GPS** (2026-10-02) — sans changement de contrat. **Tranché avec le propriétaire : côté clients, pas de `logoUrl` au contrat** — `GpsServiceType` est un enum fermé, une URL n'apporterait rien. Les trois logos (Garmin, Wahoo, Hammerhead) sont des **tuiles carrées à fond sombre**, lisibles dans les deux thèmes ; celui de Hammerhead, fourni en tracé blanc sur fond transparent (invisible sur fond clair), a été posé sur une tuile `#212121`, le fond du logo Wahoo. Web : `frontend/src/assets/gps/*.svg`, `GPS_SERVICE_LOGOS` dans `GpsConnectionsManager` à la place de l'icône générique. Mobile : PNG 32 px en 1x/2x/3x (`mobile/assets/gps/`, rasterisés des mêmes SVG — pas de `flutter_svg` pour trois images), `gpsServiceLogoAsset`, et un emplacement `leading` (un widget) sur `PdlSettingRow`. Le logo est décoratif (`alt=""`, `ExcludeSemantics`) : le nom du service est à côté. `SocialIdentityDto.externalUsername`, l'autre moitié de l'entrée d'origine, était devenu sans objet avec le retrait de Strava (API `5.0.0`). Un nouveau service ajouté à l'enum n'aura pas de logo tant qu'on ne l'aura pas ajouté aux deux tables. Test : `gps_service_logo_test.dart` (chaque service connu a un logo réellement embarqué) | 33 |
