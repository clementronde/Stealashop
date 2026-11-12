# UI_PawnShop : le receleur (DEV-034), v2 en dialogue avec le vendeur (2026-11-12)

Clément a refusé la grille d'objets (v1) : le receleur est un stand tenu par un humain.

- Il parle dans une bulle, et propose trois choix : vendre l'objet tenu en main, vendre tout l'inventaire, ou ne rien faire et partir.
- Sa référence : la capture d'un jeu, avec le vendeur qui dit « Got anything to sell? » et des choix numérotés.
- La maquette v2 est faite, **en attente de sa validation**. La version grise dans Studio vient après. Rien n'est commité.

## Maquettes (Figma)

- Aperçu jouable en Edit, dans la vraie scène : `tools/clement/pawnshop_preview.luau` (caméra devant le stand). À lancer quand Studio n'est pas en Play.
- PC, les 3 choix : https://www.figma.com/design/fXjkvf39sRhlsL94YicwDH?node-id=92-1382
- PC, la confirmation : https://www.figma.com/design/fXjkvf39sRhlsL94YicwDH?node-id=92-1416
- Téléphone : https://www.figma.com/design/fXjkvf39sRhlsL94YicwDH?node-id=93-1468
- Noms : https://www.figma.com/design/fXjkvf39sRhlsL94YicwDH?node-id=94-1398
- La v1 en grille (`89:1462`, `89:2015`, `89:2392`, `90:1382`) est marquée « remplacée ».

## Noms proposés (une ligne par élément ; T.n = ligne n de `docs/claude/notes/ui-motion-skilltree.md`)

1. `ReplicatedStorage/Assets/UI/BB_PawnTalk` (BillboardGui, `AlwaysOnTop`) : le code le pose au-dessus de la tête de `Workspace/Map/Hub/Stalls/ENV_Hub_PawnStall/Vendor_Pawn`.
   - **Style de la référence de Clément (2026-11-12) : texte blanc sans fond, avec un contour noir.** Il ne contient que `Line`, la réplique du vendeur, écrite par le code ;
   - à chaque nouvelle réplique, le texte fait un pop (T.35).
2. `StarterGui/UI_PawnShop` (ScreenGui caché, `ScreenGroup=Menu`) : s'ouvre quand le joueur entre sur le `ShopPad` du stand (tag `PawnShop`, déjà posé). Il se ferme quand le joueur quitte le pad, ou par `LeaveButton`.
3. `Dialog.Choices.SellHeldButton` :
   - **texte blanc sans fond**, comme les autres choix : `KeyLabel` « 1. », `ChoiceLabel` « Sell the item in my hand » et `Price` en vert `5cff4a` (120 × $/s de l'objet tenu) ;
   - il est grisé si le joueur ne tient pas d'objet (rien, ou un outil). Le vendeur dit alors « You're holding nothing, pal. ».
4. `Dialog.Choices.SellAllButton` : `KeyLabel` « 2. », `ChoiceLabel` « Sell my whole inventory » et `Price` (le total des objets de l'inventaire, sans ceux qui sont exposés).
5. `Dialog.Choices.LeaveButton` : `KeyLabel` « 3. » et `ChoiceLabel` « Nevermind ». Il ferme l'écran ; le vendeur dit « Come back anytime! ».
6. `Dialog.Choices.DealButton` (« Deal! » et `Price`) et `NoDealButton` (« No way »), cachés : ils remplacent les 3 choix dans deux cas.
   - L'objet tenu est Épique ou plus : « A Mythic? I'll give you $1.44M. Deal? ».
   - Le joueur vend tout l'inventaire : « 9 items for $2.1M. Deal? ».
   - `NoDealButton` ramène les 3 choix.
7. Vente faite :
   - le vendeur dit « Pleasure doing business! » ;
   - animation T.33 `Success`, puis « +$X » au-dessus du joueur (`BB_Gain`, `GainKind = Cash`, T.36), et l'argent sursaute et défile (T.38, T.15).
8. Animations :
   - les choix arrivent un par un (T.27) ;
   - survol : le texte grossit (× 1,06 en 0,08) et passe en jaune `fff36b` (T.49) ; appui et relâché : T.31 et T.32 ;
   - choix grisé : texte `9aa3b5` ;
   - refus du serveur : T.18 ;
   - touches 1, 2 et 3 sur PC.
9. Téléphone : choix de 46 px de haut, à droite de l'écran, au-dessus du bouton de saut.

## À trancher par Clément

- Les répliques du vendeur : les textes ci-dessus sont des propositions, le doc dit seulement que ses répliques donnent le ton humoristique du jeu.
- Faut-il confirmer « tout l'inventaire » à chaque fois, ou seulement s'il contient un objet Épique ou plus ? La proposition est : à chaque fois.
