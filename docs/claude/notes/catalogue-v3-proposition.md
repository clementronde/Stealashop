# Catalogue d'objets v3 : proposition (2026-11-21)

Demande de Clément : revoir les objets pour avoir des choses **qu'on a envie d'avoir dans sa base**. Plus de fruits ni de légumes : des objets plus tendance, plus pour les enfants, dans l'air du moment sur Roblox.

Statut : **proposition, rien n'est changé** dans le code, le doc partagé ni Studio. À valider par Clément, puis à passer par Ironix (liaison) avant toute modification de `Items.luau`.

## Ce qui guide le choix

Les tendances relevées le 2026-11-21 :
- **Sur Roblox**, les jeux en tête sont des jeux de vol et de collection d'œufs et de pets (Steal An Egg en premier, Adopt Me!, Steal a Brainrot toujours haut). Les enfants veulent des **créatures mignonnes**, des **œufs**, des choses **brillantes** et des **raretés folles**.
- **Côté jouets**, ce qui marche pour 2026 : les **figurines surprises** (blind box), les objets à collectionner, les peluches, le **retour du rétro** et la déco douillette.

Les règles qui en sortent :
1. **Un objet qui a l'air vivant ou désirable** sur un présentoir : une peluche, une créature, un gadget lumineux, un objet en or. Rien de banal (brique de lait, brocoli).
2. **Des animaux à la mode** : capybara, axolotl, requin, dragon, chat.
3. **Plus c'est rare, plus c'est fou** : en or, en diamant, galaxie, arc-en-ciel, en néon.
4. **Formes simples et trapues**, faciles à faire dans le style de l'Exclusive Crate (studs sur les grandes faces, cadre lisse) : voir [DA-objets-studs-blocs.md](DA-objets-studs-blocs.md).
5. **Aucune marque, aucun personnage existant.** Pas de Labubu, de Pokémon, de K-pop Demon Hunters, de Stanley, ni de personnages « brainrot » d'un autre jeu. Ce sont des objets génériques (« peluche monstre à dents », « gourde XXL »), avec notre propre dessin.

## Ce qui ne change pas

- Les 6 zones et leurs 12 magasins (Mini Mart et Kiosk, Toy Shop et Sweet Shop, Electronics et Video Games, Jewelry et Watches & Clocks, Art Gallery et Antiques, Bank et Vault).
- **Le nombre d'objets par zone et par rareté** (vague 76) : Z1 12 Communs + 1 Rare du tuto ; Z2 8 C, 8 PC ; Z3 5 C, 5 PC, 4 R ; Z4 4 C, 4 PC, 4 R, 3 É ; Z5 3 PC, 3 R, 3 É, 3 L ; Z6 3 R, 3 É, 3 L, 3 M ; 1 Secret. Total : 83. L'équilibrage (revenus, tirages, index) n'a donc pas besoin d'être refait.
- 4 catégories par zone, pour l'étiquette des colis (`BB_Box`).

Abréviations : C Commun, PC Peu commun, R Rare, É Épique, L Légendaire, M Mythique. **Gardé** : l'objet existe déjà en v2 et peut garder son ItemId.

## Zone 1 : Mini Mart et Kiosk (zone tuto, Communs)

| Catégorie | Objet | Nom affiché (EN) | Rareté | Pourquoi |
| --- | --- | --- | --- | --- |
| Boisson (Drink) | Bubble tea | Bubble Tea | C | La boisson star des enfants, perles visibles |
| Boisson | Slushie arc-en-ciel | Rainbow Slushie | C | Couleurs vives, gobelet bombé |
| Boisson | Gourde XXL | Mega Tumbler | C | La gourde géante à la mode |
| Snack (Snack) | Chips piquantes | Spicy Chips | C | Le défi « trop piquant » |
| Snack | Donut géant | Giant Donut | C | Gardé (Donut), en plus gros |
| Snack | Glace arc-en-ciel | Rainbow Ice Cream | C | Cornet à 3 boules |
| Fidget (Fidget) | Pop-it | Pop-It | C | Un pavé à bulles : parfait en studs |
| Fidget | Squishy | Squishy | C | Petite créature toute ronde |
| Fidget | Slime | Slime Jar | C | Un pot de slime fluo |
| Surprise (Surprise) | Sachet surprise | Mystery Bag | C | Le principe de la blind box |
| Surprise | Porte-clés peluche | Plush Keychain | C | Mini peluche à accrocher au sac |
| Surprise | Pack d'autocollants | Sticker Pack | C | À collectionner |
| Snack (tuto seulement) | Ramen de feu | Fire Ramen | R | Remplace le Pot de nouilles, garde son rôle de premier colis |

## Zone 2 : Toy Shop et Sweet Shop (Londres)

| Catégorie | Objet | Nom affiché (EN) | Rareté |
| --- | --- | --- | --- |
| Peluche (Plush) | Capybara en peluche | Capybara Plush | C |
| Peluche | Axolotl en peluche | Axolotl Plush | C |
| Peluche | Requin en peluche | Shark Plush | PC |
| Peluche | Peluche monstre à dents | Toothy Monster Plush | PC |
| Figurine (Figure) | Figurine surprise | Blind Box Figure | C |
| Figurine | Booster de cartes | Card Booster Pack | C (gardé) |
| Figurine | Robot transformable | Transforming Robot | PC (gardé : Robot jouet) |
| Figurine | Dragon articulé | Articulated Dragon | PC |
| Bonbon (Candy) | Ours gélifié géant | Giant Gummy Bear | C |
| Bonbon | Chamallow géant | Giant Marshmallow | C |
| Bonbon | Barbe à papa nuage | Cotton Candy Cloud | PC |
| Bonbon | Machine à bonbons | Candy Machine | PC |
| Jouet (Toy) | Voiture de cascade | RC Stunt Car | C (gardé : Voiture télécommandée) |
| Jouet | Skate lumineux | Light-up Skateboard | C (gardé : Skateboard) |
| Jouet | Blaster à mousse | Foam Blaster | PC |
| Figurine | Carte holographique | Holo Card | PC (gardé) |

## Zone 3 : Electronics et Video Games (Tokyo)

| Catégorie | Objet | Nom affiché (EN) | Rareté |
| --- | --- | --- | --- |
| Gaming (Gaming) | Manette RGB | RGB Controller | C (gardé : Manette) |
| Gaming | Souris gamer | Gaming Mouse | C (gardé : Souris) |
| Gaming | Casque à oreilles de chat | Cat Ear Headset | PC |
| Gaming | Fauteuil gamer | Gaming Chair | R |
| Lumière (Light) | Enseigne néon | Neon Sign | C |
| Lumière | Lampe à lave | Lava Lamp | C |
| Lumière | Projecteur galaxie | Galaxy Projector | PC |
| Gadget (Gadget) | Appareil photo instantané | Instant Camera | C |
| Gaming | PC gamer | Gaming PC | PC (gardé) |
| Gadget | Téléphone pliant | Foldable Phone | R (gardé : Smartphone) |
| Gadget | Casque VR | VR Headset | R (gardé) |
| Gaming | Console portable | Handheld Console | PC (gardé) |
| Robot (Robot) | Robot chien | Robot Dog | PC |
| Robot | Hoverboard | Hoverboard | R |

## Zone 4 : Jewelry et Watches & Clocks (Los Angeles, les stars)

| Catégorie | Objet | Nom affiché (EN) | Rareté |
| --- | --- | --- | --- |
| Baskets (Sneakers) | Baskets montantes | High-Top Sneakers | C (gardé : Baskets de collection) |
| Baskets | Claquettes fourrées | Fluffy Slides | C |
| Baskets | Baskets lumineuses | Light-Up Sneakers | PC |
| Baskets | Baskets en or | Golden Sneakers | É |
| Bling (Bling) | Bracelet d'amitié | Friendship Bracelet | C |
| Bling | Lunettes cœur | Heart Sunglasses | C (gardé : Lunettes de star) |
| Bling | Chaîne bling | Bling Chain | PC (gardé : Chaîne en or) |
| Bling | Bague diamant géante | Giant Diamond Ring | R |
| Star (Star) | Micro de pop star | Pop Star Mic | PC |
| Star | Casquette à strass | Rhinestone Cap | PC |
| Star | Trophée de star | Star Trophy | R |
| Star | Guitare néon | Neon Guitar | É |
| Montre (Watch) | Montre connectée | Smartwatch | R |
| Montre | Montre en or | Gold Watch | R (gardé) |
| Montre | Montre diamant | Diamond Watch | É |

## Zone 5 : Art Gallery et Antiques (Paris, le musée des légendes)

| Catégorie | Objet | Nom affiché (EN) | Rareté |
| --- | --- | --- | --- |
| Fossile (Fossil) | Ambre fossile | Amber Fossil | PC |
| Fossile | Œuf de dino fossile | Fossil Dino Egg | PC |
| Fossile | Crâne de T-Rex | T-Rex Skull | R |
| Art (Art) | Tableau pixel art | Pixel Painting | PC |
| Art | Statue de chat géant | Giant Cat Statue | R |
| Art | Capybara doré | Golden Capybara | É |
| Légende (Legend) | Armure de chevalier | Knight Armor | R (gardé) |
| Légende | Épée dans la pierre | Sword in the Stone | É |
| Légende | Œuf de dragon | Dragon Egg | L |
| Mystère (Mystery) | Momie | Mummy | É (gardé : Sarcophage) |
| Mystère | Masque ancien | Ancient Mask | L (gardé) |
| Mystère | Météorite | Meteorite | L (gardé) |

## Zone 6 : Bank et Vault (New York, l'ultime)

| Catégorie | Objet | Nom affiché (EN) | Rareté |
| --- | --- | --- | --- |
| Or (Gold) | Lingot d'or | Gold Bar | R (gardé) |
| Or | Cochon tirelire en or | Golden Piggy Bank | R |
| Or | Toilettes en or | Golden Toilet | L |
| Diamant (Diamond) | Sac de diamants | Bag of Diamonds | R (gardé) |
| Diamant | Œuf en diamant | Diamond Egg | É (gardé, venu de Z4) |
| Diamant | Diamant galaxie | Galaxy Diamond | M (gardé : Diamant géant) |
| Coffre (Vault) | Valise de billets | Cash Briefcase | É |
| Coffre | Coffre de diamants | Diamond Chest | L (gardé) |
| Coffre | Clé du coffre ultime | Ultimate Vault Key | M (gardé) |
| Ultime (Ultimate) | Trône en or | Golden Throne | É (gardé) |
| Ultime | Couronne cosmique | Cosmic Crown | L |
| Ultime | Dragon de diamant | Diamond Dragon | M |

## Secret

| Objet | Nom affiché (EN) | Remarque |
| --- | --- | --- |
| Chat porte-bonheur doré | Golden Lucky Cat | Gardé (déjà modélisé), validé par Clément le 2026-11-21. Le bébé dragon arc-en-ciel est mis de côté pour un futur Divine. |

## Bilan

- **83 objets**, dont **28 gardés** de la v2 (même ItemId, souvent avec un nouveau dessin et un nouveau nom) et **55 nouveaux**. Choix validé par Clément le 2026-11-21.
- Retirés : tous les fruits et légumes, les boissons et snacks banals, les objets « adultes » (horloges, parfum, collier de perles, Joconde, Penseur, Tour Eiffel, buste, vase, Statue de la Liberté, taureau, aigle).
- Des créatures dans toutes les zones (capybara, axolotl, requin, dragon, chat, robot chien) : c'est ce que les enfants veulent dans leur base.
- Les 83 modèles sont de toute façon à refaire dans le style de l'Exclusive Crate. Changer le catalogue maintenant ne coûte donc pas de modèle en plus.

## Ce que ça demandera ensuite (pas fait)

- Ironix (liaison) : valider, puis mettre à jour la section 10.5 du doc partagé.
- Code : `Items.luau` et `objets-catalogue-v2.json` (passer en v3), la migration des anciens objets des profils (`RetiredV1` / `RenamedV1` à étendre en v3), `Tutorial.GuaranteedItemId` (Ramen de feu), l'ordre de l'index et le banc `a22-core`.
- Modèles : les prompts Claude Design par lots (agent `prompteur-3d`), en commençant par la zone 1.

## Questions pour Clément

1. On garde les 12 magasins tels quels, ou on renomme certains pour coller aux objets (zone 4 « Star Shop », zone 5 « Legends Museum ») ?
2. (Réglé : Secret = Chat porte-bonheur doré.)
3. Tu veux enlever ou ajouter des objets avant que je passe aux prompts de la zone 1 ?

## Sources

- [Classement des jeux Roblox, novembre 2026 (rblxstat)](https://rblxstat.com/lists/most-played-roblox-games)
- [Top 50 du 18 novembre 2026 (endgametools)](https://endgametools.com/en/roblox/charts)
- [Jouets tendance 2026 (ABC News)](https://abcnews.com/shop/story/top-trending-toys-2026/?id=136566666)
- [Tendances de la Toy Fair 2026 (Toy Association)](https://toyassociation.org/PressRoom2/News/2026-News/toy-fair-brings-the-love-and-top-toy-trends-for-2026.aspx)
