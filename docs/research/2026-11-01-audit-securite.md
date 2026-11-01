# Audit de sécurité — novembre 2026 (version expurgée)

> **Version publique.** Le dépôt est public : comme pour l'audit de septembre, les constats encore
> ouverts ne portent ici que leur identifiant, leur sévérité et une phrase, sans point d'entrée,
> trace ni scénario. Le rapport complet (traces, preuves, tests de régression, correctifs) est
> conservé hors du dépôt.

- **Révision auditée** : `1780210c` (develop, arbre propre), le 2026-11-01.
- **Méthode** : revue de source multi-agents, profil standard. Reconnaissance (4 agents), registre
  de couverture déterministe de 27 unités, deux vagues de chasse (12 agents), trois critiques de
  couverture jusqu'à un passage propre, puis validation indépendante de chaque candidat (Phase 3)
  et revérification de chaque dossier retenu par un agent neuf (Phase 5). 29 agents au total.
- **Aucune exécution** : ni build, ni test, ni requête vers un environnement déployé ou un
  fournisseur. Les constats « confirmés » le sont par lecture de source déterministe ; les pistes
  « à valider » attendent un test local que le propriétaire lance.
- **Hors périmètre** : configuration Caddy de l'hôte, `.env` et clés de production, pare-feu
  effectivement installé, réglages GitHub, comportement des fournisseurs tiers, image JVM déployée.
- **Antériorité** : les constats encore ouverts de l'audit de septembre
  ([`plans/archive/2026-09-security-audit.md`](../plans/archive/2026-09-security-audit.md) ;
  `SEC-12`, `SEC-13`, `SEC-14`, `SEC-39`, `SEC-40`) ont été exclus de la chasse comme connus.

## Synthèse

L'autorisation tient : chaque appel de service porte son annotation d'accès, le contexte d'équipe
est résolu sur le domaine de la requête, les identifiants enfants sont liés à l'équipe de l'URL, le
jeton d'accès est lié à son domaine, et les quatre invariants de `CLAUDE.md` sont respectés. Aucune
injection ni XSS n'a été trouvée. Ce qui reste : un défaut de cycle de vie des identités, des bornes
de ressources manquantes sur trois chemins d'analyse d'entrée (le backend est unique et partagé
par tous les tenants), et quelques écarts de liaison ou de quota.

## Constats confirmés

| ID | Ledger | Sévérité | Constat |
|---|---|---|---|
| C1 | `SEC-41` | Moyenne | Une demande en cours sur un attribut d'identité survit à la récupération du compte |
| C2 | `SEC-42` | Faible | Un envoi de fichier refusé laisse sa copie temporaire sur le disque du backend |
| C3 | `SEC-43` | Faible | Un ancien point d'API contourne la règle « personne ne rejoint une équipe sans un clic à soi » |

## Pistes à valider (sans sévérité)

| ID | Ledger | Piste |
|---|---|---|
| V1 | `SEC-44` | Une entrée pré-authentification n'est pas bornée en mémoire avant validation |
| V2 | `SEC-45` | Une bibliothèque d'analyse de fichiers de trace n'est pas protégée contre l'expansion d'entités |
| V3 | `SEC-46` | Un chemin d'envoi de trace échappe à la borne de taille posée par `SEC-6` |
| V4 | `SEC-47` | Un retour de connexion à un service tiers n'est pas lié au navigateur qui l'a lancé |
| V5 | `SEC-48` | Un appel facturé à un fournisseur n'a pas de quota par compte |
| V6 | `SEC-49` | Un quota d'envoi suit le motif compter-puis-insérer (même famille que `SEC-35` et `SEC-39`) |
| V7 | `SEC-50` | La désactivation d'un domaine ne s'applique pas à tous les chemins de résolution |

## Rejetés à la validation

Quatre candidats ont été écartés après relecture indépendante : deux comportements documentés comme
voulus (rétention annoncée par la politique de confidentialité, portée du blocage entre membres),
un effet sans impact de sécurité (file de publication des rapports d'erreur), et un chemin réfuté
par le framework (les noms de fichiers téléversés sont réduits à leur dernier composant).

## Durcissements (non-constats)

Une vingtaine de notes de durcissement sans frontière franchie démontrée, regroupées par thème dans
le rapport complet : confiance accordée aux en-têtes de proxy et accès direct au backend depuis le
réseau partagé, signature et sources du service d'images, montages du socket Docker, filtrage du
pare-feu limité à l'interface publique, restauration des sauvegardes, épinglage des entrées de
build, défense en profondeur côté client, gardes de concurrence et de cycle de vie mineures.

## Couverture

- 27 unités : 16 couvertes sans candidat, 11 avec candidat (dont certains rejetés ensuite) ;
  aucune bloquée ni différée.
- Critique post-vague 1 : une unité ajoutée (bornes des corps de requête), quatre lacunes écartées
  avec raison. Critique post-vague 2 et critique final distinct : aucune lacune.
- Compagnons exclus : IA/LLM (aucune surface), sûreté mémoire (runtimes managés), RPC/messagerie
  (ni broker ni RPC).
- Ce passage n'épuise pas la cible ; il ne dit rien des faits de déploiement hors périmètre.
