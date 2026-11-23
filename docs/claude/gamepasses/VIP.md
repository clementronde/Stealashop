# VIP (`VIP`) — fiche gamepass

Statut : **proposition, à valider par Clément** (2026-11-21). Rien créé sur Roblox. **Pas codé** (`Ready = false`) : pas vendable à la MAJ 1 tel quel.

| Champ | Contenu |
|---|---|
| Clé | `VIP` (`Order = 3` en Config ; **6e carte** dans la maquette Studio) |
| Nom | **VIP** |
| Effet exact (doc 4.1) | Tag VIP dans le chat, aura VIP, **+10 % de revenus**, rideau **+30 s** (le « +1 coffre-fort » a été retiré, vague 54). Aucune valeur en Config pour l'instant : +10 % et +30 s viennent du doc. Le rideau est une défense de la **MAJ 2** : il n'existe pas encore. |
| Équilibre | +10 % s'additionne aux autres bonus en % (Premium, index) : faible, sain. Rideau +30 s = avantage défensif contre le vol entre joueurs, modéré. Le bouquet est presque le même que le VIP de Steal a Wild Horse (« +10% cash, +60s gate lock, VIP tag »). |
| Prix actuel | 249 R$ |
| **Prix proposé** | **249 R$, inchangé** (benchmark : 99 à 375 ; Brainrot 375, Pet 199). |
| Description (page Roblox) | **MAJ 1, sans rideau** : `+10% cash, a VIP aura and a VIP chat tag!` — **MAJ 2** : ajouter `…and +30 s of shutter time.` On n'écrit jamais un effet absent du jeu. |
| Ligne de carte | `+10% income, aura, chat tag` (inchangée, juste pour la MAJ 1) |
| Place dans la boutique | Gamepasses. **Question d'ordre** : Config le met 3e, la maquette 6e (dernier). Proposition : **3e**, juste après les deux ×2, comme dans le genre (le trio ×2 argent / VIP / vitesse en tête). |
| Icône | `UI_Icon_GP_VIP` (existe). Concept famille : couronne dorée avec « VIP » gravé, médaillon violet `8A5CF0`. |

## Pour Ironix
- Pour le vendre à la MAJ 1 sans le rideau : coder tag de chat (TextChatService), +10 % de revenus (`DisplayService.GetIncomeBonus`, même chemin que Premium), et l'aura dès que Clément la livre ; ajouter `IncomeBonus = 0.1` à l'entrée VIP de Config (valeur du doc 4.1).
- Le rideau +30 s viendra avec DefenseService (MAJ 2) ; à ce moment, mettre à jour la description sur le Creator Hub.
- Ordre des cartes : aligner `Order` sur la décision de Clément (3e ou 6e).

## Questions
1. Clément : VIP vendu dès la MAJ 1 sans le rideau, ou on attend la MAJ 2 ?
2. Clément : 3e ou 6e carte ?
3. Clément : l'aura VIP est-elle prévue de ton côté (nom `FX_Aura_VIP` ?) — sinon pas de VIP à la MAJ 1.
