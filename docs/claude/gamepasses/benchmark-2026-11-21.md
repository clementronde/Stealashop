# Benchmark des gamepasses des jeux « Steal a … » (2026-11-21)

Agent `createur-gamepasses`. Source : API publiques de Roblox (recherche « steal a », liste des gamepasses de chaque expérience, vignettes des icônes), relevé le 2026-11-21. On en reprend les **principes**, jamais les visuels ni les noms.

Limites : les **produits développeur** (packs d'argent, boosts, chance du serveur) ne sont pas listables sans être connecté au jeu, et la **mise en avant dans le jeu** (bannière, « BEST VALUE ») ne se voit qu'en jouant : ni l'un ni l'autre n'est relevé ici. « off » = gamepass retiré de la vente (souvent un ancien pass ou un objet d'événement).

## 1. Jeux relevés (joueurs en ligne au moment du relevé)

| Jeu | Joueurs | Gamepasses en vente |
|---|---|---|
| Steal An Egg | 1 654 144 | 2 |
| Break and Steal an Egg | 57 208 | 0 |
| Steal a Brainrot | 53 626 | 3 |
| Steal an Anime Pack | 37 439 | 0 (4 off) |
| Steal A Pet And Ride It | 15 907 | 18 (+4 off) |
| Steal a Superpower | 11 923 | 5 (+1 off) |
| Steal a PC | 7 778 | 3 |
| Steal a Wild Horse | 5 642 | 24 (+9 off) |

Les deux plus gros (Egg, Brainrot) vendent **très peu de gamepasses** (2 à 3)  : leur argent vient sans doute surtout des produits développeur (packs, chance du serveur, caisses), qu'on ne peut pas relever d'ici. Les petits jeux empilent des dizaines de passes, surtout cosmétiques.

## 2. Relevé, par famille d'effet

| Famille | Jeu : nom affiché — prix (R$) — description courte | Chez nous |
|---|---|---|
| **×2 argent** | Egg : « X2 MONEY! » 299 · Brainrot : « 2x Money » 299 · PC : « x2 Money » 99 · Horse : « x2 Money » 399 · Anime : « X2 MONEY! » (off) | ×2 Cash **449** |
| **VIP** | Brainrot 375 (sans texte) · Pet 199 · PC 99 (×2 argent + ×2 vitesse + titre) · Horse (off) : « +10% cash, +60s gate lock, VIP tag! » | VIP 249 (+10 %, aura, tag, rideau +30 s) |
| **Encaissement auto** | Pet : « Auto Collect » 49 · Horse (off) : « Collects stall cash while you're in the server » | Auto Collect 199 |
| **Ouverture / croissance plus rapide** | Egg : « X2 GROWTH SPEED! » **467** (le plus cher du jeu) · Pet : « 3x Open Speed » 299 · PC : « x2 Unbox Speed » 99 · Horse (off) : « x2 Growth » | Fast Open 299 (antivol seulement) |
| **×2 entraînement** | Horse : « x2 Treadmill » 349 · Horse : 20 trails de vitesse du tapis, ×1,5 à ×50, de 19 à 2 999 R$ | ×2 Training 299 |
| **Places en plus** | Horse (off) : « Extra Stalls » (+2) | +4 Displays 349 |
| **Chance permanente** | Superpower : « 2x Luck [PERMANENT] » **49** · Anime (off) : X2 LUCK, X4 LUCK | — (nous : produits ×3 Luck et Server Luck) |
| **Protection de la base** | Horse : « Forever Lock » 499 (la barrière reste fermée pour de bon) | — (nous : produit 30 Min Shield, pas codé) |
| **Objet / carte exclusif** | Superpower : cartes exclusives 649 et 799 · Horse : carottes spéciales (off) | Hydraulic Gloves 499 (pas codé) |
| **×2 ressource secondaire** | Horse : « x2 Carrots » 199 · Pet : « 2x Candy » 249, « x2 Tickets » 299, « x2 Pass XP » 299 | — |
| **Cosmétiques** | Pet : granges, tapis, trails et auras à thème 149–299 · Horse : trails | auras et trails vendus en argent du jeu |
| **Admin** | Brainrot : « Admin Commands » 7 999 | — |

## 3. Ce qui revient

1. **Le trio de base** : ×2 argent (6 jeux sur 8), VIP (4), et un pass de vitesse de progression (ouverture, croissance ou entraînement, 5). Ces trois-là sont toujours en tête de liste.
2. **Prix d'appel** : un pass à 49–99 R$ (Auto Collect 49, 2x Luck 49, PC à 99) pour faire le premier achat. Chez nous, le moins cher est à 199.
3. **×2 argent autour de 299–399** ; personne n'est à 449.
4. **VIP = un bouquet** (bonus d'argent + avantage de défense + tag) : exactement notre idée, et le +10 % est le chiffre courant.
5. **Noms** : 1 à 3 mots, multiplicateur en tête (« X2 MONEY! », « 3x Open Speed »), souvent en capitales avec « ! ». La description, quand elle existe, tient en une phrase et finit souvent par « forever ».

## 4. Les icônes

Planche d'étude (vignettes 150 px, non versionnée) : `C:\Users\User\AppData\Local\Temp\claude\ce45b76667b1377a\5f25a7ed-64df-4fae-8fc9-4d119ab2b9e0\scratchpad\bench_sheet.png`.

- **Un seul objet énorme**, rendu 3D cartoon brillant (billets, cadenas, aimant, couronne, trèfle, chronomètre), **contour noir épais**, fond transparent ou **médaillon rond** (bord doré, fond coloré qui rayonne).
- Le **« ×2 » écrit en très gros**, blanc ou doré, contour noir, posé en bas à droite ou au centre, sur toute icône de multiplicateur.
- **Une famille par jeu** : Anime Pack et Pet font tous leurs passes dans le même médaillon rond, seule la couleur change (vert = argent, violet = chance ×4, arc-en-ciel = croissance). C'est ce qui rend la grille propre.
- Symboles qui reviennent : **liasse de billets** (argent), **aimant qui attire des billets** (auto collect), **couronne ou étoile de shérif avec « VIP »** (VIP), **chronomètre + flèches avance rapide** (vitesse), **cadenas doré** (protection).

**Nos icônes actuelles** (capture de la boutique en jeu, `docs/claude/video/references/2026-11-21_ShopTikTok/frames/apres_play_pc_gamepasses.jpg`) : rendu 3D brillant du bon niveau, mais **pas une famille** : seul ×2 Training a un médaillon et un « ×2 » ; ×2 Cash n'écrit pas « ×2 » ; Auto Collect est un portefeuille (moins clair que l'aimant) ; Fast Open montre un cadenas avec une avance rapide, plutôt juste pour « antivol plus court ».

## 5. Ce qui nous manque, ce qui est en trop

**Manque**
- Un **pass d'appel ≤ 99 R$**. Candidat naturel : Auto Collect (49–99 chez les autres).
- Un **pass de chance permanent** (« 2x Luck ») : c'est le pass le plus courant après ×2 argent dans les jeux à colis. Chez nous, la chance n'existe qu'en produit (×3 Luck, Server Luck). Attention règles Roblox : un bonus de chance sur un tirage gratuit n'est pas un objet aléatoire payant, mais les cotes doivent rester affichées (à vérifier avec le skill de conformité avant d'en faire une fiche).
- Des **cosmétiques en Robux** (skin de boutique, trail exclusif) : gros revenu des petits jeux, sans casser l'équilibre. Idée pour plus tard, hors MVP de la boutique.

**En trop ou à revoir**
- **×2 Cash à 449** : au-dessus de tous les autres (299–399). **Revu après la demande de Clément (2026-11-21)** : ×2 Cash et ×2 Training deviennent la 1re marche bon marché d'une échelle ×2 / ×4 / ×8 / ×16 (29 R$ chacun, demande de Clément), sur le modèle des trails de Steal a Wild Horse. Voir `DoubleCash.md` et `DoubleTraining.md`.
- **Fast Open** : son effet a rétréci (antivol d'un objet posé au sol seulement, vague 52) alors que les « open speed » des autres touchent toute la boucle. À 299 R$, il risque de décevoir : renommer ou élargir l'effet (question pour Clément et Ironix).
- **Hydraulic Gloves** (499, pas codé) : un outil 2,5 × plus fort touche directement au vol entre joueurs ; les autres jeux vendent des objets exclusifs, mais plutôt cosmétiques ou pour le PvE. À garder hors MAJ 1.
- **7 gamepasses** d'un coup, c'est plus que les gros du genre (2–3) : avec 5 vendables à la MAJ 1, la gamme est bonne ; inutile d'en ajouter avant d'avoir des chiffres de vente.
