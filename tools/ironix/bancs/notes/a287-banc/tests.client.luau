--!nocheck
-- a287 (2026-11-21, Cantin en jeu) : RevealController + Reveal/Unbox côté client (mise en place des bancs a204 et a259).
--   A ouvreur, colis Commun en 3 actions, repli codé : la cote part de 1 IN 2, monte à chaque coup, reste visible à
--     l'éclatement et sur les silhouettes, ne redescend jamais, finit sur la vraie cote ; BB_Reveal (repli du code) :
--     Odds = la vraie cote, Income = le revenu de l'objet
--   B BB_Reveal de Clément (Lines.Odds « 1 IN 112 », Lines.Income « +$50/s », textes d'exemple) : réécrits, mutation
--     Diamond et poids compris ; une silhouette par rareté, chacune plus haut
--   C cinématique d'avant (pas de plan) : Odds caché, Income écrit
local Plan = sharedModule("UnboxPlan", "client")
local Cfg = sharedModule("Config/Unbox", "client")
local Formulas = sharedModule("Config/Formulas", "client")
local Mutations = sharedModule("Config/Mutations", "client")
local Format = sharedModule("Format", "client")
local New = Cfg.New

local alice = newPlayer("Alice")
local function spawn(player, position)
	local character = spawnCharacter(player, position)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	humanoid.HipHeight = 2
	make("Animator", { Name = "Animator" }, humanoid)
	local hand = make("Part", { Name = "RightHand", Size = Vector3.new(0.5, 0.5, 0.5), CFrame = CFrame.new(position + Vector3.new(1, 0, 0)), CanCollide = false }, character)
	make("Attachment", { Name = "RightGripAttachment", CFrame = CFrame.new(0, -0.2, 0) }, hand)
	return character
end
spawn(alice, Vector3.new(65, 3, -50))
make("ScreenGui", { Name = "UI_Hotbar", Enabled = true }, alice.PlayerGui)
make("ScreenGui", { Name = "UI_Escape", Enabled = true }, alice.PlayerGui)
local unboxScreen = make("ScreenGui", { Name = "UI_Unbox", Enabled = false }, alice.PlayerGui)
make("ImageLabel", { Name = "EdgeGlow", ImageTransparency = 1, ImageColor3 = Color3.new(1, 1, 1) }, unboxScreen)
Workspace.CurrentCamera = CAMERA
CAMERA.FieldOfView = 70
local function homeCamera()
	CAMERA.CameraType = Enum.CameraType.Custom
	CAMERA.CameraSubject = alice.Character:FindFirstChildOfClass("Humanoid")
	CAMERA.CFrame = CFrame.lookAt(Vector3.new(65, 8, -25), Vector3.new(65, 3, -45))
end
homeCamera()
dropRig()
startClient(alice)
local RC = clientModule("RevealController")

local function reveal(store, itemId, rarity, mutation, weight, id, plan)
	NET.Server.RevealStarted:FireAll(alice, store.Name, store.Name .. "/03", itemId, rarity, mutation, weight, 1, "Small", id, plan)
	flush()
end
local function scene(id)
	for _, s in RC.GetState().Scenes do
		if s.Id == id then
			return s
		end
	end
	return nil
end
local function unbox(id)
	local s = scene(id)
	return s and s.Unbox
end
local function fired(id, marker)
	local s = scene(id)
	return s ~= nil and table.find(s.Fired, marker) ~= nil
end
local function expectedIncome(itemId, mutation, weight)
	local m = if mutation ~= "" then { Effect = mutation } else nil
	return "+" .. Format.money(Formulas.ItemIncome(itemId) * Mutations.IncomeMultiplier(m, weight)) .. "/s"
end

-- Joue la scène image par image jusqu'à la révélation (puis le défilement de la cote finale) et relève la cote.
local function watch(id, limit)
	local log = { values = {}, texts = {}, phases = {}, hiddenAfterBurst = 0, burstOdds = nil, lastSilhouetteOdds = nil, silhouetteOdds = {}, actionTexts = {} }
	local start = now()
	local lastSil = 0
	local function sample()
		local u = unbox(id)
		if u == nil then
			return
		end
		table.insert(log.values, u.Odds)
		table.insert(log.texts, u.OddsText)
		table.insert(log.phases, u.Phase)
		if u.Phase == "Action" or u.Phase == "Gap" or u.Phase == "Intro" then
			if log.actionTexts[#log.actionTexts] ~= u.OddsText then
				table.insert(log.actionTexts, u.OddsText)
			end
		end
		if u.Phase == "Burst" or u.Phase == "Silhouettes" then
			if not u.OddsVisible then
				log.hiddenAfterBurst += 1
			end
			if u.Phase == "Burst" then
				log.burstOdds = u.Odds
			end
		end
		if u.Phase == "Silhouettes" then
			if u.SilhouetteIndex ~= lastSil then
				if lastSil > 0 then
					log.silhouetteOdds[lastSil] = log.lastSilhouetteOdds
				end
				lastSil = u.SilhouetteIndex
			end
			log.lastSilhouetteOdds = u.Odds
		end
	end
	sample()
	while not fired(id, "Reveal") and now() - start < limit do
		advance(1 / 30)
		sample()
	end
	if lastSil > 0 then
		log.silhouetteOdds[lastSil] = log.lastSilhouetteOdds
	end
	for _ = 1, math.ceil((New.OddsRoll + 0.1) * 30) do
		advance(1 / 30)
		sample()
	end
	return log
end
local function neverDown(values)
	for i = 2, #values do
		if values[i] < values[i - 1] - 1e-9 then
			return false, i
		end
	end
	return true, 0
end

section("A. Colis Commun, 3 actions, repli du code")
local PLAN_A = "Saw:Common,Kick:Common,Hammer:Common|10"
reveal(STORES[1], ITEM_A.Id, "Common", "", 4.5, "a1", PLAN_A)
local u = unbox("a1")
check(u ~= nil and u.OddsText == "1 IN 2" and u.OddsVisible, "A1 cote de départ « 1 IN 2 » au-dessus du colis")
check(u ~= nil and #u.Moves == 3, "A2 trois actions jouées pour un Commun")
local log = watch("a1", 20)
local ok, at = neverDown(log.values)
check(ok, "A3 la cote ne redescend jamais (" .. (if ok then "" else "image " .. at .. " : " .. tostring(log.texts[at - 1]) .. " → " .. tostring(log.texts[at])) .. ")")
check(#log.actionTexts >= 3, "A4 elle monte coup après coup pendant les actions (" .. table.concat(log.actionTexts, " → ") .. ")")
check(log.burstOdds ~= nil and log.hiddenAfterBurst == 0, "A5 visible à l'éclatement et sur les silhouettes")
check(log.lastSilhouetteOdds ~= nil and log.burstOdds ~= nil and log.lastSilhouetteOdds > log.burstOdds, string.format("A6 la silhouette la fait monter (%s → %s)", tostring(log.burstOdds), tostring(log.lastSilhouetteOdds)))
u = unbox("a1")
check(u ~= nil and u.OddsText == "1 IN 10", "A7 dernière cote affichée : la vraie (" .. tostring(u and u.OddsText) .. ")")
local board = scene("a1") and scene("a1").Board
check(board ~= nil and board:FindFirstChild("Odds") ~= nil and board.Odds.Text == "1 IN 10" and board.Odds.Visible ~= false, "A8 BB_Reveal (repli du code) : Odds = « 1 IN 10 », la même cote")
local income = expectedIncome(ITEM_A.Id, "", 4.5)
check(board ~= nil and board:FindFirstChild("Income") ~= nil and board.Income.Text == income, "A9 BB_Reveal : Income = " .. income .. " (" .. tostring(board and board:FindFirstChild("Income") and board.Income.Text) .. ")")
local done = now()
while scene("a1") and scene("a1").Stage == "Unbox" and now() - done < 5 do
	advance(1 / 30)
end
NET.Server.RevealEnded:FireAll("a1")
flush()
advance(0.5)

section("B. BB_Reveal de Clément, objet Rare Diamond")
local bb = make("BillboardGui", { Name = "BB_Reveal" }, UI_FOLDER)
local linesFrame = make("Frame", { Name = "Lines" }, bb)
make("TextLabel", { Name = "ItemName", Text = "Item" }, linesFrame)
make("TextLabel", { Name = "Rarity", Text = "RARITY" }, linesFrame)
make("TextLabel", { Name = "Odds", Text = "1 IN 112", Visible = true }, linesFrame)
make("TextLabel", { Name = "Income", Text = "+$50/s", Visible = true }, linesFrame)
homeCamera()
moveTo(alice, Vector3.new(65, 3, -50))
local PLAN_B = "Saw:Common,Kick:Uncommon,Drill:Uncommon,Search:Rare,Hammer:Rare|37"
reveal(STORES[1], ITEM_A.Id, "Rare", "Diamond", 4.5, "b1", PLAN_B)
log = watch("b1", 25)
ok, at = neverDown(log.values)
check(ok, "B1 la cote ne redescend jamais, améliorations comprises")
check(log.silhouetteOdds[1] ~= nil and log.silhouetteOdds[2] ~= nil and log.silhouetteOdds[3] ~= nil and log.silhouetteOdds[1] < log.silhouetteOdds[2] and log.silhouetteOdds[2] < log.silhouetteOdds[3] and log.silhouetteOdds[3] < 37, string.format("B2 trois silhouettes, chacune plus haut, sous la vraie cote (%s, %s, %s)", tostring(log.silhouetteOdds[1]), tostring(log.silhouetteOdds[2]), tostring(log.silhouetteOdds[3])))
u = unbox("b1")
check(u ~= nil and u.OddsText == "1 IN 37", "B3 dernière cote affichée « 1 IN 37 »")
board = scene("b1") and scene("b1").Board
local lines = board and board:FindFirstChild("Lines")
check(lines ~= nil and lines.Odds.Text == "1 IN 37", "B4 Lines.Odds réécrit : « 1 IN 37 » (au lieu de « 1 IN 112 ») (" .. tostring(lines and lines.Odds.Text) .. ")")
income = expectedIncome(ITEM_A.Id, "Diamond", 4.5)
local plain = expectedIncome(ITEM_A.Id, "", 4.5)
check(lines ~= nil and lines.Income.Text == income and income ~= plain and income ~= "+$50/s", "B5 Lines.Income réécrit : " .. income .. ", Diamond compris (" .. tostring(lines and lines.Income.Text) .. ")")
done = now()
while scene("b1") and scene("b1").Stage == "Unbox" and now() - done < 5 do
	advance(1 / 30)
end
NET.Server.RevealEnded:FireAll("b1")
flush()
advance(0.5)

section("C. Cinématique d'avant (pas de plan)")
homeCamera()
moveTo(alice, Vector3.new(65, 3, -50))
reveal(STORES[1], ITEM_A.Id, "Rare", "", 4.5, "c1", nil)
local start = now()
while (scene("c1") == nil or scene("c1").Board == nil) and now() - start < 15 do
	advance(1 / 30)
end
board = scene("c1") and scene("c1").Board
lines = board and board:FindFirstChild("Lines")
check(lines ~= nil and lines.Odds.Visible == false, "C1 sans plan : Lines.Odds caché (plus de « 1 IN 112 »)")
check(lines ~= nil and lines.Income.Text == plain, "C2 sans plan : Lines.Income = " .. plain)
NET.Server.RevealEnded:FireAll("c1")
flush()

summary("scénario client")
