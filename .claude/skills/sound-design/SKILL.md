---
name: sound-design
description: Savoir-faire pour choisir, régler et livrer les sons et musiques de Steal a Shop dans Roblox Studio (goûts de Clément, bibliothèque sous licence, mesure sans jouer, écoute par candidats numérotés, hiérarchie des volumes, variations, Audio API). À utiliser dès qu'on cherche, remplace, règle ou livre un son (Assets/Sounds), une musique (Assets/Music) ou qu'on écrit la partie son d'une ligne de liaison.
---

# Sons et musiques de Steal a Shop

Sources : la synthèse des 14 tutos son du 26/11 (`StealAShop-Art/_Vault/VFX/Son_Tutos/_Synthese_son.md`, une fiche par vidéo), la passation son du 25/11, les mémoires `sound-taste-clement`, `listen-audio-without-playing`, `roblox-music-search`. Une règle tirée des tutos reste à valider à l'écoute par Clément.

## 1. Les goûts de Clément (non négociables)

1. **Pas d'aigu, pas de couches** : un seul son par geste, jamais plusieurs empilés. **Pas de note qui monte** pour dire « positif ».
2. **Un son familier de Roblox** (façon « kaching ») plutôt qu'un son original.
3. **Il choisit toujours à l'écoute**, parmi 3 candidats numérotés. On ne livre jamais un son qu'il n'a pas entendu, sauf une V0 marquée comme telle quand il ne peut pas écouter.
4. **Seulement des sons sous licence** : compte `Roblox`, `ProSoundEffects` (partenaire), APM via `APMOfficial`. **Jamais un son mis en ligne par un joueur**, même « vérifié ». IA de bruitage (ElevenLabs…) seulement avec son accord : c'est payant, et la licence est à lire.

## 2. Méthode

1. **Chercher** en Edit : `AssetService:SearchAudioAsync` (`AudioSubType = SoundEffect`, mot-clé, `MaxDuration`). Filtrer `Creator.Name` sur les trois comptes ci-dessus. `search_asset` ne suffit pas.
2. **Mesurer sans jouer** : `AudioPlayer` → `Wire` → `AudioAnalyzer`, plus `AudioFader` (Volume 0) → `AudioDeviceOutput`. Relever la longueur, le début et la fin audibles, le pic, le centre du spectre (`GetSpectrum()`, 0 à 24 000 Hz, cases égales, ≈ 47 Hz) et la part des graves sous 300 Hz. **Écarter** ce qui dépasse ≈ 3 à 4 kHz de centre (sauf un kaching, aigu par nature), ce qui est empilé et ce qui monte.
3. **Faire écouter** : 3 candidats numérotés dans `Workspace/_ECOUTE_<Sujet>` (des `Sound`, sans script). Un `Sound` ne joue pas en Edit (`TimePosition` reste à 0) : Clément écoute en Play solo (il coche `Playing`), ou par une ligne de barre de commande `SoundService:PlayLocalSound(...)` donnée par le Chef de projet. Si son PC n'a pas de son, on pose une V0 et on garde les candidats.
4. **Livrer** : `ReplicatedStorage/Assets/Sounds/<Dossier>/<Nom>` (dossiers existants : `UI`, `Cash`, `Heist`, `Unbox`, `Training`, `Chase`, `Throw`, `Reveal`…), musiques dans `Assets/Music`. On ne renomme jamais un son livré : on change son `SoundId`. Le `Volume` est posé sur le `Sound` ; le code ne le réécrit pas (il le multiplie au plus).
5. **Écrire pour Cantin** : le nom, le dossier, le `Volume`, et ce que le code doit faire (moment, `PlaybackSpeed`, variations, baisse de la musique).

## 3. Règles tirées des tutos (26/11)

**Hiérarchie et mix**
- **Si tout sonne énorme, plus rien ne l'est** : grave et attaque forte seulement pour les grands moments (tuto 01).
- **Quatre étages de volume**, du plus doux au plus fort :
  - petits : `UI_Hover`, `UI_SliderTick`, `Train_Tick`, `Unbox_OddsTick`, `Unbox_Tap`, autour de 0,2 à 0,3 ;
  - moyens : `UI_Click`, `Display_Place`, `Cash_Pad`, `Unbox_TierNote`, `Unbox_Rattle`, autour de 0,5 ;
  - grands : `Cash_Collect`, `Heist_Grab`, `Unbox_Burst`, `Heist_Escape`, autour de 1 à 1,5 ;
  - très grands : `Heist_SafeFlash`, `Unbox_SuperLuck`, autour de 1,5 à 2.

  Entre un son répété et un grand moment, l'écart va de 5 à 10 fois.
- **Navigation < sélection < confirmation** : la navigation dure ≈ 0,17 s et sonne plus bas ; la confirmation dure ≈ 1,2 s, avec plus de grave (tuto 01).
- **Le son qui porte l'info ressort** : jusqu'à +22 dB et 1,3 s, contre 0,1 s pour les clics voisins (tuto 01).
- **Baisser la musique sous un grand moment**, puis la remonter : un `AudioFader` sur la musique, réglé par le code (tutos 01, 09, 12).
- **Portée** : les petits sons sont en 2D ou à portée courte (ils ne s'entendent pas chez les autres joueurs) ; la casse et les alertes portent loin (tuto 09).

**Sons répétés et variations**
- **Jamais le même son identique à la suite** : on tire au hasard parmi 2 à 4 variantes, sans rejouer la précédente (tutos 05, 08, 10). C'est du code de Cantin.
- **Une petite hauteur au hasard** : ±3 à 5 % de `PlaybackSpeed` au plus, **jamais en montée**. Les tutos vont jusqu'à ±14 demi-tons, c'est trop pour Clément (tuto 10).
- **Un son répété reste petit** : court, sans grave, sans une fin qui chevauche le son suivant (tuto 01). Au plus ≈ 12 par seconde.
- **Un tic suit ce qu'on voit** : il part quand une case passe le centre ou quand le chiffre affiché change, jamais à intervalle fixe. Quand ça freine, les tics ralentissent (kit Roll, 26/11).
- **Un seul `Sound` relancé** (`TimePosition` 0 puis `Play`) pour un tic, jamais un clone par tic. Un son recréé par son ID perd le `Volume` et le `PlaybackSpeed` posés sur l'objet (kits Roll et Top Donators).
- **Plusieurs choses arrivent ensemble** (icônes d'argent qui volent, gerbe d'étoiles) : un seul son, à la première arrivée (kit Roll).
- **Son de confirmation** : il part à la réponse du serveur, avec le « +$X », jamais au clic (kit Steal Egg).
- **Survol** : rien au toucher. Si on en met un, il est très bas et sur souris seulement (kits Roll et Steal Egg).
- **Une boucle de grand moment** (roulement, foule) s'éteint par un fondu de volume, de 0,3 s pour un roulement et jusqu'à 2 s pour une ambiance, jamais coupée net (kits Roll et Top Donators).

**Grands moments**
- **Deux éléments au plus**, un grave (le poids) et une matière (l'info), et si possible dans **un seul fichier** (tuto 10).
- **Plus lent = plus grave = plus gros** : `PlaybackSpeed` 0,85 à 0,9 donne du poids sans changer de son (tuto 05).
- **Une queue douce** pour un grand moment, **un arrêt net** pour un geste court (tuto 07). **Un court silence avant** le moment fort (tuto 14).

**Musique**
- **Un son qui a une note** doit jouer dans la tonalité de la musique ; sinon, prendre un son sans note (bruit, souffle) (tutos 02, 03).

**Roblox**
- Chaîne de l'API audio : `AudioPlayer` → `Wire` → `AudioEmitter`, `AudioListener` → `Wire` → `AudioDeviceOutput`. Ils se trouvent par un `AudioInteractionGroup` (tuto 12).
- `GetSpectrum()` donne des niveaux RMS de 0 à 24 000 Hz, à lire en échelle log ; `RmsLevel` > 0,1 = fort (tuto 13).
- SoundGroups (un volume par famille) : aucun tuto n'en parle. À vérifier avec Ironix.

## 4. Pièges vérifiés

- `PlayLocalSound` et un `Sound` coché `Playing` ne jouent rien en Edit ; seul l'`AudioPlayer` relié à un `AudioDeviceOutput` joue en Edit.
- Certains ID ne se chargent pas (`TimeLength` 0) : toujours faire `PreloadAsync`, puis vérifier `IsLoaded` et `TimeLength`.
- « User is not authorized to access Asset » au Play vient souvent d'un son de pack de test resté dans ServerStorage (L-417, 26/11), et non du jeu.
- Les packs du Creator Store cachent des scripts : un son se reprend par son ID, jamais en ouvrant le pack.
- **Vérifier l'auteur d'un son trouvé dans un kit ou un pack** : `MarketplaceService:GetProductInfo(id, Enum.InfoType.Asset).Creator.Name`, en Edit et en lecture seule. Sur 27 sons des kits UIverse (26/11), 11 seulement étaient chez Roblox, ProSoundEffects ou APMOfficial. La liste est dans `_Vault/VFX/Kits_UIverse/_Synthese_kits.md`.
