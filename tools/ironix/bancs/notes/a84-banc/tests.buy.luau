--!nocheck
-- Scénario « buy » (a84) : BuySkill accepté et refusé (Id inconnu, tuile fermée, Soon, maximum, argent),
-- attributs Skill_<Id>, argent retiré au prix du serveur, messages, télémétrie, OnChanged.
startSkills()
local adaData = newProfile()
local ada = join("Ada", adaData)
advance(0.5)

section("attributs au chargement")
local all = true
for _, id in SKILL_IDS do
	if ada:GetAttribute("Skill_" .. id) ~= 0 then
		all = false
	end
end
check(all, "Skill_<Id> = 0 pour les 11 compétences")
check(adaData.SkillTree == nil, "profil sans SkillTree : rien n'est créé au chargement")

local changes = {}
SkillTreeService.OnChanged(function(player, id, level)
	table.insert(changes, { player = player, id = id, level = level })
end)

section("refus")
local before = #notifies(ada)
buy(ada, "Nope")
check(#notifies(ada) == before and adaData.Cash == 1000, "Id inconnu : ignoré, aucun message, argent intact")
check(logHas("Id inconnu", "WARN", "server"), "Id inconnu : une ligne en Studio")
buy(ada, "Cameras") -- 5 000 $, Ada en a 1 000
local msg, kind = lastNotify(ada)
check(msg == "Not enough cash: $5K needed." and kind == "Warning", `argent insuffisant : « {msg} » ({kind})`)
check(adaData.Cash == 1000 and ada:GetAttribute("Skill_Cameras") == 0 and adaData.SkillTree == nil, "argent insuffisant : rien ne change")
adaData.Cash = 1e12
buy(ada, "Curtain")
msg = lastNotify(ada)
check(msg == "Locked: get Glass level 1 first.", `tuile fermée : « {msg} »`)
buy(ada, "Safe")
msg = lastNotify(ada)
check(msg == "Locked: get Glass Regen level 1 first.", `tuile fermée (Safe) : « {msg} »`)
buy(ada, "ShopLevel")
msg = lastNotify(ada)
check(msg == "Shop: coming soon!", `Soon (Coded = 0) : « {msg} »`)
buy(ada, "PotionLuck")
msg = lastNotify(ada)
check(msg == "Potion Luck: coming soon!", `Soon sans prix : « {msg} »`)
check(adaData.Cash == 1e12 and adaData.SkillTree == nil and #changes == 0 and #TELEMETRY == 0, "refus : ni argent, ni niveau, ni signal, ni télémétrie")

section("achats acceptés")
buy(ada, "Cameras")
msg, kind = lastNotify(ada)
check(ada:GetAttribute("Skill_Cameras") == 1 and adaData.SkillTree and adaData.SkillTree.Cameras == 1, "Cameras niveau 1 : profil et attribut")
check(adaData.Cash == 1e12 - 5000, `5 000 $ retirés (reste {adaData.Cash})`)
check(msg == "Cameras upgraded: I!" and kind == "Success", `message de réussite : « {msg} » ({kind})`)
check(#changes == 1 and changes[1].player == ada and changes[1].id == "Cameras" and changes[1].level == 1, "OnChanged(ada, Cameras, 1)")
local eco, ev = TELEMETRY[1], TELEMETRY[2]
check(eco and eco.what == "economy" and eco.kind == "Defense" and eco.amount == 5000 and eco.sku == "Cameras" and eco.fields[1] == "Level - 1", "télémétrie : économie Defense, 5 000, SKU Cameras, Level - 1")
check(ev and ev.what == "event" and ev.key == "DefenseBought" and ev.fields[1] == "Defense - Cameras" and ev.fields[2] == "Level - 1", "télémétrie : événement DefenseBought")
buy(ada, "Cameras")
check(ada:GetAttribute("Skill_Cameras") == 2 and adaData.Cash == 1e12 - 155000, "Cameras niveau 2 pour 150 000 $")
buy(ada, "Cameras")
msg = lastNotify(ada)
check(msg == "Cameras: coming soon!" and ada:GetAttribute("Skill_Cameras") == 2 and adaData.Cash == 1e12 - 155000, `niveau 3 au-delà de Coded : refusé (« {msg} »)`)

buy(ada, "GlassThickness")
check(ada:GetAttribute("Skill_GlassThickness") == 1, "Glass niveau 1")
buy(ada, "Curtain")
msg = lastNotify(ada)
check(msg == "Curtain: coming soon!" and ada:GetAttribute("Skill_Curtain") == 0, `Curtain ouverte par Glass 1, mais Soon : « {msg} »`)
buy(ada, "GlassRegen")
buy(ada, "Safe")
buy(ada, "Safe")
check(ada:GetAttribute("Skill_Safe") == 2, "Safe ouverte par Glass Regen 1 : niveaux 1 et 2")
local cash = adaData.Cash
buy(ada, "Safe")
msg = lastNotify(ada)
check(msg == "Safe is already at max level." and adaData.Cash == cash and ada:GetAttribute("Skill_Safe") == 2, `Safe au maximum : « {msg} »`)
for _ = 1, 4 do
	buy(ada, "GlassThickness")
end
check(ada:GetAttribute("Skill_GlassThickness") == 5, "Glass jusqu'au niveau 5")
local spent = 5000 + 150000 + 25000 + 50000 + 250000 + 25000000 + 300000 + 4000000 + 50000000 + 600000000
check(adaData.Cash == 1e12 - spent, `total retiré = somme des prix du serveur ({1e12 - adaData.Cash} / {spent})`)
buy(ada, "GlassThickness")
msg = lastNotify(ada)
check(msg == "Glass is already at max level.", `Glass au maximum : « {msg} »`)
check(SkillTreeService.GetLevel(ada, "GlassThickness") == 5 and SkillTreeService.GetEffect(ada, "GlassThickness") == 8, "GetLevel 5, GetEffect ×8")
check(SkillTreeService.GetLevel(ada, "Curtain") == 0 and SkillTreeService.GetEffect(ada, "Curtain") == nil and SkillTreeService.GetLevel(ada, "Nope") == 0, "GetLevel 0 et GetEffect nil sans achat ou Id inconnu")

section("débit de Net et profil absent")
local n = #changes
for _ = 1, 10 do
	fireAs(ada, "BuySkill", "GlassRegen")
end
advance(0.5)
local regen = ada:GetAttribute("Skill_GlassRegen")
check(regen >= 2 and regen <= 5 and #changes - n == regen - 1, `10 envois d'un coup : le débit de Net en laisse passer ({regen - 1} achat(s))`)
local cy = newPlayer("Cy") -- sans profil
fireAs(cy, "BuySkill", "Cameras")
advance(0.3)
check(#notifies(cy) == 0 and cy:GetAttribute("Skill_Cameras") == nil, "profil pas chargé : ignoré")

section("sortie")
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")
if VERBOSE then
	dumpLog()
end
summary("scénario buy")
