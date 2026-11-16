---
id: WEB-44
title: "Passkey en tête du formulaire de connexion"
status: out
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `WEB-44` | **Passkey en tête du formulaire de connexion** | Ordre actuel gardé (décidé le 4 octobre 2026 avec le propriétaire) | `LoginForm` (`WEB-42`) garde email et mot de passe en tête, puis « ou », puis la passkey et le code par e-mail. Le bouton passkey n'apparaît qu'après hydratation (`browserSupportsWebAuthn`) : en tête, il décalerait le haut de l'accueil rendu côté serveur |
