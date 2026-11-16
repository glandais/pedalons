---
id: WEB-88
title: "Bouton Partager sur la vue d'un aperçu GPX"
status: done
group: "Outils GPX (repris de biketeam)"
done: 2026-10-15
---

## Livré

`WEB-88` **Bouton Partager sur la vue d'un aperçu GPX** (2026-10-15, sans changement de contrat) — `components/gpxtool/GpxPreviewView.tsx` place le `ShareButton` commun à droite du titre, comme `RouteDetailPage` et `RideDetailPage` : `navigator.share({ title, url })` quand le navigateur le propose (une fenêtre fermée ne fait rien), sinon copie du lien avec la notification `share.copied` (`share.copyFailed` en cas d'échec). Visible de tout visiteur, connecté ou non : l'aperçu est public par son lien. Aucune clé i18n nouvelle. Tests : `GpxPreviewView.test.tsx` (visiteur anonyme et membre voient « Partager », seul le membre voit « Enregistrer comme parcours »), le comportement du partage étant couvert par `ShareButton.test.tsx`. **À ne pas défaire** : réutiliser `ShareButton`, pas de second composant de partage ; ne pas réserver le bouton aux membres.
