# L'équipe d'agents Claude de Clément

Chaque agent est un fichier de `.claude/agents/`. On l'appelle par son nom dans une session ouverte dans ce dossier (« utilise l'agent revue-modeles pour… »). Ses résultats vont toujours dans `docs/claude/` : rien ne reste seulement dans le chat.

| Agent | Rôle | Outils | Il rend |
| --- | --- | --- | --- |
| `ui-studio` | Retouche les écrans dans Studio (alignements, tailles, remise d'une ancienne version), sans script dans l'UI | MCP Roblox_Studio | Captures PC et téléphone, script rejouable dans `tools/clement/`, ligne de liaison |
| `revue-modeles` | Écrit la direction artistique de référence (les colis), puis classe tous les modèles du jeu | MCP Roblox_Studio (lecture) | `notes/DA-reference-colis.md`, `notes/revue-modeles-<date>.md` (lots à refaire) |
| `planches-chatgpt` | Fait générer par ChatGPT les planches de concept d'un lot et les contrôle contre la DA | Claude in Chrome | `planches/<lot>/` (image et prompt de chaque modèle) |
| `prompteur-3d` | Écrit le prompt Claude Design d'un modèle et vérifie le `.glb` reçu | Fichiers, Blender | Prompt prêt à coller, vérification avant import |
| `analyste-video` | Mesure une vidéo de référence d'un autre jeu | ffmpeg | Fiche « comment le refaire » |

## L'ordre d'un chantier de modèles

1. `revue-modeles` : la fiche DA des colis, puis la liste des modèles à refaire, en lots.
2. `planches-chatgpt` : les planches du premier lot, validées par Clément.
3. `prompteur-3d` : un prompt 3D par planche validée, puis la vérification du `.glb`.
4. Import et rangement dans Studio (Clément ou `ui-studio` pour la partie UI), puis la ligne dans la liaison pour Ironix.

## Règles communes

- Lire `CLAUDE.md` et la liaison au début (`git pull`, puis `grep '^| L-0NN '`).
- Ne jamais toucher `src/` ni les dossiers synchronisés d'Ironix ; aucun script dans un modèle ou dans l'UI.
- Tout ce qu'Ironix doit savoir va dans la liaison, poussé dans le même tour, avec l'accord de Clément pour pousser sur `main`.
- Les fichiers d'art bruts (références, planche de style MOD-002) sont sur le PC fixe, dans `StealAShop-Art` ; ce qui doit servir aux deux ordinateurs va dans le dépôt.
