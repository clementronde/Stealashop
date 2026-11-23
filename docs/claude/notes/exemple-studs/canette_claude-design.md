# Canette de soda, version maillage (Claude Design, comme l'Exclusive Crate)

Nom : `ITM_Z1_CanetteDeSoda` (variante d'essai : `ITM_Z1_CanetteDeSoda_Studs`). Rareté Commun, budget 2 000 triangles (10.2).

Même construction que `BOX_Shop_ExclusiveCrate` : des MeshPart séparées, le **corps** reçoit le matériau `Studs` dans Studio (Plastic + MaterialVariant `Studs`), le **cadre** reste lisse en couleur unie (or `#FFC21A` sur le colis), le néon sur des pièces à part, et le contour noir vient du Highlight `OutlineHighlight` posé dans Studio.

```
Roblox game item "Soda Can" for a cartoon shop-robbery game, displayed on a shop pedestal. Same style as our Exclusive Crate: chunky Roblox "studs mode" low-poly, thick blocky silhouette, crisp edges with only tiny bevels, no realism, no thin parts, readable at 40 studs and as a 64 px icon.

Size: 1.0 x 1.0 x 1.6 studs (width x depth x height). 1 unit = 1 stud.

Separate mesh parts, named:
- Body: the can body, a 12-sided prism, 0.875 wide, 1.125 tall, flat faces (it will get a Roblox studs texture in Studio, so keep faces large and flat). Color #E8413C.
- Band: a slightly wider ring around the middle of the body, 0.9 wide, 0.375 tall, flat faces. Color #F5F7FA.
- RimBottom and RimTop: thick chunky rims at the bottom and top, 1.0 wide, 0.25 tall each, like the gold frame of our crate. Color #FFC21A.
- Tab: a chunky pull tab on top, 0.375 x 0.25 x 0.125. Color #C9CFD8.
- Root: a simple box at the base, 1.0 x 1.0 x 0.1, hidden in game.

Colors are flat solid colors, one per part, no textures, no logo, no text.
Triangle budget: 2,000 max (aim for under 600).
Pivot at bottom center, base flat on the ground (y = 0), front facing -Z.
Do not include: lights, particles, ground, pedestal, character, outline mesh.
Export: one .glb file, one object, solid-color materials.

And the Roblox VFX pack of this entire soda can, with effects and VFX.
```

À vérifier à l'œil quand le modèle sort : la canette reste trapue et nette de loin, et le corps a de grandes faces planes pour les studs.
