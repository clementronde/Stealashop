# FAST OPEN (`FastOpen`) — fiche gamepass

Statut : **proposition, à valider par Clément** (2026-11-21). Rien créé sur Roblox.

| Champ | Contenu |
|---|---|
| Clé | `FastOpen` (`Order = 5`) — la clé ne change pas, même si le nom affiché change |
| Nom actuel | FAST OPEN |
| **Nom proposé** | **FAST UNLOCK** : depuis la vague 52, il n'y a plus de colis posé à ouvrir en base ; le pass ne fait plus que raccourcir l'**antivol**. « Fast Open » promet autre chose (ouvrir les colis plus vite) : risque de déception, voire de texte trompeur. |
| Effet exact | L'antivol d'un objet ramené et posé au sol dure `DelayFactor = 0.5` fois moins longtemps (UnboxService.GetAntiTheftDelay). Antivol de base (ShelfOpen.AntiTheft, L-112) : Commun 5 s, Peu commun 10, Rare 20, Épique 30, Légendaire 60, Mythique 90, Secret 120, Divine 180. Avec le pass : 2,5 s à 90 s. Pendant l'antivol, l'objet est **volable** et ne peut pas aller sur un présentoir. S'applique aussi aux objets déjà sous antivol à l'achat. |
| Équilibre | Avantage **défensif** dans le vol entre joueurs : les voleurs ont 2 fois moins de temps pour reprendre un objet tout juste ramené. Ça compte surtout pour les objets rares (Secret : 60 s de gagnées). Raisonnable, mais c'est bien de l'avantage PvP payé : ne pas aller au-delà de ×0,5. |
| Prix actuel | 299 R$ |
| **Prix proposé** | **199 R$**. L'effet a rétréci (une fenêtre de 2,5 à 90 s par objet ramené) ; les « open speed » du genre touchent toute la boucle (Steal A Pet : 299 ; Steal a PC : 99). À 299 il serait aussi cher que ×2 Training, pour un effet bien plus court. |
| Description (page Roblox) | `Items you bring home unlock 2× faster, so thieves get half the time to steal them back!` |
| Ligne de carte | `Items unlock 2× faster` (au lieu de `Anti-theft 2× shorter` : « anti-theft » n'est pas un mot du jeu côté joueur ; à garder si le billboard `BB_AntiTheft` montre ce mot) |
| Place dans la boutique | Gamepasses, après Auto Collect. |
| Icône | `UI_Icon_GP_FastOpen` (existe : cadenas bleu avec flèches d'avance rapide) : **le concept est déjà juste** pour « unlock ». Famille : cadenas ouvert + « ×2 » ou flèches ▶▶, médaillon bleu `2FA8F0`. Le nom de l'icône ne change pas (contrat). |

## Pour Ironix
- Si Clément valide : `DisplayName = "Fast Unlock"`, `Effect = "Items unlock 2× faster"`, `Price = 199` dans Config ; message de MonetizationService `MESSAGES.FastOpen` (« Fast Open: anti-theft 2× shorter! ») à mettre au même nom (`Fast Unlock: items unlock 2× faster!`). Clé `FastOpen` et icône `UI_Icon_GP_FastOpen` inchangées.
- Doc 4.1 à corriger (« Toutes les attentes d'ouverture des colis PNJ » n'est plus vrai).

## Questions
1. Clément : on renomme en FAST UNLOCK ?
2. Clément : 199 ou on garde 299 ?
3. Clément et Ironix : préférez-vous élargir l'effet plutôt que baisser le prix (ex. aussi l'ouverture du colis sur le rayon, T-251 « plusieurs coups ») ? Ce serait une nouvelle règle de jeu : à décider, pas à inventer ici.
