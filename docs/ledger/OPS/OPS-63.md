---
id: OPS-63
title: "Erreurs côté client web et mobile (GlitchTip)"
status: out
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `OPS-63` | **Erreurs côté client web et mobile** (reliquat de `OPS-21`) : un GlitchTip auto-hébergé, compatible Sentry | Non (décidé le 17 novembre 2026 avec le propriétaire) | Une exception JavaScript ou Dart ne remonte nulle part : on ne la connaît que si quelqu'un la signale, ou par l'appel d'API en échec qu'elle laisse dans les journaux du backend. GlitchTip pèserait une base et un Redis de plus sur l'hôte, et ses événements porteraient des données personnelles à mentionner dans la politique de confidentialité ; à rouvrir si les signalements montrent des erreurs qu'on ne sait pas reproduire |
