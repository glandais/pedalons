---
id: MOB-90
title: "Le détail d'un parcours dit à quelle équipe il appartient"
status: done
group: "Navigation à deux niveaux : analyse du 24 octobre 2026 (contrat d'API inchangé)"
---

## Livré

`MOB-90` **Le détail d'un parcours dit à quelle équipe il appartient** — `RouteSheetHeader`
(`features/routes/presentation/widgets/route_sheet_header.dart`) porte au-dessus du titre le
même `PdlTeamLine` cliquable que les détails de sortie, de voyage, de publication et d'annonce,
avec `pushLocation` vers l'équipe. Il apparaît aux crans moyen et haut ; la bande compacte du
cran bas n'en a pas. `team` est requis sur les DTO de parcours : pas de cas sans équipe. Test :
`test/features/routes/route_sheet_header_test.dart`. **À ne pas défaire** : la ligne d'équipe de
la page personnalisée (`team_custom_page.dart`) reste **non cliquable**. La page est une
sous-route de l'équipe, qui est donc toujours la page dessous : le retour y mène, et un tap en
empilerait une seconde copie. Reste ouvert : la rangée « Équipe » de la section Informations du
parcours répète désormais la ligne d'équipe.
