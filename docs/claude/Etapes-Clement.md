# Parcours de Clément avec Claude

Les 43 tâches MVP de Clément : les 36 de modèles et d'UI (backlog, Partie 1 section 13), regroupées en 20 étapes dans l'ordre où les faire, plus les 7 tâches d'animation (section 2.4), à mener en parallèle (piste « Animations » en fin de fichier). Chaque étape donne ce que tu fais toi-même, la consigne à copier-coller dans Claude, et le critère « fini quand ».

Claude lit [CLAUDE.md](../../CLAUDE.md) au démarrage : il connaît déjà les noms, tags, budgets et règles. Les consignes ci-dessous restent courtes pour cette raison.

## Avant de commencer (une seule fois)

1. Crée le groupe Roblox du studio, avec un nom de studio et pas le nom du jeu. Ajoute un rôle « Dev » qui peut modifier les jeux du groupe et publier des assets, et mets-y Ironix (L-001 dans la [liaison](../Liaison-Code-Visuel.md)).
2. Clone le dépôt dans un dossier permanent, par exemple dans tes Documents :

   ```bash
   git clone https://github.com/clementronde/Stealashop
   ```

   Puis ouvre Claude Code dans ce dossier `Stealashop`, pour qu'il lise `CLAUDE.md`. Quand Claude Code te demande d'accepter les réglages du projet, réponds **oui** : sinon le garde-fou d'Ironix, qui refuse tout envoi modifiant `src/`, ne s'active pas. Ce garde-fou ne contrôle que les envois faits par Claude : à la main, depuis un terminal ou GitHub Desktop, rien ne t'arrête. Ne touche donc jamais à `src/`.
3. Ouvre la place DEV du groupe en Team Create (tâche DEV-001).
4. Connecte le MCP Roblox Studio (plugin actif dans Studio) et le MCP Blender (add-on activé dans Blender).
5. Dans Blender, active l'extension **Cell Fracture** (pour les vitres).
6. Vérifie que tout répond :

   > Liste ce que tu vois dans Workspace et dans StarterGui de la place ouverte dans Studio, puis dis-moi quels objets sont dans la scène Blender.

7. **À chaque session ensuite**, commence par :

   > Récupère les derniers commits du dépôt, lis la liaison et dis-moi ce qui m'attend et ce qui a changé.

## Routine de livraison (à chaque asset)

1. Dépose le modèle dans `Workspace/_INBOX_CLEMENT`.
2. Demande la vérification :

   > Vérifie `<NOM DU MODÈLE>` dans `_INBOX_CLEMENT` avec le contrat de CLAUDE.md : nom, enfants obligatoires (section 10.4), tags, attributs, triangles, pivot, taille à côté d'un perso R15, aucun script (sauf un script d'effet `FX_` autorisé par la liaison, section 3.3). Corrige ce qui est purement technique (collisions, ancrage) et liste le reste sans le modifier.

3. Lance un test dans Studio : le ContractChecker ne doit afficher aucune ligne rouge.
4. Passe la tâche en « En revue » dans le doc partagé ; Ironix valide et range le modèle.

Les étapes 1 à 17 (M0 à M3) et A1 à A3 sont livrées : retirées le 2026-11-13 pour alléger ce parcours (elles restent dans l'historique git).

## M4 · du 1er au 13 décembre

### Étape 18 · UI-007, UI-004 et UI-008 · Habillage final de l'UI

- **Consigne** :

  > Habille tous les écrans MVP avec le style de la planche MOD-002, sans renommer ni déplacer aucun élément du contrat. Soigne particulièrement `UI_Unbox` en suivant le storyboard de la section 5.7 et nos vidéos de référence. Puis les billboards finaux, lisibles à 40 studs. Vérifie le rendu sur un écran de téléphone et lance le ContractChecker.

### Étape 19 · MOD-040 · Icônes des objets du catalogue

- **Consigne** :

  > Pour chaque objet `ITM_*`, fais un rendu Blender 512 × 512 sur fond transparent : caméra de trois quarts face, même lumière et même cadrage pour tous. Enregistre-les sous `/Art/Icons/<ItemId>.png`.

### Étape 20 · MOD-041 et MOD-043 · Particules, icône et miniatures

- **Consigne** :

  > Crée les textures de particules en PNG 256 × 256 transparent : éclats de verre, étincelles, confettis, rayons de révélation, et les halos des 7 raretés. Puis propose 3 compositions de miniatures 1920 × 1080 avec la casse de vitrine en vedette, et une icône 512 × 512 lisible en tout petit.

**Gel du 13 décembre** : plus aucune nouveauté, seulement des corrections jusqu'au lancement du 18.

## Piste « Animations » (en parallèle)

Toutes les animations suivent le contrat de la section 2.4 du doc partagé (le même que la section 3.2 de la [liaison](../Liaison-Code-Visuel.md)) : 20 animations, avec leur boucle, leur priorité et leurs marqueurs. **C'est toi qui animes dans l'éditeur d'animation de Studio** ; Claude prépare, découpe et vérifie, mais ne peut pas animer à ta place.

- **Joueur** : objets `Animation` dans `ReplicatedStorage/Assets/Animations/Player/`.
- **Vigiles et vendeurs** : dans le modèle lui-même, `<Modèle>/Animations/`. Le modèle n'a besoin d'aucun script : un Humanoid avec un `Animator`, plus son dossier `Animations`, suffit. C'est le code d'Ironix qui fait marcher, courir et attraper le vigile en jouant ces animations.
- **Publication** : au nom du groupe du studio, jamais depuis ton compte perso, sinon l'animation ne se joue pas dans le jeu. Chaque animation publiée va dans le registre de la liaison (nom, emplacement, ID).

### Étape A4 · ANI-030 · Célébration et finition (M4)

- **Consigne** :

  > Pendant un test, joue toutes les animations l'une après l'autre sur mon personnage, sur un vigile et sur un vendeur, et signale celles qui glissent, qui se coupent mal ou dont la boucle saute.

- **Toi** : tu animes `Celebrate`, puis tu corriges ce qui a été signalé.
- **Fini quand** : validé en playtest à deux.

## Consignes utiles à tout moment

> Quelles tâches du backlog de Clément (Partie 1, section 13) n'attendent plus rien ?

> Fais l'état des lieux de `_INBOX_CLEMENT` par rapport au contrat.

> Compte les triangles de tous les modèles de `ReplicatedStorage/Assets` et signale ceux qui dépassent le budget.

> Liste tous les modèles qui n'ont pas leur tag ou un attribut obligatoire.
