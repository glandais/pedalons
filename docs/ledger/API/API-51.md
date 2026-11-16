---
id: API-51
title: "La pose du marqueur du rattrapage GPX est testée"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-09-30
---

## Livré

`API-51` **La pose du marqueur du rattrapage GPX est testée** (2026-09-30) — trois tests dans
`GpxSanitizationBackfillTest` sur `runOnce` : après une passe sans échec, les fichiers sont
nettoyés et `maintenance/api-44-gpx-sanitized` existe ; marqueur présent, un fichier sale reste
sale (la passe ne tourne pas) ; un fichier sale et illisible fait échouer la passe
(`failed() == 1`) et aucun marqueur n'est écrit. Le bucket de test étant partagé, le marqueur est
effacé avant et après chaque test de la classe (`@AfterEach`) : ne pas retirer ce nettoyage, un
marqueur oublié ferait sauter la passe à tout test qui appellerait `runOnce`. **Écrits sans avoir
été lancés** (les tests backend sont au propriétaire du dépôt) : `mvn test
-Dtest=GpxSanitizationBackfillTest`.
