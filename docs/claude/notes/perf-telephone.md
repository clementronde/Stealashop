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
