# Steal a Shop — doc de suivi

Game design et suivi de production du jeu Roblox de Clément (modèles 3D et UI) et Ironix (développement).

**L'état du jeu aujourd'hui** est dans une seule page : « Le jeu aujourd'hui », dans le [doc de suivi partagé](https://claude.ai/artifact/QKsqfJ3YEjFn41GERuTGUx), avec le journal des décisions (Partie 1, section 15). Les valeurs (PV, prix, vitesses, raretés, durées) sont dans `src/shared/Config`, les noms du contrat dans `src/shared/Contract`.

| Document | Contenu |
| --- | --- |
| [CLAUDE.md](CLAUDE.md) | Contexte et règles du projet, lus automatiquement par Claude quand on l'ouvre dans ce dossier |
| [Liaison code ↔ visuel](docs/Liaison-Code-Visuel.md) | Ce que Clément et Ironix attendent l'un de l'autre, tests à faire, registre des animations, contrats qui relient le code et le visuel ; lu par les deux Claude à chaque session |
| [Parcours de Clément](docs/claude/Etapes-Clement.md) | Les tâches de Clément (modèles, UI, animations) étape par étape, avec une consigne à copier dans Claude pour chacune |
| [Partie 1 · MVP](docs/Partie-1-MVP.md) | **Archive** : copie de la Partie 1 du doc partagé (boucle, carte, systèmes, économie, méthode, specs, bible assets, backlogs, journal), gelée le 24/11/2026 |
| [Partie 2 · Features à ajouter](docs/Partie-2-Features-a-ajouter.md) | **Archive** : copie de la Partie 2 du doc partagé (mises à jour prévues après la sortie), gelée le 24/11/2026 |

Les deux fichiers `Partie-*` sont des copies du doc partagé, souvent en retard sur lui, gardées pour l'historique. Ils ne sont plus mis à jour et ne disent plus ce qu'est le jeu : pour cela, lire la section 0 « Le jeu aujourd'hui » (en tête de la Partie 1) du doc partagé ; une nouvelle ligne du journal des décisions s'écrit dans le doc partagé, jamais dans ces copies (décision C4 de Cantin, 24/11).
