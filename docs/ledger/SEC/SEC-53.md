---
id: SEC-53
title: "Liste de refus des pièces jointes : le label du modèle, pas seulement celui de Magika"
status: done
done: 2026-11-16
---

## Livré

`SEC-53` **Liste de refus des pièces jointes : le label du modèle, pas seulement celui de Magika**
(16 novembre 2026, contrat inchangé) — magika 0.7.0 (PR Dependabot 445, avec Jackson 3.3.0) passe
par défaut en mode « haute confiance » : sous son seuil, une prédiction devient `txt` ou `unknown`, et
son *overwrite map* change `randomtxt` en `txt`. Mesuré sur la même série de fichiers : un script
PowerShell d'une ligne, lu `powershell` à 0,95 par la 0.6.1, sort `txt` (0,43 pour `powershell`),
que la liste de refus d'`ATTACHMENT` ne nomme pas : il aurait été stocké en `text/plain`.
`DetectedFileType` porte désormais `modelLabel` (le `dlLabel` de Magika, le label lui-même pour un
fichier trop petit pour le modèle) et `FileTypeCategory.accepts(label, modelLabel)` refuse l'un ou
l'autre pour une liste de refus ; une liste d'admission (image, GPX, FIT) décide sur le label seul.
Le reste de la série ne change pas de verdict (shell, Python, PHP, batch, Mach-O, HTML, SVG, GPX).
magika 0.7.0 n'amène plus `error_prone_core`, guava ni `slf4j-simple` à la compilation : la
surcharge de guava d'`API-148` est retirée. Couvert par
`FileTypeDetectorTest.LowConfidenceScripts` et `FileTypeCategoryTest`
(`refusesWhatTheModelReadBehindALowConfidenceLabel`, `anAllowlistDecidesOnTheLabelAlone`), écrits,
non lancés. **À ne pas défaire** : ne pas revenir au mode `BEST_GUESS` pour retrouver l'ancien
comportement : le label confiant sert au choix du type MIME, et le modèle a changé
(`standard_v3_3`) ; ne pas tester `modelLabel` contre une liste d'admission, ce qui y ferait entrer
des lectures incertaines.
