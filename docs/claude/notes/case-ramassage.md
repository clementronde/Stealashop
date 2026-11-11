# Case de ramassage « satisfaisante » (CollectPad, L-082) : éléments visuels prêts, à animer par Ironix

Construit par `tools/clement/collect_pad_fx.luau` (sans commit, relançable). Aucun script dans les modèles.

1. **Case en deux parties** : `CollectPad_xx` reste la pièce fixe que le code détecte (cadre doré, `CanTouch`). Sa plaque `Plate` (néon vert, « $ ») est son enfant. L'attribut `SinkDepth` (studs) dit de combien l'enfoncer. Dans `Plate` : l'Attachment `BurstPoint` (3 `ParticleEmitter` éteints, `Sparkles`, `Ring` et `Coins`, chacun avec un attribut `EmitCount`) et la `PointLight` `Glow` éteinte.
2. **Billet et pièce volants** : `ReplicatedStorage/Assets/FX/FX_Collect_Bill` et `FX_Collect_Coin` (Models avec `PrimaryPart`, ancrés, sans collision). Chacun a une `Trail` (`TrailA`/`TrailB`) qui ne dessine qu'en mouvement.
3. **Ce que le code anime, côté client, chez le propriétaire, à l'encaissement d'une case** :
   - Enfoncer `Plate` de `SinkDepth` en 0,06 s (Quad Out), puis la remonter en 0,25 s (Back Out). En même temps, l'écraser un peu (taille XZ ×1,08), puis la remettre.
   - `Emit(EmitCount)` sur chaque émetteur de `BurstPoint`, et allumer `Glow` 0,15 s.
   - Cloner 5 à 12 billets ou pièces selon le montant. Chacun jaillit de la case (0,2 s, vers le haut, au hasard), puis file vers le compteur `UI_HUD.Cash`, en 0,4 à 0,5 s (Quad In), à 0,04 s d'écart. La cible est un point à environ 3 studs devant la caméra, `camera:ViewportPointToRay` au centre du `Cash` à l'écran : le billet rapetisse en y arrivant, puis est détruit.
   - À chaque arrivée, faire pulser `Cash` (échelle 1,15, puis retour) et monter le chiffre (déjà fait par `Roll`).
4. Un son de caisse ou de pièces au moment de l'enfoncement est à prévoir (DEV-051) ; aucun n'est encore posé.
