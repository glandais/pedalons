---
id: MOB-74
title: "Exclure du manifeste Android les pages du site sans écran dans l'app"
status: out
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `MOB-74` | **Exclure du manifeste Android les pages du site sans écran dans l'app** (`<uri-relative-filter-group android:allow="false">`, API 35+) | Non (11 octobre 2026 ; part écartée de `MOB-59`, renumérotée le 16 octobre 2026) | L'app reçoit ces liens et les passe au navigateur (`isSitePageLocation` dans `openDeepLink`) : il ne reste qu'un bref passage par l'app. L'exclusion ne vaudrait que sous Android 15+, ne se vérifie que sur un appareil avec la vérification des App Links, et un manifeste faux casse tous les liens d'app. À rouvrir si le passage par l'app gêne |
