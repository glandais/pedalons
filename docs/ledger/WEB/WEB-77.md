---
id: WEB-77
title: "Page d'un groupe de sortie au web"
status: done
group: "Accueil et page Fonctionnalités"
done: 2026-10-13
---

## Livré

`WEB-77` **Page d'un groupe de sortie au web** (13 octobre 2026, contrat inchangé). Nouvelle
route `rideGroup` au contrat des routes (`/equipes/{teamSlug}/sorties/{rideSlug}/groupes/{groupId}`,
`groupId` = TSID de `RideGroupDto.id`, web, mobile et deeplink ; commune avec `MOB-67`),
`RideGroupPage` sous le détail de la sortie (fil d'Ariane `rideGroup`, méta `rideGroupMeta` en
`noindex` selon la visibilité, préchargement SSR `prefetchRideGroup`). Aucun endpoint nouveau :
la page lit ce que lit le détail (`useRideGroupData` = `useRideDetailData` + le groupe et son
leg), dont elle partage le cache, plus la page 0 des participants du groupe. Elle montre : retour
à la sortie, sélecteur de groupe (`SegmentedControl` jusqu'à 4, `Select` au-delà, libellé
`nom · inscrits/max`), en-tête (sortie, date, heure dans le fuseau de la sortie), inscription
(`useRideGroupMembership`, sorti de `RideDetailPage` et partagé), barre de places, statistiques
(départ avant / avec / après la sortie par `groupStartRelation`, allure et arrivée estimée,
distance, dénivelé positif — chacune omise si absente), meneur, météo complète du parcours
(`GroupWeatherSection` : statuts par `WeatherStatusNotice`, départ, `LegWeather`, attribution),
participants paginés et cherchables (`ParticipantList`, sorti de `ParticipantListModal`, qui
l'enveloppe), et à droite la carte collante (`.detail-map`) avec profil et « Parcours du
groupe » (`RideGroupRouteActions`, sorti de `RideGroupCard`). Un groupe inconnu (supprimé par une
édition, vieux lien) affiche un `EmptyState` qui ramène à la sortie. Sur le détail de la sortie,
`RideWeatherSection` ne garde que « Météo au départ » : le sélecteur de groupe de `WEB-76` y est
retiré (la carte et les cartes de groupe gardent `selectedGroupId`) ; chaque `RideGroupCard`
mène à la page de son groupe (nom en lien, « Voir le groupe ») et porte `GroupWeatherLine`
(température et ciel au départ du groupe, pluie, badges Face / Dos en km), précédée devant le
nom d'une barre 4 × 20 à la couleur du tracé du groupe sur la carte, comme le `PdlColorTrack` du
mobile. Tests : `RideGroupPage.test.tsx`, `routeColors.test.ts`, `GroupWeatherSection.test.tsx`, `GroupWeatherLine.test.tsx`,
`RideWeatherSection.test.tsx`, `RideGroupCard.test.tsx`, `routeMeta.test.ts`,
`useBreadcrumbGroup.test.tsx`, `groupStart.test.ts`, `groupParticipantFilters.test.ts` ; écran
`rideGroup` ajouté à `e2e/routes-render.e2e.ts` (non lancé, `WEB-78`). **À ne pas défaire** :
le panneau météo de la sortie est limité au départ, la météo le long du parcours vit sur la page
du groupe — **sauf pour une sortie sans groupe** (un seul leg sans `groupId`, pas de page de
groupe), qui garde son `LegWeather` sur le détail, sans quoi sa météo du parcours disparaîtrait ;
la ligne météo des cartes n'est **pas cliquable** (le lien est le nom et « Voir le groupe ») et
ses couleurs viennent de `relativeWindColor`, toujours doublées du libellé ; le meneur n'est
rendu que si `group.leader` est posé, **jamais de repli sur `createdBy`** ; un inscrit dans un
autre groupe lit « Vous êtes inscrit dans le groupe X. » avec un lien, sans « Rejoindre » — le
serveur n'admet qu'un groupe par sortie (`RideService.joinGroup`, 409 `ALREADY_REGISTERED`) et
ne déplace jamais ; « Rejoindre » est le seul bouton plein ; la clé des participants vient d'une
seule fonction (`participantsPageParams` / `groupParticipantsParams`, recherche vide = absente,
taille fixe 50, `?size=` ignoré) pour le préchargement et la page, sans quoi l'hydratation
relit la liste ; la couleur de la barre d'une carte de groupe vient de `routeColorsById`
(`lib/routeColors.ts`), la numérotation même de `RoutesMapView` (rang parmi les éléments qui ont
un tracé, parcours principal compris), **pas de `sortOrder`** comme au mobile : la carte web
numérote autrement, et la barre n'aurait plus la couleur du tracé.
