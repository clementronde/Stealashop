# Le prompt Claude Design qui a donné l'Exclusive Crate

Relevé le 2026-11-21 dans le projet Claude Design « Exclusive Crate Model » de Clément (fichier `Exclusive Crate v2.html`). C'est le seul prompt 3D déjà validé : les prompts du skill partent de lui.

## Le prompt (mot pour mot)

```
Model this "Exclusive Crate" for a Roblox game, following the attached model sheet as the exact visual reference: same silhouette, proportions, colors, materials and part layout. Follow the hero 3/4 render and the front view if anything disagrees.

Size: 4.5 wide × 3.4 deep × 4.2 high studs (1 unit = 1 stud), crystals included.

Separate parts, named in English PascalCase: Body, FlapL, FlapR (the two halves of the arched lid, each with its pivot on its hinge side so they can swing open left and right), Tint, Mark, Medallion, Lock, Keyhole, Frame (all gold edges, corner caps and rivets), Crystals, NeonRed, NeonOrange, NeonYellow, NeonGreen, NeonBlue, NeonPurple.
- Tint is the glowing seam between lid and body: ONE single solid color (white #FFFFFF), because the game recolors it by rarity. It is not rainbow.
- The two thin rainbow bands are made of the six Neon parts, each one flat solid color.
- Every glowing part (Neon parts, Tint, Mark, Keyhole) is its own piece in one flat color, so Roblox Studio can switch it to the Neon material.

Studs: do NOT model them. Keep all big purple faces of Body, FlapL and FlapR flat and smooth; we apply a square-studs texture in Roblox.

Low-poly: 1,500 triangles maximum for the whole crate. Rivets are small cubes. Cylinders and the medallion 12 sides maximum. Crystals simple faceted shapes.

Pivot at the bottom center, base flat on the ground (y = 0), front face (the "?") toward −Z.

Do not include: any character, text or logo other than the "?" shape, a floor or pedestal, lights, particles or animation baked into the mesh.

Export: one single .glb file, one object, flat solid-color materials.

And the Roblox VFX pack of this entire crate, with effects and VFX.
```

## Ce que Claude Design a répondu (résumé)

- Il faut joindre la planche **dans le formulaire** : au premier envoi, elle n'était pas passée, et il l'a redemandée.
- Résultat : 1 390 triangles, exactement 4,5 × 3,4 × 4,2 studs, base à y = 0, face avant vers −Z.
- On récupère le fichier avec **« Download GLB »** dans la visionneuse. Le pack VFX arrive à part, en script Lua (`ExclusiveCrateVFX v2.lua`, non testé par Claude Design).
- Il a regroupé certaines pièces : `Frame` est devenu `FrameBody`, `FrameL` et `FrameR`, et `Crystals` est devenu `CrystalPink` et `CrystalCyan`, pour garder une couleur par pièce.
- À l'import dans Studio : choisir **Studs** comme unité.
- Une retouche a été demandée ensuite : le « ? » en une seule pièce.

## Ce qu'on en garde pour le skill

1. Commencer par « following the attached model sheet as the exact visual reference », puis dire quelle vue l'emporte en cas de désaccord.
2. Écrire explicitement « Studs: do NOT model them » et garder les grandes faces planes.
3. Donner des règles low-poly concrètes : nombre de côtés des cylindres, rivets en petits cubes, cristaux à facettes simples.
4. Chaque partie qui brille est une pièce à part, d'une seule couleur.
5. Le préfixe `Neon` sans tiret bas (`NeonRed`) marche aussi : `appliquer-da.luau` accepte `Neon*` et `Crystal*`.

Note : la page affiche « Claude Design is moving on December 14 ». Les projets doivent passer dans Claude ; à surveiller pour le skill.
