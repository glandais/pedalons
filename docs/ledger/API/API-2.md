---
id: API-2
title: "Logo d'équipe sur `TeamPublicationDto`"
status: done
group: "Petites évolutions d'API"
done: 2026-09-30
---

## Livré

| ID | Livré | Écrans |
|---|---|---|
| `API-2` | **Logo d'équipe sur `TeamPublicationDto`** (2026-09-30) — **API 5.8.0** : `logoUrl`, nullable, même valeur que `TeamDetailDto.logoUrl` (le logo de la page « À propos », gabarit `{size}`). Il vient de deux `@Formula` de `Team` (`logoAssetId`, `aboutPageVisibility`), des sous-requêtes corrélées lues dans le `SELECT` même qui charge l'équipe : aucune requête ni entité de plus par ligne, ni par équipe, et `Team.aboutPage` reste LAZY. Ne pas le remplacer par une marche sur `aboutPage.assets` (c'est ce que le LAZY évite), ni par une table de correspondance à passer à la douzaine de fabriques qui construisent `TeamPublicationDto`. Le mobile passe le logo à `PdlTeamLine` (fiche et carte de sortie, publication, voyage, annonce via `TeamBanner`, page d'équipe, carrousel, prochaine sortie, carte et fiche de parcours) avec les initiales en repli. Le web n'avait pas ce repli : ses fiches lisent l'équipe entière (`TeamContextBanner`), ses cartes n'ont qu'une icône, rien à changer. Couvert par `PostResourceTest.getPost_carriesTheTeamLogo_sameAsTheTeamDetail` (fiche et liste compacte, identique à la fiche d'équipe), les `…QueryCountTest` verts, et `post_detail_page_test.dart` (logo, puis initiales sans logo) | 11, 12, 13, 24, 31, 32 |
