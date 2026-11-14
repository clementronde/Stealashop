# Optimisation téléphone : mesures et corrections en attente (2026-11-11)

Audit de performance fait avec le skill performance-optimization (agent en lecture seule + mesures dans Studio).
**Rien n'est corrigé** : Cantin garde ces points pour une future passe « optimisation téléphone ». Règle du skill :
mesurer avant, corriger une chose à la fois, remesurer, garder seulement ce qui gagne au-delà du bruit.

## Mesures (Studio, Play solo, PC, main 55c3da9)

Outils : `ScriptProfilerService` (ServerStart / ClientStart(player, 1000) sur 10 s), `Stats`.

| Situation | Résultat |
| --- | --- |
| Serveur, jour, au repos | Heartbeat 0,18 ms en moyenne (max 0,32), envoi 0,6 kb/s ; nos 31 services < 1 ms par seconde |
| Serveur, nuit, 12 vigiles en ronde | Heartbeat 0,49 ms (max 0,70), envoi 2,9 kb/s ; GuardService ≈ 8 ms par seconde au total |
| Client, dans sa boutique (19 objets exposés) | Nos scripts ≈ 40 ms par seconde, soit ≈ 0,7 ms par image sur PC ; 27 350 triangles, 196 draw calls, ≈ 140 000 instances |

Plus gros coûts client mesurés (sur 10 s) : `ItemIdleController.onHeartbeat` 199 ms, `DisplayController.animate`
69 ms, `ShelfBoxController.step` 45 ms, `CarryController.updateRainbows` 32 ms (sans rien porter),
`HudController.update` + `countdownText` 45 ms. Caméra de Roblox : 63 ms. Sur un téléphone 3 à 4 fois plus lent,
nos scripts monteraient vers 2,5 ms par image (budget 16 ms). Pas de mesure sur un vrai téléphone.

## Corrections proposées (à faire dans la passe téléphone, avec mesure avant/après)

1. **ItemIdleController** (l.296-318, 401-426) : animer seulement les objets proches et à l'écran, déplacer les
   pièces d'un coup avec `Workspace:BulkMoveTo` (comme ShatterController), cadence plus basse au-delà de 30 studs.
2. **Halos des objets exposés** (DisplayService l.952-1027 et 1070 ; DisplayController l.346-386) : jusqu'à 144
   objets avec PointLight, ParticleEmitter, BillboardGui, et 8 à 10 Beams du Légendaire au Secret. Côté client,
   lumières et particules seulement à moins de 40 à 60 studs ; `ColorSequence` des Secrets calculées une fois (l.371
   en recrée une par rayon à chaque image) ; rayons animés seulement à l'écran.
3. **CarryController.updateRainbows** (l.277-283) : ne rien faire quand on ne porte rien (`GetDescendants` à chaque
   image tant qu'un Secret porté n'a rien à colorer).
4. **HudController** : réécrire le compte à rebours de la nuit seulement quand la seconde change.
5. **Highlights** : 25 contours de colis (`Config/ShelfBoxes.MaxOutlines`) + 6 porteurs + 3 alertes = 34, au-delà de
   la limite de 31 de Roblox (les derniers ne s'affichent pas, sans erreur) : MaxOutlines à 20.

À regarder aussi sur téléphone : la map (≈ 140 000 instances, domaine de Clément), BenchBarController
(`begin()` relancé à chaque image si la barre ou les mains manquent), PvPController (toutes les 0,2 s sur tous les
objets exposés des autres boutiques).

## Écartés par la mesure (ne pas optimiser)

- **Serveur** (vigiles, filtre de raycast reconstruit à chaque image, test de zone safe répété, PathfindingService,
  Humanoids des PNJ) : < 1 % d'un cœur, même la nuit avec 12 vigiles. À remesurer seulement avec 6 joueurs et
  6 poursuites en même temps (Test > Local Server).
- **Réseau** : l'état de l'inventaire (InventoryService, toutes les 0,5 s) n'est envoyé que s'il change ; montants
  des plaques ≈ 0,6 kb/s.
- WindowService, AntiCheatService, TrainingService, MachineVariantService, RayonService, StoreHeistService,
  NightCycleService, ShatterController, minuteurs d'UnboxService : cadencés ou bornés. Aucune fuite mémoire trouvée.

## Mesures avant et après la vague 39 (2026-11-14)

**Méthode** (détail dans les notes de session `perf-avant-vague39-2026-11-14.md` et `perf-apres-vague39-2026-11-14.md`) :
Play solo dans Studio, profil IRONIX01, boutique `PLOT_Shop_01` avec 20 objets exposés (4 Légendaires, aucun Secret),
de jour, rien porté. Caméra scriptée qui fait un tour de 18 studs de rayon en 10 s ; ScriptProfiler client à 1000 Hz,
**temps total** de chaque fonction en ms sur 10 s. S1 : perso dans la boutique ; S2 : perso à 80 studs de la porte.
AVANT = main f87a40c, 3 mesures ; APRÈS = main e80d556, 5 mesures. Moyenne ± écart type.
Pas d'A/B dans le même Play : les modules de Config sont gelés (`DeepFreeze`), on ne peut pas couper une correction
pendant le Play sans changer `src/`.

| Fonction | Situation | Avant | Après | Gain | Décision |
| --- | --- | --- | --- | --- | --- |
| Images par seconde | S1 / S2 | 22,3 ± 5,0 / 35,0 ± 1,7 | 36,7 ± 0,9 / 41,6 ± 1,5 | (plus d'images après) | — |
| Tous nos scripts client | S1 | 764 ± 168 | 726 ± 30 | 38 (dans le bruit) | — |
| Tous nos scripts client | S2 | 876 ± 35 | 751 ± 32 | 125 (net) | — |
| `ItemIdleController.onHeartbeat` | S1 | 112 ± 37 | 34,5 ± 14,4 | 78 (net ; par image 0,50 → 0,09 ms) | GARDER (1b, 1c) |
| `ItemIdleController.onHeartbeat` | S2 | 8,2 ± 6,5 | 1,1 ± 1,7 | 7 (dans le bruit) | — |
| `DisplayController.animate` | S1 | 46 ± 20 | 28,6 ± 7,5 | 18 (limite) | INCERTAIN (2a, 2b, 2c) |
| `DisplayController.animate` | S2 | 31,5 ± 12,6 | 16,5 ± 5,5 | 15 (limite) | INCERTAIN |
| `HudController.update` | S1 | 32 ± 39 | 9,6 ± 7,6 | 23 (dans le bruit) | — |
| dont `countdownText` | S1 / S2 | 5,3 ± 5,3 / 6,2 ± 4,7 | 0 / 0 (10 mesures sur 10) | 5 à 6 (net) | GARDER (4) |
| `PvPController.refreshAll` | S1 | 2,2 ± 3,8 | 7,3 ± 2,6 | −5 (plus cher, dans le bruit) | gardé (Cantin), à remesurer à plusieurs (T-050) |
| `PvPController.refreshAll` | S2 | 6,3 ± 5,3 | 4,7 ± 1,7 | 2 (dans le bruit) | gardé (Cantin), à remesurer à plusieurs (T-050) |
| `CarryController.updateRainbows` | S1 / S2 | 0 | 0 | rien porté : pas exercée | INCERTAIN (3) |

« Net » : l'écart dépasse 2 fois l'erreur sur la différence (test de Welch, t > 2). L'APRÈS a 1,2 à 1,6 fois plus
d'images que l'AVANT : à coût par image égal, ses totaux seraient plus hauts ; une baisse est donc un vrai gain.

**Highlights** : 1 actif sur 122 avant comme après, dans S1 et S2 (de jour, sans porteur ni colis proche) : la limite
de 31 n'est pas en jeu dans ces situations.

**Bruit** : AVANT, Studio tournait entre 16 et 37 i/s (écart de 15 à 120 % sur nos fonctions) ; APRÈS, entre 36 et
43 i/s, beaucoup plus stable. Les petites fonctions (quelques ms sur 10 s) sont à la limite de résolution du
profileur (1 échantillon = 1 ms).

**Corrections de la vague 39 classées**

- GARDER : 1b (objets exposés animés seulement à l'écran, `ItemIdle.OnScreenOnly`) et 1c (un seul `BulkMoveTo`
  par pose) : gain net dans la boutique, inséparables sans A/B. 4 (compte à rebours réécrit à la seconde) :
  `countdownText` absent des 10 mesures après, présent dans les 6 d'avant. 5 (`ShelfBoxes.MaxOutlines` 20) : limite,
  gardée sans gain à mesurer.
- RETIRER : PvPController (a129, objets revus seulement quand l'état de la boutique change) : aucun gain mesuré
  (S1 plutôt plus cher). Remettre le fichier : `git checkout f87a40c -- src/client/Controllers/PvPController.luau`.
  Réserve : mesuré avec 2 boutiques occupées sur 8, pas 8 pleines.
  **Décision de Cantin (2026-11-14) : on la garde**, et on la mesure au premier test avec plusieurs vrais joueurs (le plus de boutiques occupées possible) ; si elle ne gagne toujours rien, on la retire (commande ci-dessus). Rappel : test T-050 de la liaison.
- INCERTAIN : 1a (`ItemIdle.FarInterval`, objets entre 30 et 80 studs) : aucune des deux situations ne la fait
  travailler ; il faudrait mesurer à 40-70 studs, boutique à l'écran, `FarInterval = 0` puis `1/15` dans deux Plays.
  2a, 2b, 2c (`DisplayHalo`) : baisse de 35 à 50 % mais à la limite du bruit (t ≈ 1,5 et 1,9) ; 2c pas exercée
  (aucun Secret exposé). Il faudrait deux Plays par champ coupé puis en marche, Studio au premier plan, un Secret
  exposé ; la lumière et les particules (2a) coûtent surtout au rendu, que le profileur de scripts ne voit pas.
  3 (`CarryController.updateRainbows`) : rien n'est porté dans ces mesures ; à mesurer en portant un objet
  arc-en-ciel, sur un profil de test.
- Hors mesure : BenchBarController (le banc va être retiré du jeu).
