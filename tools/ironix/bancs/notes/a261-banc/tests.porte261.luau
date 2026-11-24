--!nocheck
-- Banc a261 (vague 75, T-084 raté au Play de la section C) : la porte du bot se refait dès la sortie du voleur
-- (PvPService.rebuildGate), et la vitre refaite bloquait le bot dans sa boutique. Correctif : groupes de collision
-- BotDefender (avatar du bot) et BotDoor (pièces de sa porte PlotDoor/Window), sans collision entre eux ; la porte
-- reste dans son groupe d'avant pour tous les autres, et le reprend au départ du bot.
-- Le faux Roblox ne simule pas les collisions : on contrôle les groupes et les règles enregistrés.

startBotServer()
local function glassOf(shop)
	local list = {}
	local door = shop:FindFirstChild("PlotDoor")
	local window = door and door:FindFirstChild("Window")
	if window then
		for _, d in window:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(list, d)
			end
		end
	end
	return list
end
local function allIn(parts, group)
	if #parts == 0 then
		return false
	end
	for _, p in parts do
		if p.CollisionGroup ~= group then
			return false
		end
	end
	return true
end
-- Roblox : toute pièce est dans « Default » ; le faux ne pose pas la propriété.
for _, entry in SHOPS do
	for _, p in glassOf(entry.model) do
		p.CollisionGroup = "Default"
	end
end

local bob = join("Bob", newProfile())
local plot, S = botArrives()

section("1. arrivée : l'avatar traverse sa porte, les autres non")
check(plot ~= nil, "le bot est là")
check(COLLISION_GROUPS.BotDefender == true and COLLISION_GROUPS.BotDoor == true, "groupes BotDefender et BotDoor enregistrés")
check(COLLIDABLE["BotDefender|BotDoor"] == false, "BotDefender ne touche pas BotDoor")
check(COLLIDABLE["BotDefender|Default"] == nil and COLLIDABLE["BotDoor|Default"] == nil, "rien d'autre ne change (sol, murs, joueurs)")
check(allIn(glassOf(plot), "BotDoor"), "vitres de sa porte dans BotDoor")
local others = {}
for _, entry in SHOPS do
	if entry.model ~= plot then
		for _, p in glassOf(entry.model) do
			table.insert(others, p)
		end
	end
end
check(allIn(others, "Default"), "portes des autres boutiques : inchangées")
local avatar = botAvatar()
local avatarParts = {}
for _, d in avatar:GetDescendants() do
	if d:IsA("BasePart") and d.Parent == avatar then
		table.insert(avatarParts, d)
	end
end
check(allIn(avatarParts, "BotDefender"), "corps du bot dans BotDefender")
local bobParts = {}
for _, d in bob.Character:GetDescendants() do
	if d:IsA("BasePart") then
		table.insert(bobParts, d)
	end
end
local bobInDoor = false
for _, p in bobParts do
	if p.CollisionGroup == "BotDoor" or p.CollisionGroup == "BotDefender" then
		bobInDoor = true
	end
end
check(not bobInDoor, "Bob n'est dans aucun des deux groupes (la porte refaite le bloque)")

section("2. vol et sortie : porte refaite, le bot poursuit, sa porte reste traversable pour lui seul")
check(breakDoor(bob, plot), "Bob casse la porte du bot")
enterShop(bob, S)
check(steal(bob, plot, 2), "Bob prend l'objet du présentoir 2")
exitShop(bob, S, 12)
check(waitFor(function()
	return BotService.IsChasing(bob)
end, 3), "Bob sort avec l'objet : poursuivi")
check(allIn(glassOf(plot), "BotDoor"), "pendant la poursuite : vitres toujours dans BotDoor")

section("3. départ du bot : sa porte reprend son groupe")
for i = 1, 4 do
	join("P" .. i, newProfile())
end
advance(1)
check(BotService.GetBotPlot() == nil, "5 vrais joueurs : le bot est parti")
check(allIn(glassOf(plot), "Default"), "vitres de son ancienne porte revenues dans Default")
summary("scénario porte261")
