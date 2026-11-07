# Vigiles et animations (MOD-017, MOD-030, ANI-010, ANI-012) — passation, 2026-11-07

## Livré dans Studio (place DEV, Team Create)
- `ReplicatedStorage/Assets/Guards/Guard_Z1` à `Guard_Z6` : rig R15 Roblox (AnimationConstraint, comme les persos joueurs), Humanoid + Animator, dossier `Animations` vide, aucun script. Échelle (`Model:ScaleTo`) 1,00 / 1,08 / 1,16 / 1,24 / 1,32 / 1,40 ; HipHeight 2,19 → 3,07.
- Looks : Z1 supérette (casquette, gilet fluo SECURITY, ceinture radio, café), Z2 Londres (garde royal, bonnet en poil), Z3 Tokyo (casquette plate, baudrier, bâton lumineux néon), Z4 LA (tactique, lunettes aviateur, gilet SECURITY), Z5 Paris (képi, épaulettes, moustache), Z6 New York (costume, lunettes noires, oreillette).
- 21 accessoires `ACC_Z<n>_<Nom>` (Accessory + Handle + attache du corps), ≤ ~610 triangles chacun (budget 1 000).
- Showroom : silhouette `Show_8` et socle `Ped_Vigile zone 1` remplacés par `Ped_Guard_Z1..6` + `Show_Guard_Z1..6` (sans Humanoid, ancrés, accessoires renommés `Show_ACC_…`), rangée BASE ET BOUTIQUES, x = −106,5 à −61,5, z = 280.
- ContractChecker (Edit et Play du 2026-11-07) : « Contrat : OK », seules lignes nouvelles = Guard_Z1..6 « pas encore livrée(s) : Idle, Walk, Run, Catch, Tired ».

## Animations : prêtes à publier, pas publiées
KeyframeSequence dans `ServerStorage/RBX_ANIMSAVES` (Clément les ouvre dans l'éditeur d'animation et publie au nom de RoundStone Studio) :

| Save | Rig | Objet `Animation` à créer avec l'ID | Boucle | Priorité | Marqueur |
| --- | --- | --- | --- | --- | --- |
| Guard_Idle | Rig_Guard | `Guard_Z1..6/Animations/Idle` | oui, 4 s | Idle | — |
| Guard_Walk | Rig_Guard | `…/Walk` | oui, 0,8 s | Movement | — |
| Guard_Run | Rig_Guard | `…/Run` | oui, 0,4 s | Movement | — |
| Guard_Catch | Rig_Guard | `…/Catch` | non, 1,4 s | Action | Impact 0,30 s |
| Guard_Tired | Rig_Guard | `…/Tired` | non, 3,3 s | Action | — |
| Player_HitWindow | Rig_Player | `Assets/Animations/Player/HitWindow` | non, 0,4 s | Action | Impact 0,133 s |
| Player_HitWindowHeavy | Rig_Player | `Assets/Animations/Player/HitWindowHeavy` | non, 0,7 s | Action | Impact 0,233 s |

Coups du joueur : haut du corps seulement (jambes libres). ID : à venir de Clément → registre de la liaison (section 2).
Ne pas créer d'objet `Animation` vide : le ContractChecker le signale en orange.

## Pour Ironix (à mettre dans la liaison si utile)
- `Run` est une boucle de 0,4 s pensée pour ~20 studs/s à l'échelle 1 : `track:AdjustSpeed(WalkSpeed / (20 * model:GetScale()))`, borné 0,6–1,6, évite les pieds qui glissent de la zone 1 à la zone 6. `Walk` (0,8 s) colle à ~10 studs/s à l'échelle 1.
- Rappel L-040 : AgentHeight 5 / AgentRadius 2 de GuardService pour des vigiles jusqu'à 7,3 studs de haut.

## À vérifier par Clément d'un coup d'œil
- Lunettes Z4/Z6 et moustache Z5 posées à la hauteur supposée des yeux de la tête dynamique par défaut (pas pu la lire : droits).
- Plugin Blender « RBX Animations » (Cautioned's Fork v1.96) : installé seulement pour Blender 4.2, qui n'a plus d'exécutable ; dans 5.2 son export plante (matrices des os rangées à plat). Contourné en mémoire pour ce travail ; pas installé dans 5.2.

## Fichiers
- Sources : `StealAShop-Art/Guards/_scripts/` (guards_data.py, anim_defs.py, build_anims.py…), `Guard_Animations.blend`, `Player_Animations.blend`, `rbxanim/*.rbxanim` (format du plugin), `renders/`.
- Dépôt (non commités) : `tools/clement/guards_builder.luau`, `tools/clement/guard_anims_import.luau` (relançables en mode Edit).
