# À mettre dans la liaison pour Ironix : les écrans de Clément que le code ne branche pas (2026-11-11)

Clément, en Play : « hier on a tout fait, pourquoi rien ne s'affiche ? » Il ne voit ni l'Index v3, ni les réglages, ni la barre du bas, ni les bons onglets, ni les animations validées.

- **Cause** : ce qu'il a vu hier venait des prototypes (`tools/clement/*_proto.luau`), lancés pendant son Play. Ils s'arrêtent avec le Play.
- Les écrans eux-mêmes sont bien enregistrés dans `StarterGui` (place DEV).
- Mais la liaison ne parle **jamais** de `UI_Index_v3`, `UI_Settings`, `SettingsButton`, `UI_Toast` ni `UI_Hotbar` : Ironix ne sait pas qu'ils existent.

## Ce que Clément a validé, et que le code doit brancher

1. **Index : `UI_Index_v3` remplace `UI_Index_v2`.** Validé par Clément le 2026-11-10 (« top » ; la fiche de droite suit l'objet cliqué, pas le survol).
   - `IndexController` ouvre aujourd'hui `UI_Index_v2` (`SCREEN = "UI_Index_v2"`).
   - Les noms gardés et les nouveaux sont dans `ui-index-v3.md`, sections « Mise en page » et « Pour Ironix » : `Clip`, la silhouette, la fiche `Detail` au clic, `Rewards`, `ZoneItem`, `Categories` et `MutationTabs`.
2. **Réglages : `UI_Settings`**, et le bouton `UI_HUD.SocialRow.SettingsButton` (caché, à montrer par `Features`).
   - Aucun code ne les lit.
   - Les noms, les attributs (`MusicVolume`, déjà lu par `MusicController` ; `SfxVolume` ; `VfxEnabled`), la rangée `ClickRow` et ses 5 sons de clic sont dans `ui-settings.md`.
3. **Argent hors ligne : `UI_Offline`** (à la place du Notify « Your shop earned … while you were away »), et **messages du bas : `UI_Toast`** (`Stack.Template`, 3 au plus, 2,4 s). Voir `ui-feel2-horsligne-poursuite-barre.md`.
   - Attention : depuis ce matin, Clément ne veut plus de case qui vole (voir `ui-hotbar-et-ramassage.md`). Le `Flyer` de `UI_Offline` est donc à confirmer avec lui.
4. **Arrivée en zone safe : `UI_Escape`** (`Flash`, `Banner` avec `Title`, `Subtitle` et `BoxIcon`). Le contrat est dans `ui-L092-retours.md`, section 2.
5. **Animations d'ouverture validées** : c'est déjà la ligne L-094. Rien à ajouter.
6. **Barre du bas** : il ne faut **pas** brancher `UI_Hotbar`, qui n'est qu'un essai. La nouvelle barre, `UI_HUD.Hotbar`, attend la validation de Clément dans Figma (`ui-hotbar-et-ramassage.md`). Ses noms arriveront ensuite.

## Onglets de l'inventaire : rien à changer côté code

Ce matin, l'onglet des armes avait été renommé `WeaponsTab` et `WeaponsSection`, mais le code et `Contract/UI.luau` lisent `ToolsTab` et `ToolsSection`. En Play : « ToolsTab introuvable » et « ToolsSection introuvable », l'onglet est vide, et le ContractChecker affiche 2 lignes rouges.

- **Décision** : les noms restent `ToolsTab` et `ToolsSection`. Seuls le texte « WEAPONS » et l'icône de la batte changent.
- Le correctif `tools/clement/inventory_tools_names_fix.luau` remet ces noms. Il ajoute aussi ce que le contrat demande encore dans `ToolsSection` : `SectionCount.CountLabel`, et `Rays` et `Glow` dans la carte.
- Il se lance en Edit, dès la fin du Play de Clément.
