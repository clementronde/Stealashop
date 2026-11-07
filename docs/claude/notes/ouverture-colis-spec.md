# Ouverture des colis v2 · pour Ironix (UI-004, DEV-050, DEV-052)

**Statut : validé par Clément le 2026-11-07** (« c'est juste parfait »), prototype v5 avec ses réglages par défaut.

- Prototype : https://claude.ai/artifact/Cjekv4Jxow7Dkeonb1xio1 (privé : Clément doit le partager au compte d'Ironix, comme L-034). « Copier les réglages » donne toutes les valeurs en JSON.
- Écran : `StarterGui/UI_Unbox` v2 posé le 2026-11-07 dans la place DEV, sans script. Il reste compatible avec le branchement actuel (DEV-021) : `Rarity`, `ItemName`, `Income`, `ContinueButton` et `ItemPreview` sont les mêmes instances ; les ajouts sont cachés au repos.

## Séquence validée

Temps comptés depuis l'appui sur l'invite « Open » (aujourd'hui « Ouvrir » dans UnboxController, à passer en anglais). Version complète = Rare et plus (`FullReveal`), courte = Commun et Peu commun. Toutes les durées sont des paramètres (`Config`).

0. **Amélioration du colis (nouvelle règle, à tirer par le serveur à `OpenBox`)** : jusqu'à `upMax` = 2 crans ; chaque cran réussit avec `upChance` = 10 % × chance du joueur (×1 ; aucune source de chance n'existe encore). Exemple : Commun → Peu commun → Rare. Chaque cran dure `upStep` = 0,9 s :
   - une charge de `upCharge` = 0,5 s, où le colis tremble de plus en plus et une lueur de la rareté suivante monte ;
   - puis le cran : `Upgrade` apparaît au-dessus du colis (`UpgradeLabel` « UPGRADE! » et `UpgradeRarity`, par exemple « UNCOMMON », à la couleur de la nouvelle rareté), le colis grossit d'un coup, son `Tint` change de couleur, une onde et 22 confettis partent, le perso fait un petit saut.

   L'ouverture vient 0,45 s après le dernier cran. Le contenu suit la rareté finale.
1. **Ouverture** : `Unbox` est joué. Au marqueur `Open` (secours : 0,45 s), le couvercle saute et un faisceau de lumière de la rareté sort du colis. `Backdrop` assombrit la scène à 35 % en version complète, pas du tout en courte.
2. **Rouleau** (`Reel`) : une fenêtre juste au-dessus du colis, où l'on ne voit **qu'un objet à la fois, tout noir**.
   - Le code fait descendre des clones `ITM_*` dans `ReelView` (ViewportFrame transparent, `ImageColor3` noir = silhouettes) : les suivants arrivent par le haut et ressortent par le bas. Une case = un objet.
   - `ReelGlow` prend la couleur de rareté de l'objet au centre, en fondu entre deux objets.
   - Les objets sortent du colis en 0,4 s, puis défilent pendant 3,2 s (courte : 1,3 s) : 24 objets (courte : 10). Accélération 0,25 s, freinage p = 4 (formule plus bas). Les objets tournent sur eux-mêmes à 0,15 tour/s.
   - Un « tic » sonne à chaque objet. À partir de Rare, sous 3,5 objets/s, un battement de cœur toutes les 0,55 s.
3. **Frôlement** (40 %) :
   - l'objet juste **avant** le gagnant est d'une rareté plus haute, que ce colis peut donner ;
   - le rouleau hésite à 45 % d'un cran, l'objet rare encore à moitié visible en bas ;
   - puis le dernier cran (0,3 s, Back Out) pose le gagnant au centre.

   Fausse joie : coupée. Sans frôlement, l'arrêt tombe juste avant le centre et le dernier cran cale l'objet.
4. **Arrêt** : pause de 0,25 s, puis l'objet prend ses couleurs en 0,3 s (`ReelView.ImageColor3` du noir au blanc).
5. **Éclat** :
   - `Flash` pendant 100 ms ;
   - l'objet vient devant le joueur en 0,45 s (InOut Cubic, vers `ItemPreview`, ×1,3) ;
   - `Rays` grandissent puis tournent à 0,06 tour/s, à la couleur de la rareté ; Secret : `Rays.Rainbow` ;
   - confettis : éclat de 16 / 30 / 46 / 70 / 90 / 120 morceaux de Peu commun à Secret, pluie plein écran à partir d'Épique ;
   - Légendaire et plus : `Celebrate` et annonce au serveur ;
   - Secret : ralenti ×0,3 pendant 0,5 s et musique.
6. **Textes** :
   - `Rarity` claque (échelle 2,3 → 1, Back Out 0,3 s) ; Secret : texte blanc et `Rarity.Rainbow` ;
   - `ItemName` suit à +0,18 s ;
   - `Income` à +0,12 s : le revenu défile de 0 à sa valeur en 0,9 s (courte : 0,45 s), courbe 1 − (1 − u)³, puis un « cha-ching ».
7. **Boutons**, 0,35 s après le revenu : `ContinueButton` (« CONTINUE »), et `OpenNextButton` (« OPEN NEXT ») si un autre colis est prêt. Ce second bouton n'est possible que si le serveur accepte d'ouvrir l'autre établi à distance.

**Passer** : `SkipButton` (plein écran, avec son texte « TAP TO SKIP ») est visible pendant le rouleau. Un toucher amène le rouleau sur le gagnant en 0,4 s ; pendant les textes, tout s'affiche d'un coup.

**Durées obtenues** :

| Version | Objet révélé | Bouton |
| --- | --- | --- |
| Complète | 4,9 s | 6,7 s |
| Courte | 3,0 s | 4,4 s |

Chaque cran d'amélioration ajoute 0,9 s.

## Formule du rouleau

```lua
-- position (en objets) au temps t d'un défilement de durée T ; Ta = accélération, p = freinage, L = distance
local function rollPos(t: number, T: number, Ta: number, p: number, L: number): number
	Ta = math.min(Ta, T * 0.5)
	local Td = T - Ta
	if t <= 0 then return 0 end
	if t >= T then return L end
	local D = L / (1 + 0.5 * p * Ta / Td)
	if t < Ta then return 0.5 * (D * p / (Td * Ta)) * t * t end
	return 0.5 * D * p * Ta / Td + D * (1 - (1 - (t - Ta) / Td) ^ p)
end
```

Pic d'environ 28 objets/s. Le rouleau passe sous 3 objets/s pendant les 1,4 dernières secondes : c'est le suspense.

## Composer le rouleau

- Chaque objet : rareté tirée avec `Rarities.BoxOdds[type]`, puis un objet au hasard parmi ceux de (zone, rareté). Le gagnant vient de `UnboxReveal` et se place à l'index W ≈ 3 + 24 ; l'objet de frôlement va en W − 1.
- Le rouleau ne démarre qu'avec `UnboxReveal` reçu. Le serveur décide de l'amélioration et de l'objet avant que le rouleau tourne.
- Dans `ReelView`, trois clones suffisent à la fois (le visible, celui qui entre, celui qui sort), avec une caméra fixe. Enlever les scripts des clones.

## Ce que le code anime dans `UI_Unbox`

- `Backdrop` : transparence de 1 à sa valeur (0,65).
- `SkipButton` et `Reel` : `Visible`.
- `Upgrade` : position au-dessus du colis (WorldToViewportPoint), `Visible`, échelle.
- `UpgradeRarity` : texte et couleur ; Secret : `UpgradeRarity.Rainbow`.
- `ReelGlow.BackgroundColor3` ; `ReelView` : modèles, caméra, `ImageColor3`.
- `Rays` : `Rotation`, `ImageColor3`, taille.
- `Rarity`, `ItemName`, `Income` : textes et échelle.
- `ItemPreview` : le ViewportFrame actuel.
- Boutons : `Visible` et échelle.
- `Confetti` : clones de `Confetti.Template`.
- `Flash` : transparence.

Le code ne change ni les tailles, ni les images, ni les couleurs choisies par Clément, sauf celles qui suivent les données (rareté).

## Sons

Noms proposés dans `Assets/Sounds` ; leur choix relève de DEV-051.

| Son | Moment |
| --- | --- |
| `Unbox_UpgradeCharge` | charge d'un cran (souffle qui monte) |
| `Unbox_UpgradePop` | cran d'amélioration (arpège qui monte, plus aigu à chaque cran) |
| `Unbox_Open` (existe) | marqueur `Open` |
| `Unbox_Whoosh` | apparition du rouleau |
| `Unbox_Tick` | chaque objet au centre (plus aigu pour un objet rare ; 35 par seconde au plus) |
| `Unbox_Riser` | pendant le rouleau, Rare et plus |
| `Unbox_Heartbeat` | sous 3,5 objets/s, Rare et plus |
| `Unbox_Stop` | dernier cran |
| `Unbox_Swell` | l'objet prend ses couleurs |
| `Unbox_Reveal_<Rareté>` | éclat : de 2 notes (Peu commun) à la musique du Secret |
| `Unbox_Slam` | la rareté claque (Rare et plus) |
| `Unbox_CountTick`, `Unbox_Cash` | revenu qui défile, fin du comptage |
| `Unbox_Confetti` | confettis |

## Nouveaux noms à ajouter au contrat 2.2 (`UI_Unbox`)

| Chemin | Classe | Rôle |
| --- | --- | --- |
| `Backdrop` | Frame | scène assombrie |
| `SkipButton` | GuiButton | toucher pour passer (caché au repos) |
| `Upgrade`, `Upgrade.UpgradeLabel`, `Upgrade.UpgradeRarity` | Frame, TextLabel, TextLabel | amélioration du colis (caché au repos) |
| `Reel`, `Reel.ReelGlow`, `Reel.ReelView` | Frame, Frame, ViewportFrame | rouleau (caché au repos) |
| `ItemPreview` | Frame | déjà utilisé par le code : à faire entrer au contrat |
| `Rays` | ImageLabel | rayons (provisoires en cadres ; texture de MOD-041 dans `Rays.Image`) |
| `Rarity.Rainbow`, `Rays.Rainbow`, `UpgradeRarity.Rainbow` | UIGradient | arc-en-ciel du Secret (désactivés au repos) |
| `Confetti`, `Confetti.Template` | Frame, Frame (Template) | confettis |
| `Flash` | Frame | flash blanc |
| `OpenNextButton` | GuiButton | « OPEN NEXT » (caché au repos) |

`ContinueButton` est maintenant dans un cadre `Buttons` (avec `OpenNextButton`) : le chemin du contrat reste valable grâce à Contract/Find. Éléments décoratifs : `Glow`, `GlowCore`, `Beam_01` à `_08` (rayons provisoires), `Studs`, `Label`.

## À décider ou à faire

- **Amélioration du colis** : c'est une nouvelle règle, à écrire dans le journal (section 15). Il faut aussi :
  - une source de « chance du joueur » (rien au MVP ; un bonus en Partie 2) ;
  - des valeurs à équilibrer avec Ironix ;
  - savoir si `BB_Box` est mis à jour ou caché pendant l'amélioration.
- **Catalogue** : il faut plusieurs objets par (zone, rareté), sinon le rouleau montre toujours le même objet. En zone 1, il n'y a que des Communs.
- **Textures** (MOD-041) : rayons et halo. Les icônes MOD-040 ne sont plus nécessaires pour le rouleau, qui est en 3D.
- **ContractChecker en Play** : pas lancé, car il faut l'accord de Clément. Le contrôle fait en mode Edit avec `Contract/UI` et `Contract/Find` passe.
