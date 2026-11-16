---
id: WEB-46
title: "Le tiroir mobile dit que la ligne avatar + nom mène au profil"
status: done
group: "Défauts d'interface"
done: 2026-10-04
---

## Livré

`WEB-46` **Le tiroir mobile dit que la ligne avatar + nom mène au profil** (4 octobre 2026,
relevé dans `docs/BUGS.md`) — dans le burger (`Layout.tsx`), le seul accès au profil était la
pastille et le nom, sans rien qui le signale. La ligne garde son lien et gagne « Voir mon profil »
(`nav.viewProfile`) sous le nom, et un chevron. **À ne pas défaire** : le nom affiché reste dans le
nom accessible du lien, `openProfileInApp` (`e2e/support/moderation.ts`) le trouve par lui.
