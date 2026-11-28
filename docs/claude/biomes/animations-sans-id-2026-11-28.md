# Animations sans ID publié, 28/11 (chef animation)

Sources : `Contract/Animations.luau` et liaison d'origin/main (80a00384), ContractChecker de la place v1520 (28/11), `Config/Features` d'origin/main, générateurs de `Guards/_scripts`. Rien n'a été touché dans Studio.

## Ce que dit le contrat
Toutes les animations du contrat ont un objet posé dans Studio, sauf deux groupes :

| Animations | Contrat | État | Utile à la sortie ? |
| --- | --- | --- | --- |
| `TrapStuck`, `TrapNetted`, `TrapSlip` | `Animations.Player` | Faites le 27/11 (`npc_extra_gen.py`), dans la vidéo `Guards/renders/nouvelles_animations_2026-11-27.mp4`. Pas validées, pas publiées. | Non : `Features.Traps = false` en PROD (seul `TrapsDev` est allumé). Stunned se joue à leur place. |
| `OpenCommon` … `OpenDivine`, `GrowSmall`, `GrowLarge`, `GrowColossal` (11) | `Animations.Reveal`, rig `Assets/Cinematics/CAM_Reveal` | Jamais faites. Le ContractChecker ne les contrôle pas, et le code a un repli. | Peu probable : l'ouverture se fait sur place (Unbox_*). Question à Cantin : la cinématique CAM_Reveal se joue-t-elle encore ? |

À vérifier à la prochaine ouverture de Studio, en Edit : le ContractChecker de la session a écrit « Animations absent » pour les 4 vendeurs de `ServerStorage/Assets/Env/Stalls/ENV_Stalls_*_Hub`. Le registre dit pourtant les ID posés dans les 8 vendeurs. La ligne date peut-être d'un passage plus ancien.

Hors sujet pour la sortie :
- `NPC_Bodyguard` et `NPC_DoorGuard` (`Hit`, `Knockdown`, `GetUp` de L-366) : retirés de la V1 (L-488).
- Ouvriers contrôlés comme des vigiles (Run, Catch, Tired…) : question de contrat posée à Cantin (L-506).

## Faites, hors contrat, en attente de l'avis de Clément
Elles sont dans `nouvelles_animations_2026-11-27.mp4`, contrôlées (coudes, poignets, mains hors du corps, pieds au sol), et ne sont pas publiées. Après le oui de Clément, il faut publier, poser, puis ajouter une ligne au contrat pour Cantin.

| Animation | Pour | Où dans le code | Rang |
| --- | --- | --- | --- |
| `Sleep` | joueur AFK (L-439, demande de Clément) | L-439, Ironix à faire | 1 |
| `Collect` | joueur sur la plaque d'argent (oui de Clément le 26/11) | plaque `CollectPad` | 2 |
| `Alert` | vigile qui voit la casse (oui de Clément le 26/11) | poursuite, avant `Run` | 3 |
| `Cheer` | joueur qui rentre avec l'objet ; aussi au marqueur `Land` de la croissance (L-502, L-504) | arrivée en boutique | 4 |
| `Startle` | vendeurs du hub quand une vitre casse | VendorService | 5 |
| Foule `Idle`, `Wave` | foule du braquage (`WitnessCrowd = true`) | WitnessCrowdController | 6 |

## Avec un ID, mais à refaire (après le code de Cantin, ou en retouche)
- `Unbox_Inspect`, `Unbox_Crowbar`, `Unbox_Slam`, `Unbox_Hammer` (v3b : le manche passe dans la tête) : ils attendent le poseTool de Cantin (L-508).
- Vigiles `PickUp` (le policier a le même) : poignet à 125°.
- Témoins `CallPolice` : coude à 152°.
- Témoins `Idle` et `Look`, foule `HoldSign` : poignets entre 64 et 69°.

## Les 3 premières, avec le découpage des poses
Les poses viennent des générateurs, à 30 images par seconde.

**1. `Sleep`.** Boucle de 4 s (120 images), priorité Idle, debout et affalé, bras qui pendent. Marqueur `Snore` aux images 4 et 74 : les ZZZ du chef VFX montent dessus.
- image 0 : buste penché à −6°, tête baissée à −22° ;
- image 14 : il inspire, les épaules s'ouvrent ;
- image 40 : il expire et la tête tombe (−32°) ;
- image 56 : il inspire, la tête tombe encore (−40°) ;
- image 64 : −44°, au bord de s'endormir ;
- image 70 : il sursaute, la tête se relève d'un coup (−14°) ;
- image 84 : il inspire ;
- images 104 à 120 : retour à la pose de l'image 0.

**2. `Collect`.** 0,6 s (18 images), sans boucle, priorité Action, haut du corps seulement. Marqueur `Collect` à l'image 10 : le son « kaching ».
- image 0 : repos ;
- image 5 : buste penché, les deux bras tendus vers les billets, épaules à 55° ;
- image 10 : il ramène les billets vers lui, coudes à 95° ;
- image 13 : poing droit serré et levé (coude à 115°), buste redressé ;
- image 18 : repos.

**3. `Alert` (vigiles).** 0,5 s (15 images), sans boucle, priorité Action. Marqueur `Alert` à l'image 5 : le sifflet. Le code enchaîne ensuite `Run`.
- image 0 : repos ;
- image 3 : sursaut, buste en arrière, bras écartés ;
- image 7 : il se tourne de 12° vers la vitrine et la montre, bras droit tendu à l'horizontale ;
- image 15 : il tient la pose.

## Pour Cantin, après la publication (lignes de contrat proposées)
- `Animations.Player` :
  - `Sleep` : boucle, priorité Idle, marqueur `Snore` ;
  - `Collect` : sans boucle, Action, `UpperBodyOnly`, marqueur `Collect` ;
  - `Cheer` : sans boucle, Action.
- `Animations.Guard` : `Alert`, sans boucle, Action, marqueur `Alert`.
- `Animations.Vendor` : `Startle`, sans boucle, Action, `UpperBodyOnly`.
- `Animations.Crowd` : `Idle` (boucle, priorité Idle) et `Wave` (sans boucle, Action, marqueur `Top`).
