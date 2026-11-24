--!nocheck
local checks, fails = 0, 0
local function check(cond, label)
	checks += 1
	if not cond then
		fails += 1
		print("ÉCHEC : " .. label)
	end
end

local Net = loadModule("Net")
local Definitions = loadModule("Definitions")

local violations = {}
Net.OnViolation = function(player, remote, reason, detail)
	table.insert(violations, { player = player.Name, remote = remote, reason = reason, detail = detail })
end

local byName = {}
for _, inst in INSTANCES do
	if inst.Name then
		byName[inst.Name] = inst
	end
end

-- 1. La table et les remotes du budget.
local models = Definitions.Budgets.Models
check(models ~= nil and models.RatePerSecond == 3 and models.Burst == 6, "Budgets.Models = 3 par seconde, 6 en réserve")
local expected = {
	"HoldItem", "PlaceItem", "EquipBest", "PlaceItemAuto", "UnplaceItem", "TakeDisplayItem",
	"PlaceFromReserve", "EquipCosmetic", "EquipTool", "PlaceBox", "OpenBox",
}
local inBudget = {}
for _, def in Definitions.List do
	if def.Budget ~= nil then
		inBudget[def.Name] = def.Budget
	end
end
for _, n in expected do
	check(inBudget[n] == "Models", n .. " dans le budget Models")
end
local count = 0
for _ in inBudget do
	count += 1
end
check(count == #expected, "seulement ces " .. #expected .. " remotes ont un budget (trouvé " .. count .. ")")
check(inBudget.HitWindow == nil and inBudget.BuyItem == nil, "HitWindow et BuyItem hors budget")

-- Abonnements : compte des appels arrivés au service.
local received = {}
for _, n in { "HoldItem", "UnplaceItem", "PlaceItemAuto", "EquipCosmetic", "BuyItem", "OpenBox" } do
	received[n] = 0
	Net.Server[n]:Connect(function()
		received[n] += 1
	end)
end

local function makePlayer(name)
	return { Name = name, Parent = FakePlayers }
end
local function fire(remote, player, ...)
	byName[remote].OnServerEvent:Fire(player, ...)
end
local function total()
	return received.HoldItem + received.UnplaceItem + received.PlaceItemAuto + received.EquipCosmetic + received.OpenBox
end
local order = { "HoldItem", "UnplaceItem", "PlaceItemAuto", "EquipCosmetic" }

-- 2. Rafale en mêlant 4 remotes au même instant : 6 passent (réserve), le reste refusé « Budget ».
local p1 = makePlayer("P1")
NOW = 100
for i = 1, 12 do
	fire(order[(i - 1) % 4 + 1], p1, "uid" .. i)
end
check(total() == 6, "rafale de 12 appels mêlés : 6 acceptés (trouvé " .. total() .. ")")
local budgetRefusals = 0
for _, v in violations do
	if v.reason == "Budget" then
		budgetRefusals += 1
	end
end
check(budgetRefusals == 1, "refus Budget signalé une seule fois dans la seconde (trouvé " .. budgetRefusals .. ")")
check(
	violations[1] ~= nil and violations[1].reason == "Budget" and string.find(violations[1].detail, "1 appel", 1, true) ~= nil,
	"le 1er signalement : raison Budget, 1 appel ignoré"
)

-- 3. Un autre joueur a son propre budget.
local p2 = makePlayer("P2")
local before2 = total()
fire("HoldItem", p2, "x")
check(total() - before2 == 1, "P2 n'est pas gêné par le budget de P1")

-- 4. Débit durable : 10 appels par seconde pendant 10 s, ~3 par seconde passent.
local before = total()
for step = 1, 100 do
	NOW = 100 + step * 0.1
	fire(order[step % 4 + 1], p1, "u" .. step)
end
local passed = total() - before
check(passed >= 29 and passed <= 31, "10 s à 10 appels par seconde : ~30 acceptés (trouvé " .. passed .. ")")

-- 5. Un joueur normal : un geste toutes les 0,4 s pendant 20 s, jamais refusé.
local p3 = makePlayer("P3")
local b3 = total()
for step = 1, 50 do
	NOW = 200 + step * 0.4
	fire(order[step % 4 + 1], p3, "n" .. step)
end
check(total() - b3 == 50, "un geste toutes les 0,4 s : tous acceptés (trouvé " .. (total() - b3) .. ")")

-- 6. Après un temps calme, la réserve est pleine à nouveau : six gestes d'un coup (pas plus de 4 par remote).
NOW = 300
local b4 = total()
for i = 1, 6 do
	fire(order[(i - 1) % 4 + 1], p3, "k" .. i)
end
check(total() - b4 == 6, "après un temps calme : 6 d'un coup acceptés")

-- 7. Un appel refusé par la forme ne prend pas de jeton.
local p4 = makePlayer("P4")
NOW = 400
for _ = 1, 3 do
	fire("OpenBox", p4, 123) -- mauvais type : refusé par Validate (OpenBox : 4 par seconde)
end
local b5 = total()
for i = 1, 6 do
	fire(order[(i - 1) % 4 + 1], p4, "ok" .. i)
end
check(total() - b5 == 6, "appels mal formés : aucun jeton pris (6 bons ensuite acceptés)")

-- 8. Le débit propre du remote passe avant : un appel refusé par lui ne prend pas de jeton.
local p5 = makePlayer("P5")
NOW = 500
local h0 = received.HoldItem
for i = 1, 6 do
	fire("HoldItem", p5, "h" .. i)
end
check(received.HoldItem - h0 == 4, "HoldItem garde son débit de 4 par seconde")
local u0 = received.UnplaceItem
fire("UnplaceItem", p5, "z1")
fire("UnplaceItem", p5, "z2")
fire("UnplaceItem", p5, "z3")
check(received.UnplaceItem - u0 == 2, "réserve de 6 : 4 HoldItem + 2 UnplaceItem, le 7e refusé")

-- 9. Remote hors budget jamais compté.
local bb = received.BuyItem
fire("BuyItem", p5, "cat")
check(received.BuyItem - bb == 1, "BuyItem passe avec le budget vide")

-- 10. Départ du joueur : son budget est oublié.
FakePlayers.PlayerRemoving:Fire(p5)
local b9 = received.EquipCosmetic
for i = 1, 4 do
	fire("EquipCosmetic", p5, "c" .. i)
end
check(received.EquipCosmetic - b9 == 4, "budget remis à neuf après PlayerRemoving")

print(checks .. " vérification(s), " .. fails .. " échec(s)")
