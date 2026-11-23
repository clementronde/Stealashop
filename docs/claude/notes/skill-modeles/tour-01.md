# Tour 1 : prompts (style v1)

Le 2026-11-21. Il y a 3 objets de test, et pour chacun 2 prompts : la planche (ChatGPT) puis la 3D (Claude Design). Chaque prompt est complet, prêt à copier.

Pièce jointe à chaque prompt : la référence du colis, `docs/claude/notes/img/revue-2026-11-20/15_canette_studs_vue_ensemble.jpg` (l'Exclusive Crate est à gauche). Pour Claude Design, joindre aussi la planche validée de l'objet.

Les noms de pièces sont les mêmes pour tous les objets, pour que [appliquer-da.luau](appliquer-da.luau) les reconnaisse :

| Pièce | Rôle | Dans Studio |
| --- | --- | --- |
| `Body`, `Body2`… | Les grandes faces | Plastic + `Studs` |
| `Frame`, `Frame2`… | Le cadre et les bords | SmoothPlastic |
| `Accent`, `Face`… | Les petits détails, le visage | SmoothPlastic |
| `Neon_<nom>` | Ce qui brille | Neon |
| `Crystal_<nom>` | Les cristaux | Glass, transparence 0,1 |
| `Root` | Une petite plaque sous l'objet | Invisible (contrat 10.4) |

---

## 1. Bubble tea (Commun, zone 1)

### Planche (ChatGPT)

```
Create a character turnaround / model sheet for a 3D game item: "Bubble Tea", a common collectible item displayed on a pedestal in a Roblox shop-robbery game for kids.

The item: a chunky bubble tea cup with a domed lid and a thick straw. Milky pink tea, big dark tapioca pearls visible at the bottom through a frosted band, a thick white rim frame around the lid and the base.

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

This item is Common.
Colors: tea #F7A8C8, pearls #3B2A2A, frame and lid #F5F7FA, straw #FF5FA2.

Sheet layout: front view, side view, back view and three-quarter view, same scale and same proportions in every view, on a plain light background. Next to the front view, a simple 5-stud-tall Roblox R15 silhouette for scale; the item is 1.0 x 1.0 x 1.8 studs (width x depth x height). A color palette strip with the hex colors at the bottom. No text on the item itself.
```

### 3D (Claude Design)

```
Make a 3D game model from the attached model sheet: "Bubble Tea", a common collectible item for a Roblox shop-robbery game for kids. Follow the sheet exactly, and the style below.

STYLE — "Steal a Shop" chunky Roblox toy style, same family as our Exclusive Crate (reference image attached):
- Built like a premium Roblox crate: one big, simple, chunky main volume with LARGE FLAT FACES, wrapped by a thick SMOOTH FRAME on its edges and rims (like the gold frame of the crate). Small bevels on the frame only. Crisp, clean edges.
- The large flat faces of the main volume carry the classic Roblox STUDS texture (square stud tiles in relief). The frame, small details and faces are smooth, no studs.
- Exaggerated toy proportions: short, wide, sturdy. Nothing thin: no sticks, wires, strings, sharp spikes or tiny parts. Thin real-world parts are made thick and chunky.
- 3 to 5 flat, saturated colors. No gradients, no photo textures, no text, no logo.
- Must read instantly at 40 studs away and as a 64 px icon.

Size: 1.0 x 1.0 x 1.8 studs (width x depth x height). 1 unit = 1 stud.
Separate mesh parts, each one solid color, named exactly:
- Body: the cup, a 12-sided prism with large flat faces (it gets the Roblox studs texture in Studio). #F7A8C8.
- Frame: the thick white rim at the base and the band under the lid, small bevels. #F5F7FA.
- Frame2: the domed lid. #F5F7FA.
- Accent: the tapioca pearls, big chunky spheres partly sunk into the bottom of the cup. #3B2A2A.
- Accent2: the thick straw, at least 0.18 studs wide, slightly tilted. #FF5FA2.
- Root: a flat box under the base, 1.0 x 1.0 x 0.05, hidden in game.
Do not model the studs: they come from the Roblox material. Do not model an outline mesh.
Triangle budget: 2,000 max, aim for under 600.
Pivot at bottom center, base flat on the ground (y = 0), front facing -Z.
Do not include: lights, particles, ground, pedestal, character.
Export: one .glb file, one object, solid-color materials.

And the Roblox VFX pack of this entire bubble tea, with effects and VFX.
```

---

## 2. Capybara en peluche (Commun, zone 2)

### Planche (ChatGPT)

```
Create a character turnaround / model sheet for a 3D game item: "Capybara Plush", a common collectible plush toy displayed on a pedestal in a Roblox shop-robbery game for kids.

The item: a super cute chibi capybara plush sitting down, round and chubby, tiny ears, a big flat snout, small stubby legs, a sleepy happy face, a small orange on its head (the famous capybara meme), a smooth cream belly patch.

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

This item is Common. For a creature, the "frame" is a thick smooth band: the cream belly patch, the snout and the paws are smooth; the back and the top of the head are the large flat studded faces.
Colors: body #B7834F, belly and snout #F2D9A6, eyes #1E1E1E, orange #FF9F1C.

Sheet layout: front view, side view, back view and three-quarter view, same scale and same proportions in every view, on a plain light background. Next to the front view, a simple 5-stud-tall Roblox R15 silhouette for scale; the plush is 1.4 x 1.6 x 1.5 studs (width x depth x height). A color palette strip with the hex colors at the bottom. No text on the item itself.
```

### 3D (Claude Design)

```
Make a 3D game model from the attached model sheet: "Capybara Plush", a common collectible plush toy for a Roblox shop-robbery game for kids. Follow the sheet exactly, and the style below.

STYLE — "Steal a Shop" chunky Roblox toy style, same family as our Exclusive Crate (reference image attached):
- Built like a premium Roblox crate: big, simple, chunky volumes with LARGE FLAT FACES, and thick SMOOTH bands on the edges. Small bevels only. Crisp, clean edges.
- The large flat faces carry the classic Roblox STUDS texture (square stud tiles in relief). Small details and the face are smooth, no studs.
- Chibi creature: head about half of the total height, small body, short stubby legs, simple cute face, no fur or hair strands, body made of a few big rounded blocks. Nothing thin.
- 3 to 5 flat, saturated colors. No gradients, no photo textures, no text, no logo.
- Must read instantly at 40 studs away and as a 64 px icon.

Size: 1.4 x 1.6 x 1.5 studs (width x depth x height). 1 unit = 1 stud.
Separate mesh parts, each one solid color, named exactly:
- Body: the back, sides and top of the head, chunky blocks with large flat faces (they get the Roblox studs texture in Studio). #B7834F.
- Frame: the belly patch, the snout and the four stubby paws, smooth, small bevels. #F2D9A6.
- Face: the two eyes (black rounded rectangles) and the small mouth, slightly raised. #1E1E1E.
- Accent: the small orange on the head, a chunky 12-sided ball with a leaf. #FF9F1C.
- Root: a flat box under the base, 1.2 x 1.2 x 0.05, hidden in game.
Do not model the studs: they come from the Roblox material. Do not model an outline mesh.
Triangle budget: 2,000 max, aim for under 800.
Pivot at bottom center, base flat on the ground (y = 0), the face looking toward -Z.
Do not include: lights, particles, ground, pedestal, character.
Export: one .glb file, one object, solid-color materials.

And the Roblox VFX pack of this entire capybara plush, with effects and VFX.
```

---

## 3. Œuf de dragon (Légendaire, zone 5)

### Planche (ChatGPT)

```
Create a character turnaround / model sheet for a 3D game item: "Dragon Egg", a legendary collectible item displayed on a pedestal in a Roblox shop-robbery game for kids.

The item: a big chunky dragon egg standing in a small stone nest, with thick overlapping scale plates, a thick gold frame band around its middle and around the nest rim, glowing neon cracks in the shell, and a few big translucent crystals growing from the nest, exactly like the gold frame, neon strips and crystals of the Exclusive Crate.

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

This item is Legendary.
Colors: egg shell #7B2CFF and #B13CFF, gold frame #FFC21A, neon cracks #FF9F1C, crystals #5FF3FF, nest #8A8F99.

Sheet layout: front view, side view, back view and three-quarter view, same scale and same proportions in every view, on a plain light background. Next to the front view, a simple 5-stud-tall Roblox R15 silhouette for scale; the item is 1.4 x 1.4 x 2.0 studs (width x depth x height), nest included. A color palette strip with the hex colors at the bottom. No text on the item itself.
```

### 3D (Claude Design)

```
Make a 3D game model from the attached model sheet: "Dragon Egg", a legendary collectible item for a Roblox shop-robbery game for kids. Follow the sheet exactly, and the style below.

STYLE — "Steal a Shop" chunky Roblox toy style, same family as our Exclusive Crate (reference image attached):
- Built like a premium Roblox crate: one big, simple, chunky main volume with LARGE FLAT FACES, wrapped by a thick SMOOTH gold FRAME on its edges and rims. Small bevels on the frame only. Crisp, clean edges.
- The large flat faces of the main volume carry the classic Roblox STUDS texture (square stud tiles in relief). The frame, small details and crystals are smooth, no studs.
- Exaggerated toy proportions: short, wide, sturdy. Nothing thin.
- Legendary: gold frame #FFC21A, neon strips and translucent crystals, like the Exclusive Crate.
- No gradients, no photo textures, no text, no logo.
- Must read instantly at 40 studs away and as a 64 px icon.

Size: 1.4 x 1.4 x 2.0 studs (width x depth x height), nest included. 1 unit = 1 stud.
Separate mesh parts, each one solid color, named exactly:
- Body: the egg shell, a faceted egg made of large flat scale plates (it gets the Roblox studs texture in Studio). #7B2CFF.
- Body2: a second set of scale plates for contrast. #B13CFF.
- Frame: the thick gold band around the middle of the egg, small bevels. #FFC21A.
- Frame2: the thick gold rim of the nest. #FFC21A.
- Accent: the stone nest, chunky blocks. #8A8F99.
- Neon_Cracks: the glowing cracks, thick zigzag strips slightly raised on the shell, at least 0.08 studs thick. #FF9F1C.
- Crystal_A, Crystal_B, Crystal_C: three big chunky crystals growing from the nest, 6-sided. #5FF3FF.
- Root: a flat box under the base, 1.2 x 1.2 x 0.05, hidden in game.
Do not model the studs: they come from the Roblox material. Do not model an outline mesh.
Triangle budget: 4,000 max (Legendary), aim for under 1,200.
Pivot at bottom center, base flat on the ground (y = 0), front facing -Z.
Do not include: lights, particles, ground, pedestal, character.
Export: one .glb file, one object, solid-color materials.

And the Roblox VFX pack of this entire dragon egg, with effects and VFX.
```
