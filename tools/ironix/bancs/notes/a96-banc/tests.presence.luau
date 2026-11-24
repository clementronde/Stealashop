--!nocheck
-- Scénario « presence » (a96, L-105 point 1, L-108 point 3) : 6 boutiques. Serveur vide : le bot arrive
-- après Bot.ArriveDelay sur la boutique libre de plus grand numéro, au niveau le plus faible (4 Communs de la
-- zone 1, porte d'un profil neuf), avec son avatar. Il reste de 1 à 4 vrais joueurs, part proprement dès le
-- 5e (PlayerAdded), revient quand le serveur repasse à 4, et n'est jamais un Player.

makeExtraShops()
startBotServer()
local Items = sharedModule("Config/Items")

section("serveur vide : arrivée du bot")
advance(1)
check(BotService.GetBotPlot() == nil, "pas tout de suite : le bot attend Bot.ArriveDelay (5 s)")
advance(5)
local plot = BotService.GetBotPlot()
check(plot == SHOPS[6].model, `serveur vide : le bot prend la boutique libre de plus grand numéro, la 6 (trouvé {plot and plot.Name})`)
check(plot:GetAttribute("BotName") == "Bot" and signText(plot) == "Bot's Shop", `attribut BotName « Bot » et panneau « Bot's Shop » (trouvé {signText(plot)})`)
check(plot:GetAttribute("OwnerUserId") == 0 and PlotService.GetOwner(plot) == nil, "pour les autres services, la boutique reste sans propriétaire joueur (niveau le plus faible)")
check(PlotService.IsBotPlot(plot) and BotService.IsBotPlot(plot) and not BotService.IsBotPlot(SHOPS[5].model), "IsBotPlot : vrai pour sa boutique seulement")
check(#Players:GetPlayers() == 0, "le bot n'est pas un Player")
local models = botModels(plot)
check(#models == 4, `4 objets exposés, les présentoirs d'une boutique neuve (trouvé {#models})`)
local good, slots = true, {}
for _, model in models do
	local def = Items.ById[model:GetAttribute("ItemId")]
	if def == nil or def.Rarity ~= "Common" or def.Zone ~= 1 or model:GetAttribute("OwnerUserId") ~= 0 or model:GetAttribute("Income") ~= 1 then
		good = false
	end
	slots[model:GetAttribute("DisplaySlot")] = true
end
check(good, "chaque objet : un Commun de la zone 1 du catalogue, 1 $/s, OwnerUserId = 0")
check(slots[1] and slots[2] and slots[3] and slots[4], "sur les présentoirs 1 à 4")
check(models[1] and models[1].Name:match("^DisplayItem_0%d$") ~= nil and models[1]:FindFirstChild("BB_Item") ~= nil, "construits comme un objet de joueur (DisplayItem_nn, billboard BB_Item)")
local exposed = BotService.GetExposed(plot)
check(countOf(exposed) == 4 and exposed[1] and exposed[1].Income == 1, "GetExposed : 4 objets, 1 $/s chacun")
check(plot:GetAttribute("BotIncome") == 4 and BotService.GetIncome(plot) == 4, "valeur exposée du bot : 4 $/s (attribut BotIncome)")
advance(0.6)
check(doorMaxHP(plot) == 50, `porte du bot cassable : 50 PV, base d'une boutique de niveau 1 (Formulas.PlayerWindowHP(1) ; trouvé {doorMaxHP(plot)})`)
check(doorMaxHP(SHOPS[5].model) == 0, "les autres boutiques libres restent incassables")
check(plot:GetAttribute("SafeSlots") == "1" and plot:GetAttribute("Protection") == nil, "PvPService publie le coffre-fort du bot (présentoir 1), aucune protection")

section("avatar du bot")
local avatar = plot:FindFirstChild("BotAvatar")
check(avatar ~= nil and avatar:IsA("Model"), "avatar R15 par défaut posé dans sa boutique (BotAvatar)")
if avatar then
	local root = avatar:FindFirstChild("HumanoidRootPart")
	local humanoid = avatar:FindFirstChildOfClass("Humanoid")
	check(root.Anchored == true and root.CanCollide == false and root.CanQuery == false, "HumanoidRootPart ancré, sans collision ni requête")
	check(avatar:FindFirstChild("Head").Anchored == false and avatar:FindFirstChild("Head").CanCollide == false, "les autres pièces suivent l'animation, sans collision")
	local scripts = 0
	for _, d in avatar:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			scripts += 1
		end
	end
	check(scripts == 0, "aucun script dans l'avatar (Animate retiré, 2.4)")
	local idle = avatar:FindFirstChild("Animations") and avatar.Animations:FindFirstChild("Idle")
	check(idle ~= nil and idle.AnimationId == "rbxassetid://507766666", "idle par défaut de Roblox gardé dans Animations/Idle")
	local track = IDLE_TRACKS[#IDLE_TRACKS]
	check(track ~= nil and track.Playing and track.Looped and track.Animation.Name == "Idle", "idle joué en boucle")
	check(humanoid.DisplayName == "Bot" and humanoid.HealthDisplayType == "Enum.HumanoidHealthDisplayType.AlwaysOff", "nom « Bot » au-dessus de lui, pas de barre de vie")
	local spawn = SHOPS[6].S.spawn
	local flat = Vector3.new(root.Position.X - spawn.X, 0, root.Position.Z - spawn.Z)
	check(flat.Magnitude < 0.01 and near(root.Position.Y, 0.3 + 2 + 1 + 0.1, 0.05), `debout au point d'apparition du propriétaire (écart {flat.Magnitude}, hauteur {root.Position.Y})`)
end
check(AVATAR_CALLS == 1, "avatar de Roblox demandé une seule fois")

section("1 à 4 vrais joueurs : le bot reste")
local players = {}
for i = 1, 4 do
	players[i] = join(`P{i}`, newProfile())
end
advance(3)
check(BotService.GetBotPlot() == plot, "à 4 vrais joueurs, le bot reste")
local inOrder = true
for i = 1, 4 do
	if shopOf(players[i]) ~= SHOPS[i].model then
		inOrder = false
	end
end
check(inOrder, "les joueurs reçoivent les boutiques 1 à 4, jamais celle du bot")
check(#Players:GetPlayers() == 4, "4 Players, le bot n'en est pas un")

section("5e vrai joueur : départ immédiat et propre")
local fifth = newPlayer("P5")
flush()
check(BotService.GetBotPlot() == nil, "dès l'arrivée du 5e vrai joueur (PlayerAdded), le bot part")
botLeftClean(plot, "départ au 5e joueur")
check(#botModels(plot) == 0, "objets du bot détruits")
check(signText(plot) == "", "panneau vidé")
advance(0.3)
check(doorMaxHP(plot) == 0, "porte de nouveau incassable (boutique libre)")
check(plot:GetAttribute("SafeSlots") == nil and plot:GetAttribute("StealOpen") == nil, "attributs de PvPService retirés")
spawnCharacter(fifth, Vector3.new(0, 3, 0))
DataService._load(fifth, newProfile())
advance(0.3)
check(shopOf(fifth) == SHOPS[5].model, "le 5e joueur reçoit la boutique libre de plus petit numéro")
advance(10)
check(BotService.GetBotPlot() == nil, "à 5 vrais joueurs, le bot ne revient pas")

section("retour à 4 vrais joueurs")
leave(players[2])
advance(3)
check(BotService.GetBotPlot() == nil, "pas tout de suite après un départ (5 s d'attente)")
advance(4)
check(BotService.GetBotPlot() == SHOPS[6].model, "4 vrais joueurs depuis 5 s : le bot revient sur la boutique libre de plus grand numéro")
check(#botModels(SHOPS[6].model) == 4 and SHOPS[6].model:FindFirstChild("BotAvatar") ~= nil, "objets et avatar de nouveau là")
check(AVATAR_CALLS == 1, "avatar préparé une fois, copié à chaque arrivée")
local seen = {}
for _, model in botModels(SHOPS[6].model) do
	seen[model:GetAttribute("ItemUid")] = true
end
local fresh = true
for _, model in models do
	if seen[model:GetAttribute("ItemUid")] then
		fresh = false
	end
end
check(fresh, "objets neufs (uid nouveaux) à chaque arrivée")

section("6 vrais joueurs, puis retour à 4")
-- Boutiques prises : 1, 3, 4, 5 (joueurs) et 6 (bot) ; 2 libre. Deux joueurs arrivent : 6 vrais joueurs.
local p6 = join("P6", newProfile())
check(BotService.GetBotPlot() == nil and shopOf(p6) == SHOPS[2].model, "5e vrai joueur : le bot part, P6 reçoit la boutique 2")
local p7 = join("P7", newProfile())
check(shopOf(p7) == SHOPS[6].model, "6e : il reçoit la boutique 6, libérée par le bot")
leave(p7)
leave(p6)
advance(7)
check(BotService.GetBotPlot() == SHOPS[6].model, "repassé à 4 : le bot revient")

check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")
check(not logHas("mal formé", "WARN"), "aucun envoi de remote mal formé (Net, en Studio)")
check(not logHas("[BotService]", "WARN"), "aucun avertissement de BotService")

if VERBOSE then
	dumpLog()
end
summary("scénario presence")
