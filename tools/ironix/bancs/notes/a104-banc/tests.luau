-- Scénarios du banc a104 (vague 31, L-112) : ShelfOpen/Logic, HeistController (invites « Open » et prise de
-- l'objet sorti selon la réservation), ShelfOpenController (rabats ou Lid, compteur, échelle, sortie,
-- nettoyage). SHELF_OPEN = false : l'ancien comportement exact (invite « Steal » maintenue, rien d'autre).

---------------------------------------------------------------- arbre du jeu
local Shared = folder(ReplicatedStorage, "Shared")
local ConfigF = folder(Shared, "Config")
for _, m in { "DeepFreeze", "ShelfOpen", "Items", "Rarities", "Mutations", "Balance" } do
	moduleScript(ConfigF, m, "shared/Config/" .. m .. ".luau")
end
if SHELF_OPEN then
	moduleScript(ConfigF, "Features", "shared/Config/Features.luau")
else
	moduleScript(ConfigF, "Features", { value = { ShelfOpen = false } })
end
moduleScript(Shared, "Format", "shared/Format.luau")
moduleScript(Shared, "ShelfOpenState", "shared/ShelfOpenState.luau")
moduleScript(folder(Shared, "Contract"), "Find", "shared/Contract/Find.luau")
PLAYED = {}
local SoundsF -- plus bas
moduleScript(folder(Shared, "Anim"), "MarkerSounds", {
	value = {
		find = function(name)
			local f = SoundsF:FindFirstChild(name, true)
			return if f and f:IsA("Sound") then f else nil
		end,
		playSound = function(template, at)
			local s = template:Clone()
			s.Parent = at or SoundService
			table.insert(PLAYED, { name = template.Name, sound = s, at = at })
			return s
		end,
	},
})
NET = { open = {}, grab = {} }
moduleScript(folder(Shared, "Net"), "Net", {
	value = {
		Client = {
			OpenShelfBox = {
				Fire = function(_, id)
					table.insert(NET.open, id)
				end,
			},
			GrabItem = {
				Fire = function(_, id)
					table.insert(NET.grab, id)
				end,
			},
			HeistTimer = { Connect = function() end },
		},
	},
})
local Client = folder(newInstance("Folder"), "Client")
local Controllers = folder(Client, "Controllers")
local HeistModule = moduleScript(Controllers, "HeistController", "client/Controllers/HeistController.luau")
local OpenModule = moduleScript(Controllers, "ShelfOpenController", "client/Controllers/ShelfOpenController.luau")
RESERVE = {}
moduleScript(Controllers, "ShelfBoxController", {
	value = {
		Reserve = function(key, count)
			table.insert(RESERVE, { key = key, count = count })
		end,
	},
})
local LogicModule = moduleScript(folder(Controllers, "ShelfOpen"), "Logic", "client/Controllers/ShelfOpen/Logic.luau")

-- Assets de Clément (relevé de la vague 31).
local function inst(class, parent, name, props)
	local o = newInstance(class)
	o.Name = name
	for k, v in props or {} do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local Assets = folder(ReplicatedStorage, "Assets")
local UIF = folder(Assets, "UI")
local shelfBoard = inst("BillboardGui", UIF, "BB_ShelfOpen", { AlwaysOnTop = true, MaxDistance = 60 })
local row = inst("Frame", shelfBoard, "Row")
inst("TextLabel", row, "LuckIcon", { Text = "🍀" })
inst("TextLabel", row, "Luck", { Text = "×1.00 LUCK" })
local itemBoard = inst("BillboardGui", UIF, "BB_Item", { MaxDistance = 60, StudsOffset = Vector3.new(0, 2.2, 0) })
inst("TextLabel", itemBoard, "ItemName", { Text = "Soda Can" })
inst("TextLabel", itemBoard, "Rarity", { Text = "COMMON" })
inst("TextLabel", itemBoard, "Mutation", { Text = "BIG GOLD", Visible = false })
inst("TextLabel", itemBoard, "Income", { Text = "+$5/s" })
local FXF = folder(Assets, "FX")
local light = inst("Model", FXF, "FX_ShelfLight")
local lroot = inst("Part", light, "Root", { Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 })
local mouth = inst("Attachment", lroot, "Mouth")
inst("ParticleEmitter", mouth, "Sparkles", { Rate = 14 })
inst("Attachment", lroot, "Up", { Position = Vector3.new(0, 7, 0) })
inst("Beam", lroot, "InnerLight", { Width1 = 3.4 })
inst("PointLight", lroot, "InnerGlow", { Brightness = 0 })
light.PrimaryPart = lroot
local reveal = inst("Model", FXF, "FX_ShelfReveal")
local rroot = inst("Part", reveal, "Root", { Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 })
local center = inst("Attachment", rroot, "Center")
local WHITE = Color3.new(1, 1, 1)
local function pe(parent, name, count, color)
	local e = inst("ParticleEmitter", parent, name, { Rate = 0, Color = color })
	e:SetAttribute("EmitCount", count)
	return e
end
pe(center, "Streaks", 34, ColorSequence.new(WHITE))
pe(center, "Confetti", 60, ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("ffd84a")), ColorSequenceKeypoint.new(0.5, WHITE), ColorSequenceKeypoint.new(1, Color3.fromHex("4fd2ff")) }))
pe(center, "Stars", 22, ColorSequence.new(Color3.fromHex("fff2a8"), WHITE))
pe(inst("Attachment", rroot, "Ground"), "Ring", 1, ColorSequence.new(WHITE))
inst("PointLight", rroot, "Flash", { Brightness = 0 })
inst("Beam", rroot, "Shaft", { Enabled = false })
reveal.PrimaryPart = rroot
SoundsF = folder(Assets, "Sounds")
for _, n in { "Unbox_Open", "Unbox_UpgradePop", "Unbox_Confetti" } do
	inst("Sound", SoundsF, n)
end
inst("Sound", folder(SoundsF, "UI"), "UI_Click")

-- Joueur local.
local player = inst("Player", PlayersService, "P1", { UserId = 1 })
PlayersService.LocalPlayer = player
local playerGui = inst("PlayerGui", player, "PlayerGui")
local hud = inst("ScreenGui", playerGui, "UI_HUD")
local tint = inst("Frame", hud, "RevealTint", { Visible = false, BackgroundTransparency = 0.5, BackgroundColor3 = Color3.new(0, 0, 0) })
local character = inst("Model", Workspace, "P1")
inst("Part", character, "HumanoidRootPart", { CFrame = CFrame.new(0, 3, 5) })
player.Character = character

-- Magasin : Bounds, rayon à 10 emplacements, dossier ShelfBoxes.
local Map = folder(Workspace, "Map")
local store = inst("Model", Map, "STORE_Test")
store:SetAttribute("HeistOpen", true)
inst("Part", store, "Bounds", { CFrame = CFrame.new(0, 5, 0), Size = Vector3.new(60, 10, 40), Transparency = 1 })
local shelf = inst("Part", store, "Shelf", { CFrame = CFrame.new(0, 0, 0), Size = Vector3.new(60, 0.2, 2) })
local function slotPos(n)
	return Vector3.new((n - 5) * 5, 0, 0)
end
for n = 1, 10 do
	inst("Attachment", shelf, string.format("ShelfSlot_%02d", n), { Position = slotPos(n) })
end
CollectionService:AddTag(store, "NPCStore")
local boxesF = folder(store, "ShelfBoxes")

local function makeBox(n, tier, withFlaps)
	local p = slotPos(n)
	local box = newInstance("Model")
	box.Name = if withFlaps then "BOX_Standard" else "BOX_Rare"
	local body = inst("Part", box, "Body", { CFrame = CFrame.new(p + Vector3.new(0, 1, 0)), Size = Vector3.new(2, 2, 2) })
	box.PrimaryPart = body
	box.WorldPivot = CFrame.new(p)
	local lid = inst("Model", box, "Lid")
	if withFlaps then
		local fl = inst("Model", lid, "FlapL")
		inst("Part", fl, "Leaf", { CFrame = CFrame.new(p + Vector3.new(-0.5, 2.1, 0)), Size = Vector3.new(1, 0.2, 2) })
		local fr = inst("Model", lid, "FlapR")
		inst("Part", fr, "Leaf", { CFrame = CFrame.new(p + Vector3.new(0.5, 2.1, 0)), Size = Vector3.new(1, 0.2, 2) })
	else
		inst("Part", lid, "Slab", { CFrame = CFrame.new(p + Vector3.new(0, 2.1, 0)), Size = Vector3.new(2, 0.2, 2) })
	end
	inst("Highlight", box, "OutlineHighlight", { FillTransparency = 1, OutlineTransparency = 0 })
	inst("SelectionBox", box, "Outline")
	inst("BillboardGui", body, "BB_Box")
	box:SetAttribute("SlotId", "STORE_Test:" .. n)
	box:SetAttribute("Slot", string.format("ShelfSlot_%02d", n))
	box:SetAttribute("Tier", tier)
	box:SetAttribute("Landed", true)
	CollectionService:AddTag(box, "ShelfBox")
	box.Parent = boxesF
	return box
end
local function slotAtt(n)
	return shelf:FindFirstChild(string.format("ShelfSlot_%02d", n))
end

local Items = requireModule(ConfigF:FindFirstChild("Items"))
local Balance = requireModule(ConfigF:FindFirstChild("Balance"))
local Rarities = requireModule(ConfigF:FindFirstChild("Rarities"))
local ShelfOpenState = requireModule(Shared:FindFirstChild("ShelfOpenState"))
local ITEM_ID, ITEM_DEF
for id, def in Items.ById do
	if ITEM_ID == nil or id < ITEM_ID then
		ITEM_ID, ITEM_DEF = id, def
	end
end
local function makeItem(n, attrs, parent)
	local m = newInstance("Model")
	m.Name = "ITM_Test"
	local p = slotPos(n)
	local body = inst("Part", m, "Body", { CFrame = CFrame.new(p + Vector3.new(0, 0.75, 0)), Size = Vector3.new(1.5, 1.5, 1) })
	m.PrimaryPart = body
	m.WorldPivot = CFrame.new(p)
	m:SetAttribute("SlotId", "STORE_Test:" .. n)
	m:SetAttribute("ItemId", ITEM_ID)
	for k, v in attrs do
		m:SetAttribute(k, v)
	end
	CollectionService:AddTag(m, "ShelfItem")
	m.Parent = parent or Workspace
	return m
end
local function played(name)
	local list = {}
	for _, p in PLAYED do
		if p.name == name then
			table.insert(list, p)
		end
	end
	return list
end
local function boardsNamed(name)
	local list = {}
	for _, c in playerGui:GetChildren() do
		if c.Name == name then
			table.insert(list, c)
		end
	end
	return list
end

---------------------------------------------------------------- Logic
if SHELF_OPEN then
	print("== ShelfOpen/Logic")
	local Logic = requireModule(LogicModule)
	local ShelfOpen = requireModule(ConfigF:FindFirstChild("ShelfOpen"))
	check(Logic.luckText(1.2345) == "×1.23 LUCK" and Logic.luckText(10) == "×10.00 LUCK", "texte « ×N.NN LUCK »")
	local t0 = 100
	check(Logic.shownLuck(t0, 2, nil, t0 + 0.3) == 1, "chance ×1 pendant les rabats")
	-- L-118 point 4 (2026-11-13) : le tic k tombe à montée × √(k / N), montée de 2 s au plus.
	local firstTick = ShelfOpenState.riseTime(2) * math.sqrt(1 / ShelfOpenState.ticksTo(2))
	check(Logic.shownLuck(t0, 2, nil, t0 + ShelfOpen.FlapsTime + firstTick - 0.01) == 1, "juste avant le premier tic : ×1")
	check(near(Logic.shownLuck(t0, 2, nil, t0 + ShelfOpen.FlapsTime + firstTick + 0.01), 1.03), "premier tic : ×1,03")
	check(ShelfOpenState.riseTime(10) <= 2 + 1e-9 and ShelfOpenState.riseTime(1.5) < ShelfOpenState.riseTime(10), "montée de 2 s au plus, plus courte pour une petite chance")
	local lastGap = ShelfOpenState.riseTime(10) * (1 - math.sqrt(1 - 1 / ShelfOpenState.ticksTo(10)))
	check(lastGap < firstTick, "la montée accélère : le dernier tic est plus serré que le premier")
	check(Logic.shownLuck(t0, 2, nil, t0 + 60) == 2, "jamais au-dessus de la chance tirée")
	local stopped = t0 + ShelfOpen.FlapsTime + 0.55
	check(near(Logic.shownLuck(t0, 5, stopped, t0 + 30), 1.03 ^ 5), "ShelfRevealAt avancé (police) : la chance s'arrête là")
	check(Logic.tickIndex(t0, 1.5, nil, t0 + 60) == ShelfOpenState.ticksTo(1.5) and Logic.tickIndex(t0, 1.5, nil, t0) == 0, "numéro du tic, borné")
	check(Logic.growth(1) == 0 and near(Logic.growth(Logic.MaxLuck), 1) and Logic.growth(2) < Logic.growth(3), "croissance k : 0 à ×1, 1 au plus haut de la table, croissante")
	check(Logic.boxScale(0, nil) == 1 and near(Logic.boxScale(1, nil), 1.6) and near(Logic.boxScale(1, 0), 1.6 * 1.04), "échelle 1 + 0,6 k, battement + 4 %")
	check(Logic.tickPitch(1, 14) == 1 and near(Logic.tickPitch(14, 14), 2) and Logic.tickPitch(1, 1) == 1, "tic : une octave sur la montée")
	check(near(Logic.flapAngle(0), 0) and near(Logic.flapAngle(0.35), math.rad(115)) and Logic.flapAngle(0.2) > math.rad(90), "rabats : 0 → 115° en 0,35 s (Back Out)")
	check(Logic.mutationText("Big", "Gold") == "BIG GOLD" and Logic.mutationText(nil, "Rainbow") == "RAINBOW" and Logic.mutationText(nil, nil) == nil and Logic.mutationText("Nope", nil) == nil, "ligne Mutation « BIG GOLD », nil sans mutation")
	check(Logic.wantsTint("Epic") and Logic.wantsTint("Divine") and not Logic.wantsTint("Rare") and not Logic.wantsTint(nil), "voile : Épique et plus")
	check(Logic.canTake(2, 50, 1, 49) == false and Logic.canTake(1, 50, 1, 49) and Logic.canTake(2, 50, 1, 50) and Logic.canTake(nil, nil, 1, 0), "réservation : ouvreur seul, puis tous")
	local flapBox = newInstance("Model")
	local lid = inst("Model", flapBox, "Lid")
	inst("Model", lid, "FlapL")
	check(Logic.lidPlan(flapBox).Mode == "Lid", "un seul rabat : le Lid entier")
	inst("Model", lid, "FlapR")
	check(Logic.lidPlan(flapBox).Mode == "Flaps" and #Logic.lidPlan(flapBox).Parts == 2, "FlapL et FlapR : les rabats")
	check(Logic.lidPlan(newInstance("Model")).Mode == "None", "sans Lid : rien ne s'ouvre")
	check(Rarities.ById.Epic ~= nil and Logic.rarityColor("Epic") == Rarities.ById.Epic.Color and Logic.rarityColor("x") == WHITE, "couleur de rareté")
end

---------------------------------------------------------------- HeistController
print("== HeistController" .. (if SHELF_OPEN then " (ShelfOpen)" else " (ShelfOpen = false)"))
local box1 = makeBox(1, "Standard", false)
local box3 = makeBox(3, "Luxe", false)
local Heist = requireModule(HeistModule)
taskLib.spawn(Heist.Start)
advance(0.3)
local p1 = slotAtt(1):FindFirstChild("GrabPrompt")
local std = Balance.Heist.BoxTiers.Standard
check(p1 ~= nil, "une invite sur le colis")
if SHELF_OPEN then
	check(p1.ActionText == "Open" and p1.HoldDuration == 0 and p1.ObjectText == std.DisplayName .. " Box", "« Open », un appui, « Standard Box »")
	check(p1.Enabled == true, "invite active (magasin ouvert, dedans, mains vides)")
	p1.Triggered:Fire()
	check(#NET.open == 1 and NET.open[1] == "STORE_Test:1" and #NET.grab == 0, "appui : OpenShelfBox(slotId), pas de GrabItem")
	check(p1.Enabled == false, "invite coupée tout de suite après l'appui")
	advance(0.5)
	check(p1.Enabled == false, "toujours coupée en attendant le serveur")
	advance(0.7)
	check(p1.Enabled == true, "réponse jamais venue : invite rendue après 1 s")
	box1:SetAttribute("ShelfOpenState", "Opening")
	advance(0.25)
	check(p1.Enabled == false, "colis en cours d'ouverture : plus d'invite")
	box1:SetAttribute("ShelfOpenState", nil)
	-- Objet sorti à l'emplacement 3 (le colis Luxe consommé), réservé à un autre joueur.
	box3:Destroy()
	advance(0.1)
	local item = makeItem(3, { Rarity = "Rare", ShelfReservedBy = 2, ShelfReservedUntil = serverNow() + 5, Income = 10 }, boxesF)
	advance(0.25)
	check(slotAtt(3):FindFirstChild("GrabPrompt") == nil, "pas d'invite « Open » sur l'objet sorti")
	local ip = item.Body:FindFirstChild("ShelfItemPrompt")
	check(ip ~= nil and ip.ActionText == "Steal" and ip.ObjectText == ITEM_DEF.DisplayName, "invite « Steal » sur l'objet, à son nom")
	check(ip ~= nil and near(ip.HoldDuration, Balance.Heist.BoxTiers.Luxe.GrabTime), "maintien du Tier du colis de l'emplacement (Luxe)")
	check(ip ~= nil and ip.Enabled == false, "réservé à un autre : invite cachée")
	advance(5.1)
	check(ip ~= nil and ip.Enabled == true, "réservation passée : invite pour tous")
	local mine = makeItem(4, { Rarity = "Rare", Tier = "Premium", ShelfReservedBy = 1, ShelfReservedUntil = serverNow() + 5 }, Workspace)
	advance(0.25)
	local mp = mine.Body:FindFirstChild("ShelfItemPrompt")
	check(mp ~= nil and mp.Enabled == true and near(mp.HoldDuration, Balance.Heist.BoxTiers.Premium.GrabTime), "réservé à moi : invite tout de suite (hors du dossier, par Bounds ; Tier de l'objet)")
	mp.PromptButtonHoldBegan:Fire()
	mp.Triggered:Fire()
	check(#NET.grab == 2 and NET.grab[1] == "STORE_Test:4" and NET.grab[2] == "STORE_Test:4", "prise : GrabItem(slotId) au début et à la fin")
	player:SetAttribute("Carrying", "Common")
	advance(0.25)
	check(mp.Enabled == false, "mains pleines : invite coupée")
	player:SetAttribute("Carrying", nil)
	advance(0.25)
	CollectionService:RemoveTag(mine, "ShelfItem")
	check(mp.Parent == nil, "tag retiré : invite détruite")
	item:Destroy()
	check(ip.Parent == nil, "objet détruit : invite détruite")
else
	check(p1.ActionText == "Steal" and near(p1.HoldDuration, std.GrabTime), "ancien comportement : « Steal », maintien du type")
	p1.PromptButtonHoldBegan:Fire()
	p1.Triggered:Fire()
	check(#NET.grab == 2 and #NET.open == 0, "ancien comportement : GrabItem début et fin, jamais OpenShelfBox")
	local item = makeItem(3, { Rarity = "Rare" }, boxesF)
	advance(0.25)
	check(item.Body:FindFirstChild("ShelfItemPrompt") == nil, "ancien comportement : aucune invite d'objet sorti")
	item:Destroy()
end

---------------------------------------------------------------- ShelfOpenController
print("== ShelfOpenController")
local Open = requireModule(OpenModule)
taskLib.spawn(Open.Start)
local function sessionOf(box)
	for _, s in Open.GetState() do
		if s.Box == box then
			return s
		end
	end
	return nil
end
local function fxFolder()
	return Workspace:FindFirstChild("_ShelfOpenFX")
end

if not SHELF_OPEN then
	local b = makeBox(5, "Standard", true)
	b:SetAttribute("ShelfOpenAt", serverNow())
	b:SetAttribute("ShelfLuck", 2)
	b:SetAttribute("ShelfRevealAt", serverNow() + 2)
	b:SetAttribute("ShelfOpenState", "Opening")
	advance(1)
	check(#Open.GetState() == 0 and fxFolder() == nil and #boardsNamed("BB_ShelfOpen") == 0, "ShelfOpen = false : rien ne s'anime")
	check(errorsInLog() == 0, "aucune erreur")
	return
end

local function open(box, luck, by)
	local now = serverNow()
	box:SetAttribute("ShelfOpenBy", by or 1)
	box:SetAttribute("ShelfOpenAt", now)
	box:SetAttribute("ShelfLuck", luck)
	box:SetAttribute("ShelfRevealAt", now + ShelfOpenState.revealDelay(luck))
	box:SetAttribute("ShelfOpenState", "Opening")
	return now
end

-- A : rabats, chance ×1,5 ; B : sans rabats, ×1.
local A = makeBox(5, "Standard", true)
local B = makeBox(6, "Standard", false)
local flapL = A.Lid.FlapL.Leaf
local flapR = A.Lid.FlapR.Leaf
local flapLY, flapRY = flapL.Position.Y, flapR.Position.Y
local flapLOrig = flapL.CFrame
local slab = B.Lid.Slab
local slabOrig = slab.CFrame
local openA = open(A, 1.5)
local openB = open(B, 1)
advance(0.2)
check(sessionOf(A) ~= nil and sessionOf(A).Phase == "Opening" and sessionOf(A).Mode == "Flaps", "A : ouverture suivie, rabats")
check(flapL.Position.Y > flapLY + 0.3 and flapR.Position.Y > flapRY + 0.3, "les deux rabats se lèvent")
check(flapL.Position.X < slotPos(5).X - 0.5 and flapR.Position.X > slotPos(5).X + 0.5, "chacun bascule vers l'extérieur (charnière sur son bord extérieur)")
check(sessionOf(B) ~= nil and sessionOf(B).Mode == "Lid", "B (BOX_<Rareté> sans rabats) : le Lid entier")
check(slab.Position.Y > slabOrig.Position.Y + 0.3 and slab.Position.Z > slabOrig.Position.Z, "le Lid se lève et bascule vers l'arrière (+Z)")
check(#played("Unbox_Open") == 2, "son des rabats, une fois par colis")
check(#boardsNamed("BB_ShelfOpen") == 0, "pas encore de compteur pendant les rabats")
advance(0.45)
local boards = boardsNamed("BB_ShelfOpen")
check(#boards == 1 and boards[1].Adornee == A.Body, "compteur sur A seulement (B tiré à ×1)")
local lightA
for _, c in (if fxFolder() then fxFolder():GetChildren() else {}) do
	if c.Name == "FX_ShelfLight" and math.abs(c.Root.Position.X - slotPos(5).X) < 0.5 then
		lightA = c
	end
end
check(lightA ~= nil, "FX_ShelfLight sorti")
check(lightA ~= nil and near(lightA.Root.Position.Y, 2.1 + 0.1, 0.05), "lumière posée sur le haut du colis")
-- Montée : chance, échelle, tics.
local luckLabel = boards[1]:FindFirstChild("Luck", true)
local sawScaled = false
local sawLabel = true
for _ = 1, 30 do
	advance(1 / 60)
	local shown = ShelfOpenState.luckAt(openA, 1.5, serverNow() + 1e-6)
	if luckLabel.Text ~= string.format("×%.2f LUCK", shown) then
		sawLabel = false
	end
	if A:GetScale() > 1.01 then
		sawScaled = true
	end
end
check(sawLabel, "« ×N.NN LUCK » suit luckAt à l'heure du serveur")
check(sawScaled, "le colis grandit avec la chance")
check(lightA:FindFirstChild("InnerLight", true).Width1 > 3.4 and lightA:FindFirstChild("InnerGlow", true).Brightness > 3, "la lumière grandit avec la chance")
check(near(lightA.Root.Position.Y, A:GetBoundingBox().Position.Y + select(2, A:GetBoundingBox()).Y / 2, 0.05) or lightA.Root.Position.Y > 2.25, "la lumière suit le haut du colis")
advance(ShelfOpenState.revealDelay(1.5))
check(luckLabel.Text == "×1.50 LUCK", "compteur arrêté à la chance tirée")
check(sessionOf(A).Phase == "Waiting", "A attend l'objet du serveur")
local ticks = played("UI_Click")
check(#ticks == ShelfOpenState.ticksTo(1.5), "un tic par marche : " .. #ticks)
check(near(ticks[1].sound.PlaybackSpeed, 1) and near(ticks[#ticks].sound.PlaybackSpeed, 2), "le tic monte d'une octave")
check(sessionOf(B).Phase == "Waiting", "B : sortie juste après les rabats (×1)")

-- B : le serveur dit « Revealed » mais l'objet n'arrive jamais chez nous : éclatement seul, puis fin.
B:SetAttribute("ShelfOpenState", "Revealed")
advance(2.2)
check(sessionOf(B) ~= nil and sessionOf(B).Phase == "Revealing" and B.Body.LocalTransparencyModifier == 1, "B sans objet : colis caché, éclatement")

-- A : l'objet arrive (Épique, BIG GOLD), hors du magasin, relié par SlotId.
local beforePop = #played("Unbox_UpgradePop")
local itemA = makeItem(5, { Rarity = "Epic", Income = 7200, MutationSize = "Big", MutationEffect = "Gold", ShelfReservedBy = 1, ShelfReservedUntil = serverNow() + 5 })
local itemPivot = itemA:GetPivot()
local sA = sessionOf(A)
check(sA ~= nil and sA.Phase == "Revealing" and sA.Item == itemA, "l'objet arrivé lance la sortie")
check(A.Body.LocalTransparencyModifier == 1 and A.Lid.FlapL.Leaf.LocalTransparencyModifier == 1, "le colis disparaît (en local)")
check(A.OutlineHighlight.OutlineTransparency == 1 and A.Outline.Visible == false and A.Body:FindFirstChild("BB_Box") == nil, "son contour noir et BB_Box aussi")
check(near(itemA:GetScale(), 0.2) and itemA:FindFirstChild("ShelfRevealWhite") ~= nil, "l'objet sort petit et blanc")
check(#RESERVE > 0 and RESERVE[#RESERVE].count == 1 and RESERVE[#RESERVE].key == "ShelfOpen", "Highlight blanc réservé chez ShelfBoxController")
local revealFx
for _, c in fxFolder():GetChildren() do
	if c.Name == "FX_ShelfReveal" and (c.Root.Position - Vector3.new(slotPos(5).X, 0, 0)).Magnitude < 3 then
		revealFx = c
	end
end
check(revealFx ~= nil, "FX_ShelfReveal au centre du colis")
local epic = Rarities.ById.Epic.Color
check(revealFx ~= nil and rawget(revealFx.Root.Center.Confetti, "_emitted") == 60 and rawget(revealFx.Root.Center.Streaks, "_emitted") == 34 and rawget(revealFx.Root.Ground.Ring, "_emitted") == 1, "Emit(EmitCount) sur chaque émetteur")
check(revealFx ~= nil and revealFx.Root.Center.Confetti.Color.Keypoints[2].Value == epic and revealFx.Root.Ground.Ring.Color.Keypoints[1].Value == epic, "couleurs de la rareté")
check(revealFx ~= nil and revealFx.Root.Flash.Brightness == 9 and revealFx.Root.Shaft.Enabled == true, "Flash à 9, Shaft allumé")
check(tint.Visible == true and tint.BackgroundColor3 == epic and near(tint.BackgroundTransparency, 0.62), "RevealTint chez l'ouvreur (Épique)")
check(#played("Unbox_UpgradePop") == beforePop + 1, "son de sortie")
check(fxFolder():FindFirstChild("FX_ShelfLight") == nil or fxFolder():FindFirstChild("FX_ShelfLight") ~= lightA, "la lumière s'éteint")
advance(0.65)
check(near(itemA:GetScale(), 1) and (itemA:GetPivot().Position - itemPivot.Position).Magnitude < 1e-6, "l'objet revient à sa taille, à sa place")
check(itemA:FindFirstChild("ShelfRevealWhite") == nil and RESERVE[#RESERVE].count == 0, "blanc retiré, réservation rendue")
check(#played("Unbox_Confetti") >= 1, "puis les confettis")
local ib = Open.GetItemBoards()[itemA]
check(ib ~= nil and ib.Parent == playerGui and ib.Adornee == itemA.Body, "BB_Item au-dessus de l'objet")
check(ib ~= nil and ib.ItemName.Text == ITEM_DEF.DisplayName and ib.Rarity.Text == "EPIC" and ib.Rarity.TextColor3 == epic and ib.Income.Text == "+$7.2K/s", "BB_Item : nom, rareté, $/s")
check(ib ~= nil and ib.Mutation.Text == "BIG GOLD" and ib.Mutation.Visible == true, "ligne Mutation « BIG GOLD » montrée")
check(tint.Visible == false and tint.BackgroundTransparency == 0.5 and tint.BackgroundColor3 == Color3.new(0, 0, 0), "voile rendu tel quel")
check(#boardsNamed("BB_ShelfOpen") == 0, "compteur retiré")
advance(3)
check(sessionOf(A) == nil and sessionOf(B) == nil, "ouvertures terminées")
check(#fxFolder():GetChildren() == 0, "tous les FX libérés")
check(near(A:GetScale(), 1) and A.Body.LocalTransparencyModifier == 1, "colis A remis à sa taille, toujours caché")
B:SetAttribute("ShelfOpenState", nil)
advance(0.05)
check(B.Body.LocalTransparencyModifier == 0 and B.OutlineHighlight.OutlineTransparency == 0 and B.Outline.Visible == true, "état remis à nil : colis caché réaffiché")
check(Open.GetItemBoards()[itemA] ~= nil, "BB_Item reste tant que l'objet est sur le rayon")
itemA:Destroy()
advance(0.05)
check(Open.GetItemBoards()[itemA] == nil and ib.Parent == nil, "objet parti : BB_Item détruit")

-- C : police pendant la montée (ShelfRevealAt avancé), puis annulation.
local C = makeBox(7, "Standard", true)
local cFlap = C.Lid.FlapL.Leaf
local cFlapOrig = cFlap.CFrame
local cBodyOrig = C.Body.CFrame
open(C, 3)
advance(1.2)
C:SetAttribute("ShelfRevealAt", serverNow())
advance(0.1)
local cBoard = boardsNamed("BB_ShelfOpen")[1]
local frozen = cBoard and cBoard:FindFirstChild("Luck", true).Text
advance(0.5)
check(cBoard ~= nil and cBoard:FindFirstChild("Luck", true).Text == frozen and frozen ~= "×3.00 LUCK", "police : la chance reste là où elle était (" .. tostring(frozen) .. ")")
check(sessionOf(C) ~= nil and sessionOf(C).Phase == "Waiting", "C attend l'objet")
C:SetAttribute("ShelfOpenState", nil)
advance(0.05)
check(sessionOf(C) == nil, "annulée : ouverture arrêtée")
check(near(C:GetScale(), 1) and (cFlap.Position - cFlapOrig.Position).Magnitude < 1e-6 and (C.Body.Position - cBodyOrig.Position).Magnitude < 1e-6, "colis remis comme avant (taille, rabats)")
check(cBoard.Parent == nil and #fxFolder():GetChildren() == 0, "compteur et lumière libérés")

-- D : ouvert par un autre, Légendaire sans mutation.
local D = makeBox(8, "Standard", false)
open(D, 1, 2)
advance(0.7)
local itemD = makeItem(8, { Rarity = "Legendary", Income = 50 })
check(tint.Visible == false, "pas de voile chez les autres joueurs")
advance(0.5)
local ibD = Open.GetItemBoards()[itemD]
check(ibD ~= nil and ibD.Mutation.Visible == false, "sans mutation : ligne Mutation cachée")
advance(3)
check(#Open.GetState() == 0 and #fxFolder():GetChildren() == 0, "tout est libéré")

-- E : objet déjà sorti quand on arrive (pas d'ouverture suivie) : BB_Item sans animation.
local itemE = makeItem(9, { Rarity = "Common", Income = 5 })
check(Open.GetItemBoards()[itemE] ~= nil and near(itemE:GetScale(), 1), "objet déjà sorti : BB_Item, sans animation")

check(errorsInLog() == 0, "aucune erreur ni avertissement des contrôleurs")
