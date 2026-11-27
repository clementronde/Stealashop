# Règles des plateformes qui changent un plan

Relevé le 25/11/2026 sur les pages officielles (codes et monétisation relus le 26/11). Une règle bouge souvent : relire la source avant une décision qui coûte (argent, date de sortie).
Détail complet et sources secondaires : vault `_Vault/Marketing/Benchmark_Roblox_testeurs_codes_liens.md`.

## Roblox : qui peut jouer à un jeu neuf

| Règle | Source |
| --- | --- |
| Un nouveau jeu est d'abord ouvert **seulement aux 16+ vérifiés par l'âge** (phase d'essai) | [Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select) |
| Comptes **Kids (5-8 ans)** et **Select (9-15 ans)** : il faut **100 parties uniques de joueurs vérifiés très engagés en 60 jours**, puis un examen de sécurité. Suivi : Creator Hub > le jeu > Paramètres de publication > Gérer l'audience | idem |
| Autre voie : **révision accélérée**, 50 000 Robux par jeu, remboursables (pas si le jeu est modéré pour de bon). Pour un lancement à date fixe | idem |
| Groupe propriétaire : compte vérifié (pièce d'identité si 18+), double authentification, abonnement Plus ou Premium depuis 2 mois **ou** frais uniques remboursables | idem |
| Note de contenu : Minimale ou Légère pour Kids ; jusqu'à Modérée (9+) pour Select. Un jeu de braquage avec armes peut être noté Modérée | idem |

**Conséquence** : un lancement à date fixe vise les moins de 16 ans seulement si le seuil est passé (test public avant la sortie) ou si la révision accélérée est payée. Décision de Clément et Cantin.

## Roblox : liens et textes

| Règle | Source |
| --- | --- |
| **3 liens** au plus, un par type, parmi : Facebook, X, YouTube, Twitch, Discord, Guilded, communauté Roblox. **Pas TikTok, pas Instagram, pas Linktree** | [Social media links](https://create.roblox.com/docs/production/promotion/social-media-links) |
| Liens visibles **seulement par les 16+ vérifiés** (depuis le 30/06/2026) | idem, [aide Roblox](https://en.help.roblox.com/hc/en-us/articles/360000910966) |
| **Aucun lien ni « discord.gg/… »** dans la description, le jeu ou le chat. Phrase permise : « Join us in our Community Server. Links on our game's page » | idem |
| **Share Link** : un lien suivi par réseau, permis hors de Roblox, avec données de lancement possibles (un avantage pour qui arrive par ce lien) | [Share links](https://create.roblox.com/docs/production/promotion/share-links) |
| Éviter : titre centré sur la récompense (« free », « Robux »), métadonnées qui trompent, quasi-copie d'un autre jeu | [Discovery](https://create.roblox.com/docs/production/promotion/discovery) |

## Roblox : découverte (2026)

| Règle | Source |
| --- | --- |
| Fenêtre de **28 jours** depuis le 15/06/2026 ; rétention J1, J2-7, J8-28 | [newsroom 15/06/2026](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox) |
| Signaux principaux : taux de passage, rebond de la première partie, jours et temps de jeu par joueur (jusqu'à 60 min par jour) | [Discovery](https://create.roblox.com/docs/production/promotion/discovery) |
| Seuls les joueurs arrivés par l'accueil comptent pour le classement de l'accueil : les pubs et les vidéos amènent des joueurs, la rétention fait le reste | [Discovery FAQ](https://create.roblox.com/docs/discovery-faq) |
| Pas de page « Coming soon » officielle. Outils : jeu privé + rôle Tester du groupe, mode Beta (caché des recommandations), **évènement d'expérience** avec bouton Notify Me | [Experience events](https://create.roblox.com/docs/production/promotion/experience-events) |
| Today's Picks : choix humains ; une mise à jour enregistrée comme évènement aide | [DevForum 13/10/2025](https://devforum.roblox.com/t/roblox-curation-how-do-we-consider-games-for-today%E2%80%99s-picks/4005089) |

## Codes (règle officielle relue le 26/11/2026)

- **Un code publié hors du jeu** (TikTok, Discord, X, YouTube…) est une « offre promotionnelle » ([Promo Offers for Virtual Rewards](https://en.help.roblox.com/hc/en-us/articles/10549651908244-Promo-Offers-for-Virtual-Rewards)). Les conditions :
  - sa récompense ne sert que dans notre jeu ;
  - elle n'est **ni un objet vendu en Robux, ni la monnaie du jeu quand elle s'achète en Robux**. Chez nous, l'argent ($) se vend en Robux : un code ne donne jamais d'argent, ni un ×2 Cash (vendu dans le Starter Pack) ;
  - **aucun échange** n'est demandé pour l'obtenir : jamais « like = code » ni « follow = code » ;
  - les détails et la **date de fin** sont publics, partout où le code est annoncé.
- Récompenses sûres pour un code : un objet de colis (`Kind = "Item"`), ou une récompense qui ne sert qu'aux codes et ne se vend jamais.
- Un **objectif collectif** (« Thanks for 1,000 likes, code for everyone ») reste possible : chacun reçoit le code sans rien faire en échange. Mais la récompense suit la même règle. Source : DevForum, avis de membres (non officiel) ; [Discovery FAQ](https://create.roblox.com/docs/discovery-faq) pour les jeux « menés par les cadeaux ».

## Monétisation dans le jeu (Directives, relues le 26/11/2026)

| Règle | Source |
| --- | --- |
| Remise authentique (pas « en promo » en permanence) et juste (pas une durée très courte qui presse) | [Monétisation, Directives](https://create.roblox.com/docs/production/monetization) |
| Jamais de fausse rareté ni de fausse durée ; jamais de compte à rebours inexact ou qui redémarre pour le même article | idem |
| Avec les mineurs : « View item », « See price », « Open shop », jamais « GET IT NOW », « LAST CHANCE », « BUY BEFORE IT'S GONE! » | idem |
| Minuteries qu'on supprime ou qu'on avance en payant : déconseillées sur Roblox | idem, « Stratégies » |
| Objet aléatoire payant : les chances de chaque résultat avant la dépense, et `PolicyService` pour bloquer les joueurs à qui c'est interdit (obligatoire) | [Objets aléatoires payants](https://create.roblox.com/docs/production/monetization/paid-random-items) ; [Règles de la communauté](https://about.roblox.com/fr/community-standards) |
| Récompense contre un like ou un favori : aucune règle officielle ne la nomme, mais le contenu trompeur « pour l'engagement » est interdit. Le DevForum la juge interdite. Le groupe (`IsInGroup`) est la condition admise | [Règles, Intégrité](https://about.roblox.com/fr/community-standards) ; détail : vault `_Vault/Marketing/Kits_UIverse/Synthese_kits.md` |

## Réseaux

| Règle | Source |
| --- | --- |
| **TikTok** : lien en bio cliquable à partir de **1 000 abonnés** ou avec un compte Entreprise vérifié ; TikTok conseille les liens directs. Avant le seuil : écrire le code Discord en clair | [TikTok, lien en bio](https://www.tiktok.com/support/faq_detail?id=7581821550328896012) |
| **TikTok** : pas de bannière ; photo de profil en rond | `StealAShop-Art/Reseaux/_tailles/tailles_plateformes.md` |
| **Discord** : lien court `discord.gg/<nom>` au **niveau 3 = 14 boosts** ; perdu 30 jours après la fin des boosts. Avant : une invitation permanente partout | [FAQ boosts](https://support.discord.com/hc/en-us/articles/360028038352) |
| **Linktree** : à éviter. Roblox ne l'accepte pas, TikTok conseille le lien direct, les gros jeux du genre mettent le Discord en direct | benchmark Roblox du vault |
