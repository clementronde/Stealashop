---
name: modele-da
description: Crée un modèle 3D de Steal a Shop dans la DA du jeu (style Exclusive Crate : studs sur les grandes faces, cadre lisse, rareté par ajouts). Pour un objet demandé, écrit la planche ChatGPT puis le prompt Claude Design avec le bloc de style validé, contrôle chaque résultat avec la grille, applique la DA dans Studio et range le modèle. À utiliser dès que Clément demande un nouvel objet, une créature ou une variante.
---

# Modèles dans la DA de Steal a Shop

> **BROUILLON.** Ce fichier est dans `docs/claude/notes/skill-modeles/`. Il ne passera dans `.claude/skills/modele-da/` qu'une fois le bloc de style validé sur les 3 familles de formes (journal du README). Les parties « à remplir » attendent les résultats des tours.

## 1. Les règles de Clément

1. Un objet qu'on a envie d'avoir dans sa base : tendance, pour les enfants, sans marque ni personnage existant.
2. Le style est celui de l'Exclusive Crate : studs sur les grandes faces, cadre lisse sur les bords, contour noir, couleurs franches.
3. La rareté se voit aux ajouts (cadre de la couleur de la rareté, néon, or et cristaux), pas à plus de détails.
4. *(à remplir : ce que Clément refuse, appris pendant les tours)*

## 2. Méthode

1. Fiche de l'objet : nom, ItemId, rareté, zone, taille en studs, pièces.
2. Planche ChatGPT : prompt = sujet + **bloc de style validé** + mise en page de la planche. Joindre la référence du colis et les 2 modèles validés les plus proches.
3. Contrôle de la planche avec la grille (16 sur 20, sans aucun 0). Au plus 3 essais.
4. Claude Design : prompt = sujet + bloc de style + pièces nommées + règles techniques. Joindre la planche.
5. Contrôle du `.glb` : taille, triangles, noms.
6. Import, puis `appliquer-da.luau`, puis capture à côté du colis.
7. Montrer à Clément de face et de trois quarts, avec la note. Dire ce qui n'est pas vérifié.

## 3. Le bloc de style validé

*(à remplir : la version gagnante de `style-vN.md`, mot pour mot)*

## 4. Les gabarits par famille

*(à remplir : objet simple, créature, objet très rare. Pièces, proportions et pièges de chaque famille)*

## 5. Les noms de pièces et ce que Studio en fait

Voir `tour-01.md` : `Body*` en studs, `Frame*`, `Accent*` et `Face*` lisses, `Neon_*`, `Crystal_*`, `Root`.

## 6. La grille

Voir le README de l'atelier (10 critères sur 20).

## 7. Exemples validés

*(à remplir : pour chaque modèle validé, le prompt final, la planche et la capture)*

## 8. Ce qui ne marche pas

*(à remplir : les formulations qui ont donné de mauvais résultats, et pourquoi)*
