# Chevauchements de l'UI : L-133 et L-135 (points 1, 4, 5 et 6), faits le 2026-11-14

Tout est fait en Edit, annulable, sans aucun script dans les écrans. Rien n'est commité.

**Aucun nom lu par le code ne change.** Deux contraintes sont ajoutées, que le code ne lit pas : `UI_Hotbar.Bar.WidthLimit` et `Bar.Template.TouchMin`.

**Mesures** : sur des copies, avec les marges de Roblox (barre du haut de 58 px ; sur téléphone, encoche de 47 px et barre du bas de 21 px). Tailles : 1920 × 1080, 1366 × 768, 844 × 390, plus 1440 × 900, 1280 × 1024 et 940 × 816 (fenêtre de Studio).

**Textes de test** :
- argent « $212B » et « +$52.3K/s » ;
- 3 messages de 65 caractères (« Inventory full: display or sell an item before opening this box. ») ;
- « $52.3K/s » au-dessus de chaque case ;
- « Night in 1:45 ».

## 1. `UI_ZoneBanner` (L-133) : la même taille pour « Speed 22 » et « Damage 40K »

- **Avant** : les deux cases avaient la même largeur, donc le texte le plus long rapetissait (14 px contre 20 px en 1920).
- **Maintenant**, dans `Advice` :
  - les cases sont assez larges pour leur texte le plus long : `RecommendedLabel` 0,30, `Speed` 0,225 (« Speed 12.3B »), `Damage` 0,275 (« Strength 12.3B ») ;
  - les trois font 0,5 de haut, et les icônes 0,75 ;
  - `Speed` et `Damage` sont alignés à gauche, `RecommendedLabel` à droite.
- **Mesuré** : la même taille partout, sur une seule ligne. 18 px en 1920, 15 px en 1366, 11 px sur téléphone (petit, car le bandeau est petit).

## 2. « ESCAPED! » × alerte de vol (L-135 point 1)

- **La cause** : la boîte au-dessus du titre (`BoxIcon`) dépasse de la bannière de 0,5 × sa hauteur. Sous la bannière de l'alerte, la flèche (`Arrow`) et le bouton `Action` occupaient la place de l'arrivée.
- **`UI_TheftAlert.Banner.Arrow`** : passe à **droite** de la bannière, centrée en hauteur (AnchorPoint (0 ; 0,5), Position (1,015 ; 0,5)). `Action` reste sous la bannière.
- **`UI_Escape.Banner`** : AnchorPoint (0,5 ; 0), Position (0,5 ; 0,4134 H + 66), Size (0,42 ; 0,235 H − 32), taille minimale 140 × 54 (au lieu de 300 × 115).
  - Elle descend sous l'alerte et reste au-dessus du message du bas, qui arrive au même moment (« Item secured!… »).
  - Sur PC, elle garde sa taille, environ 0,2 H.
- **Mesuré** : plus aucun contact avec l'alerte (bannière, `Action` et flèche), aux 6 tailles. Pas de contact non plus avec le 1er message du bas.
- **Ce qui reste** :
  - sur téléphone, « ESCAPED! » fait 142 × 54 : titre de 30 px, mais **sous-titre de 9 px**. Avec 2 ou 3 messages en même temps, il touche les messages du dessus ;
  - en 1366, contact de 1 px avec le 3e message.

## 3. Messages du bas `UI_Toast.Stack` (L-135 point 4)

- **Changé** :
  - largeur : 0,27 W + 320 px (0,72 W avant) ;
  - position : 22 px plus haut (0,86 H − 22).
- **Mesuré** :
  - ils ne touchent plus `SocialRow` en 1920, 1366, téléphone, 1440 et 1280 ;
  - ils ne touchent plus les « $/s » des cases sur téléphone ;
  - un message de 65 caractères tient sur une ligne sur téléphone (522 px de large).
- **Ce qui reste** : dans la fenêtre de Studio (940 × 816), le 3e message touche `SocialRow` (44 × 19 px).

## 4. Barre d'objets `UI_Hotbar.Bar` × argent et « Night in » (L-135 point 5)

- **Changé** :
  - `Bar.WidthLimit` (UIAspectRatioConstraint 13,44, le rapport du 16:9, FitWithinMaxSize) : sur un écran moins large que le 16:9, les cases rapetissent ;
  - `Bar.Template.TouchMin` (UISizeConstraint, 44 × 44 au moins) ;
  - `Bar` décalée de 14 px vers la droite.
- **Taille des cases** :

  | Écran | Taille des cases |
  | --- | --- |
  | 1920 × 1080 | 88 px (inchangé) |
  | 1366 × 768 | 62 px (inchangé) |
  | 1440 × 900 | 66 px |
  | 1280 × 1024 | 59 px |
  | Téléphone | 44 px (50 avant, toujours 44 au moins) |

- **Mesuré** : ni les cases ni leur « $/s » ne touchent plus l'argent ni « Night in », à 5 tailles sur 6.
- **Ce qui reste** : dans la fenêtre de Studio, 6 × 4 px entre le « $/s » de la 1re case et le « +$/s » de l'argent.

## 5. Bouton de saut de Roblox (téléphone, L-135 point 6)

- **Changé** :
  - `NightCountdown` : Position X = 1,0214 W − 72 ;
  - `SocialRow` : Position X = 1,0137 W − 66.
  - Les hauteurs ne changent pas.
- **Effet** : sur téléphone (844), ils finissent à 741 px, avant le bouton de saut (749 à 819). Sur PC, ils sont presque à la même place (9 px plus à gauche en 1920, 21 px en 1366).
- **Mesuré** : plus aucun contact avec le bouton de saut.
- **Pas vérifié** : la tablette, dont le bouton de saut est plus grand et placé ailleurs.

## À signaler (pas fait)

Le ContractChecker affiche **76 lignes rouges**, et aucune ne vient de ces écrans.
- Ce sont des scripts dans deux packs du Creator Store posés dans Workspace : `Aura Pack Premium By Sanzzzzz` et `THE ULTRA VFX AND PARTICLES PACK`.
- On y trouve notamment des `TouchDamageScript`, et des scripts `Runtime` / `ScreenBuilder` cachés dans des Beams et des Attachments.
- La règle (CLAUDE.md) : vider de ses scripts tout modèle du Creator Store avant de l'utiliser.
- À faire par Clément : retirer ces packs, ou leurs scripts, avant tout Play.
