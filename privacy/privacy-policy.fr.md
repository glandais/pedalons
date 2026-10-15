# Politique de confidentialité

**Dernière mise à jour : 15 octobre 2026**

La présente politique de confidentialité décrit la manière dont Pedalons (« nous », « notre », « nos ») collecte, utilise et protège vos données personnelles lorsque vous utilisez notre plateforme (site web, application mobile, extensions pour appareils GPS).

Pour toute question relative à vos données personnelles, vous pouvez nous contacter à l'adresse : **privacy@pedalons.fr**

---

## 1. Données que nous collectons

### Données de compte

Lors de la création de votre compte, nous collectons :

- **Adresse e-mail** : pour l'authentification et les communications liées au service
- **Nom affiché** : choisi par vous, visible par les membres de votre équipe
- **Photo de profil** (facultatif). Dans l'application mobile, vous la choisissez avec le sélecteur du système : l'application ne reçoit que cette photo, et n'accède ni à l'appareil photo ni au reste de votre photothèque.
- **Préférences** : unités, thème, langue, fuseau horaire, réglages de notifications, et si d'autres membres peuvent vous écrire au sujet de vos petites annonces (oui par défaut, désactivable dans votre profil). Unités, thème, langue et fuseau ne sont enregistrés dans votre compte qu'une fois que vous les avez choisis ; en attendant, c'est le réglage de votre navigateur ou de votre appareil qui s'applique. Nous utilisons votre langue et votre fuseau pour rédiger et dater nos e-mails et notifications (à défaut : la langue de la page d'où vous avez fait la demande ou celle de l'expéditeur, et l'heure de Paris).
- **Acceptation des conditions d'utilisation** : la date à laquelle vous les avez acceptées à l'inscription, conservée comme preuve de cette acceptation
- **Données d'état du compte** : le fait que votre adresse e-mail ait été vérifiée et la date de cette vérification, les dates de création et de dernière modification du compte, le site (domaine) auquel votre compte est rattaché, et — pour les rares comptes qui administrent la plateforme — un indicateur de rôle d'administrateur.
- **Appartenances aux équipes** : vos équipes, votre rôle dans chacune (membre, organisateur, administrateur) et votre date d'arrivée. Qui voit la liste des membres : voir « Visibilité au sein de la plateforme » à la section 4.

### Équipes venues de Biketeam

Un administrateur d'équipe Biketeam peut transférer son équipe sur Pedalons. Notre serveur récupère alors le contenu de l'équipe directement auprès de Biketeam : pages (y compris les coordonnées de contact qu'elles affichent), lieux, itinéraires, sorties, voyages, publications et images. **Aucune donnée de membre n'est transférée** : ni comptes, ni appartenances, ni inscriptions, ni commentaires. Le compte Pedalons qui confirme le transfert devient administrateur de l'équipe et auteur de tout ce qui est importé ; les membres rejoignent ensuite l'équipe par le lien d'invitation habituel. Pour chaque demande de transfert, nous enregistrons le compte qui l'a confirmée, l'équipe Biketeam concernée, les dates et le résultat.

### Données d'authentification

Pour sécuriser l'accès à votre compte, nous traitons :

- **Mot de passe** (si vous en définissez un) : conservé uniquement sous forme de hachage irréversible, jamais en clair, et jamais envoyé par e-mail.
- **Clés d'accès (passkeys)** : la clé privée reste sur votre appareil et ne nous est jamais transmise. Nous conservons la clé publique et ses données techniques (dont le modèle d'authentificateur), le nom d'appareil que vous lui donnez, et ses dates de création et de dernière utilisation.
- **Sessions** : un jeton de connexion, haché sur nos serveurs, valable 30 jours, ou 90 jours pour un compteur GPS Karoo ou Garmin, qui n'est pas connecté en permanence. Où il est stocké sur votre appareil : voir « Données stockées localement sur votre appareil ».
- **Codes à usage unique (OTP)** : hachés, valides 5 minutes, invalidés après 5 tentatives erronées.
- **Liens envoyés par e-mail** (vérification d'inscription, changement d'adresse, réinitialisation du mot de passe) : jetons hachés, à usage unique, valides 24 heures (1 heure pour la réinitialisation). À l'inscription, votre e-mail, votre nom et la date d'acceptation des conditions sont gardés en attente : le compte n'est créé, avec le mot de passe que vous choisissez sur la page du lien, qu'une fois ce lien suivi, et la nouvelle adresse n'est appliquée qu'une fois le sien suivi.
- **Codes d'appairage d'appareils GPS** : codes temporaires (10 minutes) pour connecter un Karoo ou un Garmin.
- **Tentatives échouées** : chaque mot de passe erroné et chaque code d'appairage inconnu sont notés avec leur date, pour bloquer quelques minutes les essais répétés. Nous ne notons ni le mot de passe ni le code essayés, ni votre adresse e-mail en clair (seulement une empreinte irréversible), ni votre adresse IP ; pour un code d'appairage saisi une fois connecté, l'identifiant technique de votre compte.
- **Jeton de calendrier** : si vous vous abonnez au calendrier, un jeton aléatoire, intégré à l'adresse de votre flux, qui expire après 90 jours sans que votre application de calendrier l'ait consulté. Il est stocké en clair pour que votre application de calendrier puisse l'utiliser ; vous pouvez le régénérer à tout moment (voir « Abonnements calendrier » à la section 4).

### Données de session

À chaque connexion, nous enregistrons :

- **Adresse IP** et **agent utilisateur** (type de navigateur/appareil) : pour la sécurité du compte et la détection d'activité suspecte.
- **Date de dernière connexion** et **dernière utilisation de session**.
- **Journaux serveur** : date et heure, adresse IP, navigateur ou appareil, page demandée et code de réponse, parfois votre adresse e-mail et des identifiants techniques. Ils servent uniquement à la sécurité, à la détection d'abus et au dépannage — jamais au profilage ni à la publicité. Votre position et vos jetons de connexion n'y sont jamais écrits. Les requêtes de mesure d'audience du site n'y figurent pas (voir « Mesure d'audience du site » ci-dessous). Conservés 14 jours (voir section 6).

### Mesure d'audience du site

Sur le site web, nous comptons les pages vues, pour savoir quels sites et quelles pages de la plateforme sont utilisés, avec un outil de mesure d'audience que nous hébergeons nous-mêmes. L'application mobile et les extensions pour appareils GPS ne mesurent pas l'audience.

- **Ce qui est compté** : des pages vues, pas des visites ni des visiteurs. Pour chaque page vue : le site (son nom de domaine) ; le type de page (par exemple « fiche d'une sortie ») et si ce type de page est ouvert à tous ou réservé aux membres ; pour une page d'équipe, l'identifiant de l'équipe (celui de son adresse sur pedalons.fr), y compris pour une équipe privée, même sur le domaine propre d'un club ; pour la première page affichée seulement, le site d'où vous venez, réduit à son nom de domaine ; la famille et la version principale de votre navigateur, votre système, la catégorie de taille de votre écran (téléphone, tablette, ordinateur, grand écran ; jamais sa largeur exacte) et votre pays.
- **Ce qui ne l'est jamais** : l'adresse complète de la page, la sortie, le parcours, la publication ou la page consultés, les paramètres de l'adresse (liens d'invitation, de connexion…), le titre de la page, votre compte, vos équipes, ni le fait que vous soyez connecté ou non.
- **Sans cookie ni identifiant** : aucun cookie n'est déposé et aucun identifiant de visiteur ou de session n'est calculé : deux pages vues ne peuvent pas être reliées entre elles, ni sur un même site, ni d'un site de club à l'autre.
- **Votre adresse IP n'est pas conservée** : elle sert quelques secondes, en mémoire, à déduire votre pays sur nos serveurs, sans service tiers, et à écarter les robots et les abus ; elle n'est jamais écrite dans les statistiques.
- **Des compteurs, pas un enregistrement par page vue** : nous gardons, pour chaque page, des totaux par heure ou par jour, et chaque caractéristique (navigateur, système, écran, pays, site d'origine) est comptée à part. Seul le responsable du traitement consulte ces statistiques ; elles ne sont communiquées à personne, ni recoupées avec les autres données de la plateforme.
- **Durée** : 24 mois (voir section 6). Les requêtes reconnues comme venant de robots ne sont pas comptées.
- **Vous y opposer** : voir section 7.

### Données de localisation et GPS

Lorsque vous créez ou consultez des itinéraires :

- **Traces GPS** : coordonnées (latitude, longitude, altitude) issues des fichiers GPX que vous importez ou des itinéraires que vous dessinez avec notre planificateur (lorsque votre site ou votre équipe l'a activé). Les points que vous placez sont envoyés à notre moteur de calcul d'itinéraires, auto-hébergé.
- **Fichiers GPX que vous importez** : nous n'en gardons que la trace et les points d'intérêt (position et nom). Horodatages, mesures de capteurs (fréquence cardiaque, cadence, puissance, température) et métadonnées du fichier (auteur, adresse e-mail, appareil) sont supprimés avant tout stockage, et n'apparaissent donc dans aucun fichier que nous conservons, proposons au téléchargement ou envoyons à vos services GPS. Il en va de même d'un fichier GPX ou FIT joint à une publication comme simple pièce jointe : nous n'en gardons que la trace et ses points, et un fichier FIT est réécrit en parcours (sans tours, séances ni informations sur l'appareil).
- **Points d'intérêt** : noms et coordonnées des lieux que vous ajoutez.
- **Coordonnées de l'équipe** (facultatif) : point géographique représentant la localisation de votre équipe.
- **Lieux d'annonces et de rendez-vous** : l'adresse ou le point sur la carte que vous attachez à une petite annonce ou à un lieu de rendez-vous. Le point d'une annonce n'est montré aux autres membres que sous forme de zone approximative (voir « Petites annonces » ci-dessous). Pour un lieu saisi en texte, choisissez un point de repère proche plutôt que votre domicile si vous ne voulez pas que votre adresse soit visible par votre équipe.

Nous ne suivons pas vos déplacements en continu et ne conservons jamais d'historique de localisation. Deux fonctions lisent votre position actuelle :

- **Application Garmin Edge** : à l'affichage de son écran principal, elle envoie la position de l'appareil à notre serveur pour trier les itinéraires de votre équipe par distance. Elle nécessite la permission Garmin « Positionnement », accordée à l'installation.
- **Application iOS/Android** : uniquement si vous touchez « Autour de moi » dans la liste des itinéraires. Elle lit alors une fois votre position approximative, jamais en arrière-plan, et l'envoie avec les requêtes de liste tant que ce filtre est actif. Elle ne l'enregistre pas sur votre téléphone.

Ces coordonnées ne servent qu'à ce tri et à ce filtrage : elles ne sont stockées ni dans votre compte, ni dans notre base de données, ni dans nos journaux. Notre site web et notre extension Hammerhead Karoo n'accèdent pas à la localisation de votre appareil.

### Outil d'analyse GPX

Notre outil GPX permet d'analyser un fichier GPX, ou un itinéraire que vous dessinez, sans le rattacher à une équipe ; il nécessite un compte. Pour chaque fichier analysé, nous stockons le fichier (nettoyé comme décrit ci-dessus), ses fichiers dérivés (GPX simplifié, FIT, image de carte), ses statistiques, son nom et un lien vers votre compte, pour vous montrer votre historique dans « Mes fichiers ». Ces fichiers sont supprimés automatiquement après **30 jours**, ou plus tôt si vous les supprimez.

**Quiconque possède le lien peut voir le fichier.** Chaque fichier analysé reçoit une longue adresse aléatoire impossible à deviner. Quiconque la détient — y compris sans compte — peut voir la trace sur une carte, ses statistiques, et la télécharger en GPX ou FIT. Vous seul pouvez la modifier ou la supprimer. Ne partagez le lien qu'avec les personnes à qui vous voulez donner la trace, et supprimez le fichier si le lien a circulé plus largement que prévu.

### Contenu que vous créez

- **Sorties (rides)** : titre, description, date et heure, groupes de niveau, itinéraire associé, lieux de départ et d'arrivée, statut de publication (brouillon, publié, annulé) et date de publication programmée.
- **Voyages (trips)** : voyages sur plusieurs jours et leurs étapes (titre, description, dates, itinéraires, lieux de départ et d'arrivée).
- **Inscriptions (participations)** : la sortie ou le voyage, le groupe de niveau choisi, et la date de votre inscription. Votre nom affiché et votre photo de profil apparaissent alors dans la liste des participants, visible par toute personne pouvant voir la sortie ou le voyage — y compris des visiteurs non connectés lorsqu'il est public. Annuler votre inscription supprime l'enregistrement.
- **Publications (posts)** : titre et texte au format Markdown.
- **Commentaires** : texte associé à une publication, une sortie, un voyage ou un itinéraire.
- **Petites annonces** : titre, description, photos, type (vente, achat, location), prix, période de location, et le lieu que vous indiquez (texte libre et/ou point sur la carte). Les annonces ne sont visibles que par les membres connectés de votre équipe, jamais publiquement. Nous stockons exactement le point que vous placez, mais seuls vous, les administrateurs de votre équipe et les administrateurs de la plateforme le voient précisément ; les autres membres ne voient qu'une zone d'environ 1 km de côté. Le lieu saisi en texte est affiché tel que vous l'avez écrit. Les photos jointes ne portent pas de position GPS (voir « Photos et images »).
- **Messages au sujet d'une petite annonce** : « Contacter le vendeur » envoie votre message (2 000 caractères au maximum) par e-mail à l'auteur de l'annonce, avec votre nom affiché, le titre de l'annonce et un lien vers elle. Votre adresse e-mail est indiquée comme adresse de réponse : l'auteur la voit et peut vous répondre ; la sienne ne vous est jamais montrée. Nous ne conservons pas le texte du message : nous enregistrons seulement que vous avez écrit au sujet de cette annonce, et quand, pour limiter les abus (10 messages par heure au maximum).
- **Pages d'équipe** : la page « à propos » et les pages supplémentaires publiées par votre équipe.
- **Modèles de sortie** : les modèles réutilisables (titre, description, groupes de niveau) enregistrés par les organisateurs de votre équipe.
- **Lieux** : noms, adresses postales, liens et coordonnées des points de rendez-vous et d'arrivée que vous enregistrez pour votre équipe.
- **Itinéraires (routes)** : nom, distance, dénivelé positif et négatif, vallonnement, type de surface, traces et points GPS, et deux fichiers dérivés (GPX simplifié et FIT) pour l'envoi vers un appareil GPS.
- **Photos et images** : les fichiers que vous téléversez, avec leur nom d'origine, leur format et leurs dimensions. Avant d'enregistrer une image (photo, avatar, logo, pièce jointe), nous la réencodons : seule l'image elle-même est conservée, et toutes les métadonnées ajoutées par votre appareil ou votre logiciel disparaissent, dont la position GPS de la prise de vue, la date et le modèle d'appareil. Le réencodage peut réduire légèrement la qualité ; certains formats sont convertis en JPEG, et une image que nous ne savons pas réencoder est refusée. Les autres fichiers joints (PDF, documents…) sont conservés tels que vous les envoyez, avec leurs métadonnées. Les vidéos ne sont pas acceptées : elles portent le lieu et l'heure où elles ont été filmées, parfois tout le trajet enregistré par la caméra, et nous ne savons pas les en débarrasser de façon sûre.

Chaque élément ci-dessus est stocké avec l'identité du compte qui l'a créé et les dates de création et de dernière modification.

### Invitations dans une équipe

Un administrateur d'équipe peut inviter quelqu'un par son adresse e-mail, que cette personne ait un compte ou non. Nous stockons l'adresse invitée, l'équipe, le rôle proposé, l'administrateur qui invite, le statut de l'invitation et ses dates, et qui l'a acceptée ou révoquée ; le lien envoyé n'est stocké que haché. L'e-mail d'invitation indique le nom affiché de l'administrateur et le nom de l'équipe ; le nombre d'e-mails d'invitation qu'une même adresse peut recevoir par jour est limité. Personne ne rejoint une équipe sans avoir accepté, et créer un compte ne vaut pas acceptation. Les administrateurs de l'équipe voient les invitations envoyées, avec chaque adresse et son statut. Durées de validité et de conservation : voir section 6.

### Notifications

Lorsqu'il se passe quelque chose dans vos équipes — nouvelle sortie, voyage ou publication, changement ou annulation d'une sortie où vous êtes inscrit, rappel avant une sortie, inscription à une sortie que vous organisez, commentaire ou réponse, invitation, signalement à modérer — nous créons une notification pour vous. Elle conserve son type, ses dates de création et de lecture, et une copie de ce dont elle parle au moment de sa création : le nom du membre qui l'a déclenchée, le nom de l'équipe, le titre et la date de l'élément concerné, et, pour un commentaire, un extrait de 280 caractères au maximum.

Chaque notification apparaît dans votre boîte de réception, sur le site et dans l'application ; selon vos réglages, par type et par canal, elle peut aussi vous être envoyée par e-mail ou en notification push. Vous pouvez aussi recevoir vos e-mails non urgents en un récapitulatif quotidien, et mettre une équipe en sourdine (ses annonces ne vous parviennent plus, les notifications qui vous concernent personnellement continuent d'arriver). Nous stockons ces choix, ainsi que le canal, l'état et la date de chaque envoi par e-mail ou push.

Si vous autorisez les notifications push, nous stockons, pour chaque téléphone ou navigateur : un jeton push émis par Google Firebase Cloud Messaging, qui identifie l'installation ou le navigateur et non votre personne ; la plateforme ; le nom ou le modèle de l'appareil (sur le site, le navigateur et le système) ; la version de l'application ; et les dates d'enregistrement et de dernière activité. L'autorisation n'est demandée que lorsque vous le choisissez, jamais au lancement, et vous pouvez la retirer à tout moment dans les réglages de votre appareil, de votre navigateur ou de vos notifications.

Les notifications push affichent leur titre et leur texte sur votre appareil, et, selon vos réglages, sur l'écran verrouillé ; pour un commentaire, ce texte contient le nom de son auteur et un extrait. Si vous ne voulez pas qu'il soit visible, modifiez les réglages de l'écran verrouillé ou coupez le push pour ces types.

**Canaux de discussion d'équipe** : les administrateurs d'une équipe peuvent la relier à un canal de discussion (Slack, Discord, Mattermost) ou à toute adresse HTTPS de leur choix. Les annonces de l'équipe (sortie, voyage ou publication publié, sortie ou voyage annulé ou modifié) y sont alors publiées, avec le nom du membre qui les a déclenchées, le nom de l'équipe, le titre et la date de l'élément, ce qui a changé, et un lien. Toute personne ayant accès au canal peut les lire, et le service les conserve selon ses propres règles. Nous enregistrons si chaque message a été remis, et quand.

### Signalements et blocages

Pour permettre la modération (voir la section 6 des conditions d'utilisation), nous enregistrons :

- **Vos signalements** : qui a signalé (vous), ce qui est signalé (le contenu ou le membre, et l'équipe concernée), l'auteur du contenu ou le membre visé, le motif choisi, le message facultatif que vous ajoutez, une **copie du texte signalé** (1 000 caractères au plus) et la décision prise (contenu supprimé ou signalement rejeté, par qui et quand). La copie permet de vérifier la décision même si le contenu a été modifié ou supprimé depuis.
- **Vos blocages** : qui a bloqué qui, et depuis quand.

Qui y a accès :

- **Votre identité de signaleur** n'est visible **que par l'équipe Pedalons**. Elle n'est jamais montrée aux organisateurs de l'équipe, ni à l'auteur du contenu, ni au membre signalé.
- **Les organisateurs et administrateurs de l'équipe** voient le contenu signalé, son auteur, les motifs et les messages ajoutés, mais pas qui a signalé. Un message peut vous identifier par ce qu'il dit : écrivez-le en sachant qu'ils le liront. Un organisateur visé par un signalement ne le voit pas.
- **Vos blocages** ne sont visibles que par vous. La personne bloquée n'en est pas informée, et rien dans le service ne le lui révèle.

Un contenu signalé par au moins trois membres est masqué aux membres en attendant la décision d'un modérateur. La notification qui prévient les modérateurs d'un signalement ne contient que le nom de l'équipe, jamais le contenu signalé ni l'identité du signaleur.

**Filtre de publication** : au moment où vous publiez, votre texte est comparé à une courte liste de termes injurieux ou haineux. S'il en contient un, la publication est refusée et le texte n'est pas enregistré ; ce refus n'a aucune autre conséquence pour votre compte.

### Signalements de problèmes et rapports d'erreur

Pour corriger les bugs, nous recevons :

- **Vos signalements de problème ou suggestions** (« Signaler un problème », dans le site ou l'application) : le texte que vous écrivez, la plateforme et la version de l'application, et, si vous laissez cochée la case « Joindre les informations techniques », la page ou l'écran affiché, l'équipe que vous consultez, le système et le modèle de l'appareil ou le navigateur, la langue, le fuseau horaire, et un journal de vos dernières actions dans l'application (pages visitées, requêtes en échec, erreurs). Le formulaire vous montre exactement ce qui sera envoyé.
- **Des rapports d'erreur automatiques** (connecté uniquement) : quand l'application rencontre une erreur inattendue, elle envoie la description technique de l'erreur, les mêmes informations techniques et le journal de vos dernières actions. Vous pouvez désactiver cet envoi dans **Profil → Confidentialité**.

Le journal ne contient ni mot de passe, ni contenu de formulaire, ni paramètre d'adresse web ; les jetons de connexion et les adresses e-mail qui s'y trouveraient sont masqués par nos serveurs avant tout enregistrement. Ces informations sont transmises à l'équipe Pedalons sous forme de tickets dans un dépôt **privé** GitHub (voir section 4), où vous êtes désigné par un identifiant technique, jamais par votre nom ni votre adresse e-mail.

### Inscriptions aux programmes bêta

Sur la page Applications, toute personne, avec ou sans compte, peut laisser une adresse e-mail pour être prévenue de l'ouverture d'une version de test de notre application mobile ou Garmin. Nous stockons l'adresse, le site sur lequel elle a été saisie et la date ; elle n'est rattachée à aucun compte et aucun e-mail de confirmation n'est envoyé. Nous ne l'utilisons que pour vous contacter au sujet de la bêta. Si nous vous invitons, nous la saisissons à la main dans le service de test du magasin concerné (Apple TestFlight ou Google Play Console), qui la traite selon sa propre politique de confidentialité. Connect IQ, le magasin de Garmin, n'ayant pas de service de test, votre adresse n'y est pas saisie. Pour être retiré de la liste, écrivez à privacy@pedalons.fr.

### Données de connexion à des services GPS tiers

Si vous connectez un service GPS externe (Hammerhead, Garmin, Wahoo) :

- **Jetons d'accès OAuth** : chiffrés avant stockage. Nous ne stockons jamais vos identifiants (nom d'utilisateur/mot de passe) de ces services.
- **Identifiant utilisateur externe** : lorsque le service en renvoie un à la connexion (c'est le cas de Hammerhead, pas de Wahoo), pour le relier à votre compte Pedalons.
- **Ce que nous envoyons** : uniquement lorsque vous choisissez d'envoyer un itinéraire, sa trace et son nom sur votre compte du service. Wahoo reçoit aussi le point de départ, la distance, les dénivelés et une empreinte du fichier (pour éviter les doublons). La connexion à Wahoo demande l'autorisation de lire votre profil (Wahoo l'exige) et de créer des itinéraires ; nous ne lisons ni votre profil ni vos activités Wahoo.

### Données stockées localement sur votre appareil

**Dans votre navigateur web** : les cookies et le stockage local utilisés par le site sont listés à la section 8. S'y ajoute le journal de vos dernières actions (200 entrées au plus), gardé en mémoire tant que la page est ouverte, pour un éventuel signalement de problème ; il ne quitte votre appareil que dans les cas décrits dans « Signalements de problèmes et rapports d'erreur ».

**Dans l'application mobile :**

- **Votre jeton de session** : stocké dans le stockage sécurisé de votre appareil, et supprimé à la déconnexion. L'application n'utilise pas de cookies.
- **Préférences d'affichage** : une copie de votre thème, de votre langue et de vos unités (la valeur de votre compte prévaut), ainsi que vos réglages de carte et de présentation de la liste des itinéraires.
- **Caches d'images et de carte** : les photos et avatars affichés (y compris les photos privées de vos équipes) et les images de carte, gardés dans le stockage de l'application pour ne pas être retéléchargés, et effacés à la désinstallation ou à l'effacement de ses données.
- **Fichiers que vous téléchargez** : un itinéraire ou une pièce jointe que vous téléchargez est enregistré dans le dossier temporaire de l'application, puis transmis au menu de partage ; il y reste jusqu'à ce que le système le vide ou que vous désinstalliez l'application.
- **Jeton push** : le composant Firebase Cloud Messaging conserve sur l'appareil un identifiant d'installation et un jeton push. Ils restent après la déconnexion, car ils identifient l'installation et non votre personne, mais notre serveur cesse alors de les utiliser pour votre compte.
- **Journal des dernières actions et rapports d'erreur** : vos dernières actions (200 entrées au plus), les rapports d'erreur pas encore envoyés et votre réglage des rapports automatiques. Rien de cela ne quitte votre téléphone, sauf dans les cas décrits dans « Signalements de problèmes et rapports d'erreur ».
- **Pas de sauvegarde** : sur Android, les données de l'application sont exclues de la sauvegarde dans le cloud et du transfert vers un nouvel appareil.

**Sur votre appareil GPS (Karoo, Garmin)** : l'extension Pedalons ne stocke que vos jetons de session et leur expiration (plus, pendant l'appairage, le code temporaire), dans son stockage privé, sans chiffrement supplémentaire : une personne ayant accès à l'appareil déverrouillé ou à une de ses sauvegardes pourrait les lire. Aucun contenu de sortie ou d'itinéraire n'y est conservé. Se déconnecter sur l'appareil n'efface les jetons que de l'appareil : la session reste valide sur nos serveurs jusqu'à son expiration (90 jours). Pour y mettre fin immédiatement, par exemple si vous perdez l'appareil, utilisez « Déconnecter tous les appareils » dans votre profil, sur le site ou dans l'application mobile.

---

## 2. Comment nous collectons vos données

- **Directement auprès de vous** : lorsque vous créez un compte, remplissez votre profil, importez des fichiers GPX, créez du contenu ou connectez un service GPS.
- **Automatiquement** : adresse IP et agent utilisateur lors de vos connexions ; cookie de session pour maintenir votre authentification ; journaux serveur décrits à la section 1 ; sur le site, mesure d'audience décrite à la section 1 (« Mesure d'audience du site ») ; et, sauf si vous les désactivez, rapports d'erreur automatiques (voir « Signalements de problèmes et rapports d'erreur »).
- **Depuis la plateforme à laquelle Pedalons succède** : un administrateur d'équipe Biketeam peut faire transférer le contenu de son équipe depuis le serveur de Biketeam, comme décrit à la section 1 (« Équipes venues de Biketeam »).
- **Auprès d'autres membres** : un administrateur d'équipe qui vous invite nous communique votre adresse e-mail (voir « Invitations dans une équipe ») ; un membre qui vous signale, ou signale votre contenu, nous communique le motif, son message et une copie du texte signalé (voir « Signalements et blocages »).
- **Depuis le formulaire d'inscription à la bêta** (voir « Inscriptions aux programmes bêta »).

En dehors de ces cas, **nous ne collectons aucune donnée auprès de tiers** : nous n'achetons ni ne louons jamais de données, et nous ne collectons rien depuis les réseaux sociaux.

---

## 3. Pourquoi nous utilisons vos données

Pour chaque finalité, la base légale (RGPD) sur laquelle elle repose :

- **Fournir le service (compte, authentification, navigation)** : Exécution du contrat
- **Afficher les itinéraires, sorties, voyages et autres contenus de votre équipe** : Exécution du contrat
- **Envoyer des e-mails de vérification et codes de connexion** : Exécution du contrat
- **Afficher les notifications concernant vos équipes dans votre boîte de réception, sur le site et dans l'application** : Exécution du contrat
- **Vous envoyer des notifications par e-mail, selon vos réglages de notifications** : Exécution du contrat (réglable à tout moment, type par type)
- **Vous notifier sur votre téléphone ou dans votre navigateur (notifications push)** : Consentement (autorisation donnée sur le téléphone ou dans le navigateur) ; vous pouvez le retirer dans les réglages de votre appareil ou de votre navigateur, ou couper le push type par type dans vos réglages de notifications
- **Publier les annonces de l'équipe dans le canal de discussion relié par ses administrateurs** : Intérêt légitime (l'intérêt de l'équipe à informer ses membres)
- **Relayer les messages au sujet des petites annonces** : Exécution du contrat
- **Invitations dans une équipe** : Intérêt légitime (l'intérêt de l'équipe à inviter ses membres)
- **Modérer les contenus : traiter les signalements, appliquer vos blocages, filtrer les termes injurieux à la publication** : Exécution du contrat (conditions d'utilisation) et intérêt légitime (protéger les membres)
- **Conserver la preuve de votre acceptation des conditions d'utilisation** : Intérêt légitime
- **Sécuriser votre compte (détection de sessions suspectes)** : Intérêt légitime
- **Synchroniser vos itinéraires avec des appareils GPS connectés** : Consentement (connexion volontaire)
- **Afficher les cartes (fonds de carte téléchargés par votre appareil auprès du fournisseur choisi)** : Intérêt légitime
- **Position approximative (« Autour de moi », facultatif, application mobile)** : Consentement, donné via la demande d'autorisation du système d'exploitation ; vous pouvez le retirer dans les réglages de votre appareil
- **Fournir votre flux calendrier personnel à l'application de calendrier de votre choix** : Consentement (abonnement volontaire)
- **Vous prévenir de l'ouverture d'une bêta de nos applications** : Consentement (inscription volontaire)
- **Traiter vos signalements de problème et corriger les erreurs de l'application** : Intérêt légitime (fiabilité du service ; rapports automatiques désactivables)
- **Mesurer l'audience du site, de façon anonyme et agrégée** : Intérêt légitime (exempté de consentement) ; opposition possible, voir section 7
- **Assurer la continuité du service pour les équipes venues de la plateforme précédente** : Intérêt légitime
- **Exploiter et assister la plateforme** : Intérêt légitime

Nous n'utilisons **jamais** vos données pour :
- De la publicité ciblée
- La revente, la location ou le partage à des fins commerciales
- Du profilage automatisé ou de la prise de décision automatisée
- Un suivi de votre navigation d'un site à l'autre, ou des statistiques rattachées à votre compte

---

## 4. Partage de vos données

### Visibilité au sein de la plateforme

- **Contenu d'équipe** (« équipe ») : visible par les membres de cette équipe. Les brouillons et éléments non publiés ne sont visibles que par les organisateurs et administrateurs de l'équipe.
- **Contenu non répertorié** (« non répertorié ») : absent des listes publiques, des résultats de recherche et des annuaires, mais lisible par quiconque possède le lien, y compris sans compte. Traitez un lien non répertorié comme semi-public : nous ne pouvons pas empêcher qu'il soit transféré.
- **Contenu public** (« public ») : un contenu « public » dans une équipe publique est accessible à quiconque sur internet, sans compte et sans connexion. Ces pages peuvent être indexées par les moteurs de recherche et affichées en aperçu de lien dans les réseaux sociaux et messageries. Cela inclut les listes de participants des sorties et voyages publics (nom affiché et photo de profil de chaque inscrit).
- **Liste des membres d'une équipe** : les administrateurs la voient en entier (nom affiché, photo, rôle, date d'arrivée) et peuvent y chercher par adresse e-mail ; les organisateurs voient les noms et les photos, pour choisir un meneur de groupe ; les autres membres ne la voient que si les administrateurs ouvrent le trombinoscope (fermé par défaut). Les adresses e-mail ne sont jamais montrées aux autres membres.
- **Votre nom affiché et votre photo de profil** sont visibles par les membres de vos équipes, et par quiconque sur internet partout où ils apparaissent sur du contenu public (liste des participants, auteur d'une publication). Le fichier de votre photo est servi à une adresse qui n'exige pas de connexion. Choisissez un nom et une photo que vous acceptez de montrer publiquement ; vous pouvez retirer votre photo à tout moment.
- **Fichiers de l'outil GPX** : accessibles à quiconque possède le lien, sans compte (voir « Outil d'analyse GPX » à la section 1).
- **Aperçus de lien** : lorsqu'un lien vers un itinéraire, une sortie ou un fichier GPX analysé est collé dans une messagerie, un réseau social ou un outil de discussion, cette plateforme récupère l'image d'aperçu que nous publions — pour une trace, une carte de la trace avec son nom, sa distance et son dénivelé — même si personne ne clique. Ne partagez pas le lien si la trace part de votre domicile.
- **Abonnements calendrier (ICS)** : votre lien calendrier personnel fonctionne sans connexion : quiconque l'obtient peut lire les sorties et voyages que vous voyez, y compris ceux réservés à l'équipe. Un service de calendrier hébergé (Google Calendar, Apple Calendar, Outlook…) récupère le flux sur ses propres serveurs et en stocke le contenu (titres, dates et liens des sorties et étapes, noms de vos équipes) ; nous n'avons aucun contrôle sur ce qu'il en fait. Traitez l'adresse du flux comme un mot de passe : tant qu'une application de calendrier la consulte, elle reste valide ; elle expire après 90 jours sans consultation, et la régénérer invalide immédiatement l'ancienne.
- **Canaux de discussion d'équipe** : si les administrateurs de votre équipe en ont relié un (voir « Notifications » à la section 1), les annonces de l'équipe, avec le nom du membre qui les a déclenchées, y sont publiées. C'est l'équipe qui choisit ce service, qui les reçoit en tant que destinataire agissant selon ses propres conditions, et non en tant que prestataire de notre part.
- **Signalements** : voir « Signalements et blocages » à la section 1.
- **Administration de la plateforme** : un très petit nombre de comptes administrateurs de la plateforme (actuellement le responsable du traitement lui-même) peut techniquement accéder à tous les comptes et à tous les contenus de tous les sites, y compris les contenus d'équipe et les brouillons, et lister les adresses e-mail, les dates de dernière connexion et les inscriptions aux programmes bêta. Cet accès sert uniquement à exploiter, assister et modérer le service, et uniquement lorsque c'est nécessaire.

### Sous-traitants techniques

Nous faisons appel à des services techniques pour le fonctionnement de la plateforme :

- **Scaleway (Scaleway SAS, France)**
  - *Rôle* : Hébergement de l'application, de la base de données et des fichiers ; envoi des e-mails (relais SMTP Transactional Email)
  - *Données concernées* : Pour l'hébergement, toutes les données. Pour les e-mails : l'adresse et le nom du destinataire, et le contenu complet de chaque message — liens et codes de connexion, invitations (valides 14 jours), messages au sujet des petites annonces (avec l'adresse de l'expéditeur comme adresse de réponse), notifications et récapitulatifs (qui contiennent des liens durables vers les contenus concernés), et lien vers votre export de données. Scaleway est contractuellement tenu de n'utiliser ces données que pour remettre l'e-mail pour notre compte.
- **GitHub (GitHub, Inc., États-Unis)**
  - *Rôle* : Suivi des signalements de problème et des rapports d'erreur, dans un dépôt privé accessible à la seule équipe Pedalons
  - *Données concernées* : Texte du signalement, informations techniques, journal des dernières actions, équipe consultée, identifiant technique du compte et domaine
- **Google Firebase Cloud Messaging (Google Ireland Limited, Irlande)**
  - *Rôle* : Acheminement des notifications push vers l'application mobile, via Apple Push Notification service pour les iPhone, et vers votre navigateur
  - *Données concernées* : Le jeton push de votre téléphone ou de votre navigateur, l'adresse IP de votre appareil lorsque l'application ou le navigateur contacte Firebase, et le contenu de chaque notification : titre et texte (qui peuvent contenir un nom d'équipe, le titre et la date d'une sortie, d'un voyage ou d'une publication, le nom d'un membre et un extrait de commentaire), ainsi que des données techniques qui permettent d'ouvrir la bonne page (type et identifiant de la notification, identifiants de l'équipe et de la page)
- **Apple Push Notification service (Apple Distribution International Ltd, Irlande)**
  - *Rôle* : Acheminement des notifications push vers les iPhone, relayées par Firebase Cloud Messaging
  - *Données concernées* : Le même contenu de notification et le jeton push Apple de votre appareil
- **Hammerhead, Garmin, Wahoo (États-Unis)**
  - *Rôle* : Envoi de vos itinéraires vers votre appareil GPS, uniquement si vous connectez le service
  - *Données concernées* : Jetons OAuth, et les itinéraires que vous choisissez d'envoyer (trace, nom ; pour Wahoo, aussi le point de départ, la distance et les dénivelés)

L'outil de mesure d'audience du site est hébergé par nos soins chez Scaleway, comme le reste de la plateforme : aucun autre prestataire ne reçoit ces statistiques.

### Services push des navigateurs

Sur le site, une notification push est remise à votre navigateur par le service push de son éditeur (Google pour Chrome, Mozilla pour Firefox, Apple pour Safari, Microsoft pour Edge), choisi par votre navigateur et non par nous. Ce service reçoit le message chiffré, qu'il ne peut pas lire, l'adresse d'abonnement de votre navigateur et l'adresse IP de votre appareil. Il agit en responsable de traitement indépendant, selon la politique de l'éditeur de votre navigateur, et n'intervient que si vous activez les notifications sur le site.

### Affichage des cartes et recherche d'adresses

Les images de carte sont téléchargées par votre appareil directement auprès du fournisseur du fond de carte que vous avez choisi. Ce fournisseur reçoit votre adresse IP, la version de votre navigateur ou de votre application, et la zone de carte affichée (ce qui révèle approximativement la zone de l'itinéraire que vous regardez) ; nous ne lui transmettons rien vous concernant. Ces fournisseurs agissent en responsables de traitement indépendants, selon leurs propres politiques.

La recherche de lieux (lieu de l'équipe, lieux de rendez-vous, petites annonces ; une fois connecté) passe au contraire par notre serveur, qui interroge Nominatim en votre nom : Nominatim ne reçoit que le texte saisi et votre langue d'affichage, jamais votre adresse IP ni votre identité. Les résultats sont gardés en mémoire sur notre serveur 24 heures au maximum.

Les prévisions météo des sorties sont demandées à Open-Meteo par notre serveur, en tâche de fond et jamais pendant votre visite : Open-Meteo ne reçoit que le centre d'une maille d'environ 5 km autour du départ et des points du parcours (jamais le lieu de rendez-vous exact), parfois une altitude arrondie à 100 m, et l'adresse IP de notre serveur — jamais votre identité, votre compte ni votre adresse IP.

- **VersaTiles (tiles.versatiles.org)**
  - *Rôle* : Fond de carte vectoriel (style par défaut), polices et sprites de carte
  - *Données concernées* : Adresse IP, zone de carte affichée
- **Mapterhorn (tiles.mapterhorn.com, servi par Cloudflare, États-Unis)**
  - *Rôle* : Tuiles d'altitude et d'ombrage (relief 3D) ; également utilisé par notre serveur pour corriger l'altitude des traces importées
  - *Données concernées* : Votre navigateur ou application, uniquement si vous activez l'ombrage du relief ou le relief 3D (tous deux désactivés par défaut) : adresse IP, zone de carte affichée. Côté serveur : coordonnées de tuiles grossières (~10 km de côté) couvertes par une trace et adresse IP de notre serveur — jamais votre identité, votre compte ni votre adresse IP
- **IGN / Géoplateforme (data.geopf.fr, France)**
  - *Rôle* : Fonds IGN, satellite et SCAN 25 ; également utilisé par notre serveur (LiDAR HD) pour corriger l'altitude des traces importées en France
  - *Données concernées* : Votre navigateur ou application : adresse IP, zone de carte affichée. Côté serveur : coordonnées des tuiles (~1 km de côté) couvertes par une trace et adresse IP de notre serveur — jamais votre identité, votre compte ni votre adresse IP
- **OpenStreetMap Foundation (tile.openstreetmap.org, Royaume-Uni)**
  - *Rôle* : Fond OpenStreetMap
  - *Données concernées* : Adresse IP, zone de carte affichée
- **OpenStreetMap France (tile-cyclosm.openstreetmap.fr)**
  - *Rôle* : Fond CyclOSM
  - *Données concernées* : Adresse IP, zone de carte affichée
- **OpenStreetMap Nominatim (nominatim.openstreetmap.org)**
  - *Rôle* : Recherche de lieux, interrogée par notre serveur
  - *Données concernées* : Le texte que vous saisissez et votre langue d'affichage ; jamais votre adresse IP ni votre identité
- **Open-Meteo (api.open-meteo.com)**
  - *Rôle* : Prévisions météo des sorties, interrogé par notre serveur
  - *Données concernées* : Coordonnées du centre de mailles d'environ 5 km, altitude arrondie, adresse IP de notre serveur ; jamais votre adresse IP ni votre identité
- **Esri (server.arcgisonline.com, États-Unis)**
  - *Rôle* : Fond « Satellite (ESRI) »
  - *Données concernées* : Adresse IP, zone de carte affichée

Le fond de carte « Michelin » est servi par nos soins (tiles.pedalons.fr) : le choisir n'implique aucun tiers. Le traitement des images, le rendu des cartes et le calcul d'itinéraires sont également auto-hébergés, et les polices du site et de l'application y sont intégrées (sauf celles des étiquettes de carte, fournies par VersaTiles).

### Autorités

Nous pouvons être amenés à communiquer vos données si la loi l'exige (demande judiciaire, obligation légale).

---

## 5. Transferts internationaux de données

Nos serveurs sont hébergés par **Scaleway** (Scaleway SAS, Vitry-sur-Seine, France) et sont situés en France. Les données que nous stockons restent dans l'Union européenne.

Certains traitements que vous pouvez déclencher impliquent des serveurs situés hors de l'Union européenne :

- **Services GPS tiers** (Hammerhead, Garmin, Wahoo, États-Unis) : uniquement si vous en connectez un, et seulement pour les itinéraires que vous leur envoyez. Ce transfert est nécessaire au service que vous demandez, l'envoi de l'itinéraire sur votre compte (article 49, paragraphe 1, point b, du RGPD) ; Garmin adhère en outre au cadre de protection des données UE–États-Unis (Data Privacy Framework).
- **Fonds de carte et relief** : votre appareil envoie votre adresse IP et la zone affichée au fournisseur du fond que vous choisissez (voir section 4). Le fond « Satellite (ESRI) » vient d'Esri (États-Unis), qui adhère au Data Privacy Framework. Les tuiles de relief de Mapterhorn, demandées seulement si vous activez l'ombrage ou le relief 3D, sont servies par Cloudflare (États-Unis), qui y adhère aussi. Le fond OpenStreetMap est servi depuis le Royaume-Uni, qui bénéficie d'une décision d'adéquation de la Commission européenne.
- **Composant de messagerie Firebase de Google** : l'application mobile l'intègre, et il contacte les serveurs de Google au démarrage de l'application, avant même que vous vous connectiez ou autorisiez les notifications, ce qui révèle l'adresse IP de votre appareil et crée un identifiant d'installation Firebase. L'application et le site n'intègrent que cette partie messagerie de Firebase : aucun composant d'analyse, de publicité ou de suivi de Firebase. Sur le site, ce composant n'est chargé qu'une fois les notifications activées.
- **Notifications push** : Google (Firebase Cloud Messaging) peut traiter leur titre, leur texte et le jeton push de votre appareil aux États-Unis ; ce transfert est encadré par les clauses contractuelles types de la Commission européenne et par l'adhésion de Google LLC au Data Privacy Framework. Sur iPhone, elles sont remises par Apple (Apple Distribution International, Irlande), dont les transferts vers les États-Unis sont encadrés par les clauses contractuelles types ; dans un navigateur, par le service push de son éditeur, qui ne reçoit que le message chiffré (voir section 4). Cela n'a lieu que tant que vous autorisez les notifications.
- **Signalements de problème et rapports d'erreur** : transmis à GitHub (États-Unis), sans votre nom ni votre adresse e-mail ; ce transfert est encadré par les clauses contractuelles types de la Commission européenne et par l'adhésion de GitHub, Inc. au Data Privacy Framework.
- **Canaux de discussion d'équipe** : le service choisi par les administrateurs de l'équipe (par exemple Slack ou Discord, exploités depuis les États-Unis) reçoit les annonces de l'équipe. Ce transfert a lieu sur instruction des administrateurs, qui choisissent le service : Slack et Discord adhèrent au Data Privacy Framework ; tout autre service relève de ses propres conditions.
- **Programmes bêta** : si nous vous invitons, votre adresse e-mail est saisie dans Apple TestFlight ou Google Play Console ; Apple et Google encadrent leurs transferts vers les États-Unis par les clauses contractuelles types.

---

## 6. Conservation des données

- **Données de compte (adresse e-mail, nom affiché, photo de profil, préférences, hachage du mot de passe)** : Tant que votre compte existe ; effacées dès que vous le supprimez (voir section 7)
- **Date d'acceptation des conditions d'utilisation** : Tant que votre compte existe
- **Sessions de connexion (jeton haché, adresse IP, navigateur ou appareil, dates de création et de dernière utilisation)** : 30 jours à compter de la connexion, sans prolongation à l'usage
- **Sessions d'un appareil GPS appairé (Karoo, Garmin)** : 90 jours à compter de l'appairage, sans prolongation à l'usage. « Déconnecter tous les appareils » la révoque, de même qu'une réinitialisation du mot de passe ; se déconnecter sur l'appareil lui-même ne la révoque pas
- **Codes de connexion temporaires (OTP)** : 5 minutes, ou jusqu'à 5 tentatives erronées
- **Inscription en attente (lien de vérification, nom affiché, hachage du mot de passe, date d'acceptation des conditions)** : 24 heures
- **Lien de réinitialisation de mot de passe** : 1 heure
- **Lien de vérification de changement d'e-mail** : 24 heures
- **Codes d'appairage d'appareils GPS** : 10 minutes au plus
- **Challenges de clés d'accès** : 5 minutes au plus
- **Tentatives de connexion et d'appairage échouées** : 24 heures
- **Jeton de calendrier (adresse secrète de votre flux .ics)** : Jusqu'à régénération, ou effacé après 90 jours sans consultation du flux
- **Équipes et contenus (sorties, posts, itinéraires, voyages, pages)** : La suppression d'un élément le masque aux membres et aux visiteurs, mais il reste dans notre base : les administrateurs de l'équipe le voient toujours dans leurs listes, marqué « Supprimé », et peuvent le restaurer. L'enregistrement est conservé jusqu'à demande d'effacement définitif
- **Commentaires** : Effacés dès que vous ou votre équipe les supprimez, avec les réponses qu'ils ont reçues ; l'extrait copié dans une notification subsiste jusqu'à l'expiration de celle-ci (90 jours)
- **Photos, fichiers téléversés, points d'intérêt, lieux, inscriptions, clés d'accès, connexions aux services GPS** : Effacés immédiatement et définitivement lorsque vous ou votre équipe les supprimez
- **Fichiers attachés au contenu (images, GPX, FIT, images de carte générées)** : Tant que l'enregistrement associé existe en base. Les fichiers téléversés mais jamais attachés à un contenu sont effacés un jour après l'envoi
- **Fichiers de l'outil d'analyse GPX** : 30 jours après création (supprimables par vous à tout moment)
- **Notifications (boîte de réception, statut de lecture, copie du contenu, trace des envois par e-mail, push et canal de discussion)** : 90 jours. Les messages déjà publiés dans le canal de discussion d'une équipe y restent, selon les règles de ce service
- **Réglages de notifications (réglages par type, récapitulatif quotidien, équipes en sourdine)** : Tant que votre compte existe
- **Enregistrement push d'un téléphone ou d'un navigateur (jeton push, plateforme, appareil ou navigateur, version de l'application, dates)** : Jusqu'à ce que vous vous déconnectiez sur cet appareil ou y coupiez les notifications, qu'un autre compte s'y connecte, que Firebase Cloud Messaging refuse le jeton (par exemple après désinstallation de l'application), ou que vous supprimiez votre compte. « Déconnecter tous les appareils » ne supprime que l'enregistrement de l'appareil depuis lequel vous l'utilisez : vos autres appareils continuent de recevoir des notifications push jusqu'à ce que vous vous y déconnectiez
- **Réglages du canal de discussion d'une équipe (adresse du canal, langue, état du dernier envoi)** : Jusqu'à ce que les administrateurs de l'équipe retirent le canal
- **Invitations dans une équipe (adresse e-mail invitée, rôle proposé, auteur de l'invitation, statut et dates)** : Valables 14 jours ; l'enregistrement, y compris l'adresse d'une personne qui n'a jamais créé de compte, est conservé 1 an après l'acceptation, la révocation ou l'expiration, pour que l'équipe sache qui a invité qui
- **Trace des messages envoyés au sujet d'une petite annonce (expéditeur, annonce, date ; le message lui-même n'est pas stocké)** : Jusqu'à l'effacement définitif de l'annonce
- **Blocages** : Jusqu'à ce que vous débloquiez la personne, ou jusqu'à la suppression du compte de l'un de vous deux
- **Signalements, copie du texte signalé et décision** : Tant que le compte de la personne visée existe, pour garder la trace des décisions de modération ; à la suppression du compte du signaleur, conservés sans lien avec lui (voir section 7)
- **Signalements de problème et suggestions** : 1 an sur nos serveurs, ou jusqu'à la suppression de votre compte ; le ticket GitHub correspondant est conservé tant qu'il est utile au suivi du bug
- **Rapports d'erreur automatiques** : 90 jours sur nos serveurs, ou jusqu'à la suppression de votre compte ; le ticket GitHub correspondant est conservé tant qu'il est utile
- **Demandes de transfert d'équipe depuis Biketeam (compte qui l'a confirmée, équipe Biketeam, dates, résultat)** : 1 an après la fin du transfert ou l'expiration de la demande ; après la suppression du compte, la demande n'est plus rattachée à rien qui identifie la personne
- **Inscriptions aux programmes bêta (adresse e-mail, site, date)** : 1 an après l'inscription ; écrivez à privacy@pedalons.fr pour être retiré de la liste plus tôt
- **Archive d'export de vos données (ZIP)** : 7 jours
- **Historique des demandes d'export (date de la demande, statut, taille de l'archive, date d'expiration)** : 90 jours
- **Journaux d'accès du serveur (date et heure, adresse IP, navigateur ou appareil, adresse demandée sans les coordonnées ni les jetons, code de réponse ; hors requêtes de mesure d'audience, qui n'y sont pas écrites)** : 14 jours
- **Statistiques d'audience du site (compteurs par page, sans adresse IP, ni identifiant, ni session ; statistiques agrégées comprises)** : 24 mois. Pour les requêtes reconnues comme venant de robots, qui ne sont pas comptées, la page demandée et l'agent utilisateur : 30 jours
- **Données après suppression du compte** : Effacement immédiat (voir section 7)

Les données expirées sont effacées de la base par un nettoyage exécuté chaque nuit : elles peuvent donc rester stockées jusqu'à 24 heures au-delà de la durée indiquée.

**Sauvegardes.** Chaque nuit, nous réalisons une copie complète de la base de données et des fichiers téléversés, stockée sur un serveur séparé situé en France ; les 30 dernières copies sont conservées, les plus anciennes supprimées automatiquement. Une donnée supprimée ou effacée, y compris à la suppression de votre compte, peut donc subsister dans nos sauvegardes pendant 30 jours au maximum. Les sauvegardes sont chiffrées (voir section 9) et ne servent qu'à restaurer le service après un incident. Les statistiques d'audience du site ne sont pas sauvegardées.

---

## 7. Vos droits

Conformément au Règlement Général sur la Protection des Données (RGPD), vous disposez des droits suivants :

- **Droit d'accès** : obtenir une copie de vos données personnelles.
- **Droit de rectification** : corriger des données inexactes ou incomplètes.
- **Droit à l'effacement** (« droit à l'oubli ») : demander la suppression de vos données.
- **Droit à la limitation du traitement** : restreindre temporairement l'utilisation de vos données.
- **Droit à la portabilité** : recevoir vos données dans un format structuré et lisible par machine.
- **Droit d'opposition** : vous opposer au traitement fondé sur l'intérêt légitime. Pour la mesure d'audience du site : activez Do Not Track ou Global Privacy Control dans votre navigateur, ce qui vaut pour tous nos sites ; ou, sur le site, utilisez l'interrupteur de **Profil → Confidentialité** ou de la page **Confidentialité** (/confidentialite). Cet interrupteur ne vaut que pour ce navigateur et pour ce site : à refaire sur chaque site de club et sur chaque navigateur. L'application ne mesure rien.
- **Droit de retirer votre consentement** : à tout moment, sans affecter la licéité du traitement antérieur.

### Exporter vos données vous-même

Vous pouvez exercer vous-même vos droits d'accès et de portabilité, sans nous écrire : dans **Profil → Confidentialité → Mes données**, sur le site ou dans l'application, demandez un export. Nous préparons une archive ZIP et vous envoyons par e-mail un lien de téléchargement, valable **7 jours**. Un export par heure et par compte.

L'archive contient, au format JSON, tout ce qui vous concerne : votre profil, vos équipes, vos inscriptions, ce que vous avez publié et vos fichiers, vos notifications des 90 derniers jours et leurs réglages, vos appareils enregistrés pour le push, vos blocages, les signalements que vous avez faits (sans la copie du texte signalé, qui est le contenu de quelqu'un d'autre) et vos signalements de problème. Les secrets d'authentification (mot de passe haché, jetons, clés) en sont exclus pour des raisons de sécurité, mais leurs métadonnées (dates, appareils, services) y figurent. L'archive ne contient pas encore votre fuseau horaire, votre réglage de contact pour les annonces, vos invitations dans une équipe, ni la trace des messages envoyés au sujet des petites annonces ; demandez-les à privacy@pedalons.fr.

### Supprimer votre compte

Vous pouvez supprimer votre compte vous-même, à tout moment, sans nous écrire :

- **sur le site web comme dans l'application mobile** : **Profil → Mon compte → Zone de danger**, puis « Supprimer le compte ».

Si vous êtes le seul administrateur d'une équipe qui compte d'autres membres, vous devez d'abord nommer un autre membre administrateur : l'application et le site vous indiquent les équipes concernées. Une équipe dont vous êtes le seul membre est supprimée avec votre compte.

Si vous n'avez plus accès à votre compte ou à l'application, écrivez-nous depuis l'adresse e-mail de votre compte à **privacy@pedalons.fr** en demandant sa suppression.

La suppression est irréversible et immédiate : toutes les données rattachées à votre compte sont effacées dès votre confirmation, à ces exceptions près :

- **Ce que vous avez publié pour une équipe** (sorties, voyages, parcours, posts et leurs fichiers) appartient à cette équipe et reste en ligne, attribué à « Ancien membre », sans plus aucun lien avec vous. Vos inscriptions aux sorties passées sont conservées sous la même forme anonyme, sans être affichées.
- **Vos commentaires** sont effacés, sauf un commentaire auquel d'autres membres ont répondu, conservé vide avec la mention « Commentaire supprimé ».
- **Vos petites annonces** sont retirées, vidées de leur texte, de leur prix et de leur lieu, et leurs photos supprimées.
- **Les signalements que vous avez faits** sont conservés sans lien avec vous, pour que les décisions prises restent vérifiables ; les tickets GitHub issus de vos signalements de problème restent en place, avec un identifiant qui ne mène plus à personne. Les signalements qui vous visent sont supprimés.
- **Les notifications que vous avez déclenchées** chez d'autres membres gardent votre nom affiché jusqu'à leur expiration (90 jours), et les messages déjà publiés dans le canal de discussion d'une équipe y restent.
- **Nos sauvegardes** contiennent encore vos données pendant 30 jours au maximum (voir section 6).

Pour qu'un contenu publié pour une équipe disparaisse, supprimez-le avant de supprimer votre compte, ou demandez-le à un organisateur de l'équipe. Supprimer votre compte efface la connexion à vos services GPS de notre côté, mais ne retire pas l'autorisation que vous leur aviez donnée : vous pouvez la révoquer depuis votre compte Hammerhead, Garmin ou Wahoo.

### Nous contacter

Pour exercer vos autres droits, ou si vous préférez passer par nous, écrivez à **privacy@pedalons.fr**. Pour protéger vos données, nous pouvons vous demander de confirmer une demande depuis l'adresse e-mail rattachée à votre compte.

Nous répondons à toute demande dans un délai de **30 jours**. Si nous ne pouvons pas donner suite, nous vous expliquerons pourquoi.

Vous pouvez également introduire une réclamation auprès de la **CNIL** (Commission Nationale de l'Informatique et des Libertés) : [www.cnil.fr](https://www.cnil.fr)

---

## 8. Cookies et stockage local

Pedalons utilise un nombre minimal de cookies et de données de stockage local :

- **refresh_token**
  - *Type* : Cookie HttpOnly (site web)
  - *Finalité* : Maintenir votre session authentifiée
  - *Durée* : 30 jours après la connexion
- **refresh_token**
  - *Type* : Stockage sécurisé de l'appareil (application mobile ; ce n'est pas un cookie)
  - *Finalité* : Vous garder connecté sans ressaisir vos identifiants
  - *Durée* : Jusqu'à la déconnexion (validité de la session côté serveur : 30 jours)
- **lang**
  - *Type* : Cookie
  - *Finalité* : Mémoriser la langue que vous avez choisie, pour afficher les pages dans cette langue
  - *Durée* : 1 an
- **pedalons-unit-system**
  - *Type* : localStorage
  - *Finalité* : Mémoriser votre système d'unités
  - *Durée* : Persistant
- **mantine-color-scheme-value**
  - *Type* : localStorage
  - *Finalité* : Mémoriser votre thème (clair/sombre)
  - *Durée* : Persistant
- **pedalons-map-style, pedalons-map-terrain3d, pedalons-map-hillshade**
  - *Type* : localStorage
  - *Finalité* : Mémoriser vos préférences d'affichage de carte
  - *Durée* : Persistant
- **pedalons-error-reports**
  - *Type* : localStorage
  - *Finalité* : Mémoriser que vous avez désactivé les rapports d'erreur automatiques
  - *Durée* : Persistant
- **pedalons.webPush.token**
  - *Type* : localStorage
  - *Finalité* : Désinscrire ce navigateur des notifications push lorsque vous vous déconnectez ou les coupez
  - *Durée* : Jusqu'à votre déconnexion ou la coupure des notifications
- **Données de messagerie Firebase**
  - *Type* : Stockage du navigateur (site web)
  - *Finalité* : Inscription de ce navigateur aux notifications push, uniquement une fois que vous les avez activées
  - *Durée* : Jusqu'à l'effacement des données de votre navigateur
- **pedalons.installBanner.dismissedAt**
  - *Type* : localStorage
  - *Finalité* : Mémoriser que vous avez fermé la proposition d'installer le site comme une application
  - *Durée* : Persistant (la proposition revient après 90 jours)
- **pendingInvitationToken, pendingBiketeamMigrationRequest**
  - *Type* : sessionStorage
  - *Finalité* : Garder une invitation à une équipe, ou une demande de transfert d'équipe depuis Biketeam, le temps de vous connecter
  - *Durée* : Jusqu'à la fermeture de l'onglet
- **pedalons-analytics-optout**
  - *Type* : localStorage
  - *Finalité* : Retenir votre opposition à la mesure d'audience, sur ce site et dans ce navigateur seulement
  - *Durée* : Jusqu'à ce que vous retiriez votre opposition ou effaciez les données du site dans votre navigateur

Lorsque vous êtes connecté, la langue, les unités et le thème enregistrés dans votre compte prévalent sur la copie locale. Pour les autres données conservées par l'application mobile et par les extensions Karoo et Garmin, voir « Données stockées localement sur votre appareil » à la section 1.

**Nous n'utilisons aucun cookie de suivi, d'analyse ou de publicité.** La mesure d'audience du site n'utilise aucun cookie et remplit les conditions d'exemption de consentement de la CNIL (voir « Mesure d'audience du site » à la section 1) ; vous pouvez vous y opposer à tout moment (voir section 7). Aucun consentement n'est donc requis : le cookie de session est strictement nécessaire au fonctionnement du service, et le cookie lang ne fait que mémoriser un choix que vous avez fait. Notez que l'affichage d'une carte amène votre navigateur à demander des tuiles directement au fournisseur du style sélectionné — voir « Affichage des cartes et recherche d'adresses » à la section 4.

---

## 9. Sécurité

Nous mettons en œuvre les mesures suivantes pour protéger vos données :

- **Chiffrement en transit** : toutes les communications utilisent HTTPS (TLS).
- **Chiffrement au repos** : les jetons d'accès à vos services GPS sont chiffrés (AES-256-GCM).
- **Hachage des secrets** : mots de passe (bcrypt), jetons de session, codes à usage unique et liens envoyés par e-mail ne sont stockés que sous forme de hachages irréversibles. Deux secrets font exception, car nos systèmes doivent les rechercher directement : le jeton de votre lien calendrier et le court code d'appairage d'un appareil GPS (valable 10 minutes).
- **Cookie de session** : illisible par les scripts de la page, envoyé uniquement en HTTPS, et protégé contre son utilisation par un autre site pour modifier vos données.
- **Isolation entre sites** : les données de chaque site sont isolées dans la base de données ; seuls les administrateurs de la plateforme font exception (voir section 4).
- **Limitation des codes de connexion** : le nombre de codes et de liens de connexion pouvant être demandés pour une même adresse est plafonné, et chacun expire rapidement.
- **Limitation des essais** : après plusieurs mots de passe erronés pour une même adresse, la connexion par mot de passe est suspendue un quart d'heure (la connexion par code e-mail et par clé d'accès reste possible) ; de même, les codes d'appairage d'appareils GPS inconnus sont limités.
- **Sauvegardes** : chiffrées en transit vers un serveur séparé. La base de données est chiffrée avant de quitter nos serveurs, et seule une clé conservée hors ligne peut la déchiffrer ; l'ensemble est stocké sur un volume chiffré.

Aucun système n'est infaillible. Si vous constatez une activité suspecte sur votre compte, contactez-nous immédiatement.

**Violation de données** : si une violation de vos données présente un risque pour vos droits et libertés, nous la notifions à la CNIL dans les 72 heures après en avoir pris connaissance ; si le risque est élevé, nous vous prévenons aussi, dans les meilleurs délais, en vous disant ce qui s'est passé et ce que vous pouvez faire.

---

## 10. Mineurs

Pedalons n'est pas destiné aux enfants de moins de 16 ans, et nous ne collectons pas sciemment leurs données. En créant votre compte, vous déclarez avoir au moins 16 ans, dans la même case que l'acceptation des conditions, dont nous gardons la date. Nous ne vérifions pas cette déclaration et ne vous demandons pas votre date de naissance. Si vous êtes parent et pensez que votre enfant nous a fourni des données, contactez-nous pour que nous les supprimions.

---

## 11. Modifications de cette politique

Nous pouvons mettre à jour cette politique pour refléter des changements dans nos pratiques ou dans la réglementation ; la date en tête de cette page indique la dernière version. En cas de changement important, nous vous en informerons par e-mail.

---

## 12. Responsable du traitement

Le responsable du traitement de vos données personnelles est :

- **LANDAIS Gabriel** (entreprise individuelle)
- **Adresse** : 29 rue Docteur Jean Rostand, 44800 Saint-Herblain, France
- **SIRET** : 897 872 958 00011

C'est le même responsable sur tous les sites que Pedalons héberge, y compris celui d'un club sous son propre nom de domaine : les clubs et les équipes qui utilisent la plateforme ne sont pas responsables du traitement de vos données sur Pedalons.

### Délégué à la protection des données (DPO)

Le délégué à la protection des données est **Gabriel Landais**, joignable à l'adresse de contact ci-dessous.

## 13. Contact

Pour toute question relative à cette politique ou à vos données personnelles : **privacy@pedalons.fr** (réponse sous 30 jours maximum).

---
