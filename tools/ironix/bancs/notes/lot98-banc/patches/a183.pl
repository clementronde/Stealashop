# lot98-commun (petit chef 2) : a419 (manette, Features.Gamepad) : SkillTreeController écoute SelectionGained des tuiles
# (sélection à la manette) et InputBegan des boutons, et SkillTree/Nav pose Selectable = false sur sa couche ; le faux
# Roblox de ces bancs (copie a60/a62 + a85) n'avait ni SelectionGained (« membre inconnu ») ni la propriété Selectable.
# Signaux ajoutés à la liste EVENTS (jamais tirés ici : souris et doigt comme avant), Selectable aux objets d'UI.
undef $/; $_ = <>;
s/(\nlocal EVENTS = \{\r?\n(?:[^\n]*\n)*?\}\r?\n)/$1EVENTS.SelectionGained = true -- lot98-commun : a419\nEVENTS.SelectionLost = true\nEVENTS.InputBegan = true\nEVENTS.InputEnded = true\nEVENTS.InputChanged = true\nfor _, guiClass in { "Frame", "TextLabel", "TextButton", "ImageLabel", "ImageButton", "ScrollingFrame", "TextBox", "CanvasGroup" } do\n\tif PROPS[guiClass] ~= nil and PROPS[guiClass].Selectable == nil then\n\t\tPROPS[guiClass].Selectable = string.find(guiClass, "Button", 1, true) ~= nil\n\tend\nend\n/;
# Scénario alert : « tout le premier anneau est au maximum ou pas codé ». a408 code Guards (5 niveaux) et Cameras niveau 3,
# a411 ajoute FittingRoom (1 niveau, sans renaissance) : mises au maximum pour garder ce point de départ.
s/\tSkill_Cameras = 2,(\r?\n)\tSkill_Bodyguards = 0,/\tSkill_Cameras = 3, -- lot98-commun : a408$1\tSkill_Bodyguards = 5, -- lot98-commun : a408$1\tSkill_FittingRoom = 1, -- lot98-commun : a411/;
print;
