# Six miniatures faites avec le prompt (MOD-043, 2026-11-25)

Demande de Clément, passée par le chef vidéo : 6 variations avec [prompt_miniatures.md](../prompt_miniatures.md)
(version du commit `10c54d2`). Rien n'est publié ni poussé.

**Méthode** : une conversation ChatGPT par image, dans le Chrome de Clément, avec le prompt complet et la scène sous
`USER REQUEST`. Deux pièces jointes : `ref_tenue_baconhair.png` et l'icône de l'objet (`StealAShop-Art\Items\Icons_V3`).
Les demandes exactes sont dans `chatgpt/demande_<n>.txt`. Finition : `& tools/clement/miniatures/miniatures_prompt_2026-11-25.ps1`.

| Miniature | Moment, lieu | Objet (rareté) | Ajouts |
| --- | --- | --- | --- |
| THUMB_P1_CasseGuitareLA | Vitrine cassée, Los Angeles | Neon Guitar (Épique) | +$1T/s, flèche |
| THUMB_P2_ColisCroissantParis | Colis ouvert, Paris | Croissant Shark (Légendaire) | +$5T/s, « !! » sur le vigile |
| THUMB_P3_FuitePigeonNewYork | Fuite avec deux policiers, New York | Golden Pigeon (Mythique) | +$9T/s, flèche, « !! » |
| THUMB_P4_VolJoueurCapybara | Vol chez un autre joueur, hub | Golden Capybara (Épique) | +$1T/s |
| THUMB_P5_NuitChihuahuaLondres | Nuit, mur et vigiles de nuit, Londres | Diamond Chihuahua (Épique) | +$1T/s, flèche |
| THUMB_P6_EntrainementLingot | Entraînement au banc et tapis, sa boutique | Giant Gold Bar (Rare) | +$1T/s, flèche |

Chaque miniature est en 1920 × 1080 avec `_controle_320x180` et `_controle_zones` ; les 6 ensemble :
[planche_320x180.png](planche_320x180.png). Les valeurs d'argent sont gonflées exprès.

**Ce que le prompt rate** (à corriger dans `prompt_miniatures.md`) :
- Des lettres reviennent sur le décor : la façade de la banque (P3) et « TELEPHONE » sur la cabine (P5).
- La cagoule change de forme : capuche intégrale façon ninja (P1), bandeau et masque bas ailleurs.
- P1 part vers un rendu 3D réaliste au contour fin dès que la boutique est détaillée.
- La boutique du joueur n'est pas décrite : P6 ressemble à une salle de sport rose.
- Sans l'icône jointe, ChatGPT ne connaît pas nos objets : le prompt devrait demander de la joindre.
