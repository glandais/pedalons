---
id: WEB-65
title: "Tableau de bord pour un admin de plateforme non membre"
status: out
---

## Écarté

| ID | Sujet | Décision | Ce que ça implique |
|---|---|---|---|
| `WEB-65` | **Tableau de bord pour un admin de plateforme non membre** | Tableau complet, décidé le 6 octobre 2026 avec le propriétaire (remplace la décision du 5 octobre, « les non-membres gardent la page publique », dépassée par l'Agenda d'équipe `API-86`, `WEB-68`, `MOB-60`) | Le fil a disparu et le tableau de bord est rendu à tout le monde, web et mobile ensemble. `TeamDashboardService` traite un admin de plateforme en `ADMIN` (`platformAdmin || …`) : non membre, il reçoit le tableau ADMIN complet (blocs organisateur et admin), comme il voit toutes les équipes dans « Mes équipes » (`API-67`). C'est voulu : ne pas le ramener à la partie publique, ni dans le service ni dans un client |
