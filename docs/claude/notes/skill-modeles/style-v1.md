# Bloc de style v1 (2026-11-21)

Tiré du `BOX_Shop_ExclusiveCrate` (Claude Design) : 19 MeshPart, corps et rabats en Plastic + `Studs` violet, cadre lisse or `#FFC21A`, bandes de néon, cristaux translucides, contour noir. À coller **tel quel** dans les deux prompts (planche et 3D). On ne modifie jamais une version : on écrit `style-v2.md`.

## Le bloc (en anglais)

```
STYLE — "Steal a Shop" chunky Roblox toy style, same family as our Exclusive Crate (reference image attached):
- Built like a premium Roblox crate: one big, simple, chunky main volume with LARGE FLAT FACES, wrapped by a thick SMOOTH FRAME on its edges and rims (like the gold frame of the crate). Small bevels on the frame only. Crisp, clean edges.
- The large flat faces of the main volume carry the classic Roblox STUDS texture (square stud tiles in relief). The frame, small details and faces are smooth, no studs.
- Exaggerated toy proportions: short, wide, sturdy. Nothing thin: no sticks, wires, strings, sharp spikes or tiny parts. Thin real-world parts are made thick and chunky.
- Creatures are chibi: head about half of the total height, small body, short stubby legs, simple cute face (two black rounded-rectangle eyes with a small white highlight, small mouth), no fur or hair strands, body made of a few big rounded blocks.
- 3 to 5 flat, saturated colors. No gradients, no photo textures, no text, no logo.
- Rarity is shown by add-ons, not by more detail: Common and Uncommon = the object alone; Rare = frame in the rarity color; Epic = plus one glowing neon strip; Legendary and above = gold frame #FFC21A, neon strips and translucent crystals, like the Exclusive Crate.
- Rarity colors: Common #B0B7C3, Uncommon #2FE08F, Rare #2F9BFF, Epic #A855F7, Legendary #FFC21A, Mythic #FF3B5C.
- Rendered like a cartoon game asset: thick black outline around the silhouette, soft studio light, plain light background.
- Must read instantly at 40 studs away and as a 64 px icon.
```

## Pourquoi chaque ligne (pour régler les versions suivantes)

| Ligne | D'où elle vient | Ce qu'on surveille |
| --- | --- | --- |
| Volume + cadre lisse | `Body` en studs et `FrameBody` lisse du colis | Si le modèle sort sans cadre, renforcer : « the frame is mandatory » |
| Studs sur les grandes faces seulement | Le colis n'en met que sur `Body` et `Shell` | Studs partout, ou nulle part |
| Rien de fin | Règle des colis (0,15 stud minimum) | Anses, pailles, oreilles, pattes trop fines |
| Créatures chibi | Ce qui plaît le plus sur Roblox (pets, œufs) | Visage trop réaliste, trop de détails |
| Rareté par ajouts | L'œuf Angel et l'Exclusive Crate | Un Commun avec du néon, un Légendaire sans or |
| Cadre de la couleur de la rareté (Rare) | Proposition, à valider | Si ça fait trop chargé, cadre neutre jusqu'à Épique |
| Contour noir | `OutlineHighlight` du colis | Ce n'est qu'un rendu : dans le maillage, pas de contour (Studio le pose) |
