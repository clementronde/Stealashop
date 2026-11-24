---------------------------------------------------------------- banc a161 (vague 50, L-165 point 5)
-- Collé après le début du banc a80 (mise en place jusqu'avant V1). Grand socle RarestDisplay, chance
-- formatée (Shared/ItemOdds), codage des leaderboards (Config/Leaderboard), ancien socle sans RarestDisplay.
local VfxCfg = requireModule(ReplicatedStorage.Shared.Config.Vfx, "client")
local RaritiesC = requireModule(ReplicatedStorage.Shared.Config.Rarities, "client")
local ItemsC = requireModule(ReplicatedStorage.Shared.Config.Items, "client")
local ShelfOpenC = requireModule(ReplicatedStorage.Shared.Config.ShelfOpen, "client")
local MutC = requireModule(ReplicatedStorage.Shared.Config.Mutations, "client")
local Odds = requireModule(ReplicatedStorage.Shared.ItemOdds, "client")
local LB = requireModule(ReplicatedStorage.Shared.Config.Leaderboard, "client")
requireModule(CHASE_MODULE, "client")
requireModule(CONTROLLERS.ShelfBoxController, "client")
requireModule(CONTROLLERS.DisplayController, "client")
requireModule(ReplicatedStorage.Shared.Net.Net, "server")
local Vfx = requireModule(VFX_MODULE, "client")
taskLib.spawn(Vfx.Start)
step(0.1)

local function named(parent, name)
	local out = {}
	for _, child in parent:GetChildren() do
		if child.Name == name then
			table.insert(out, child)
		end
	end
	return out
end

print("\n== O. Chance formatée (Shared/ItemOdds)")
check(Odds.Format(5300000000) == "1 in 5,300,000,000", `O1 « 1 in 5,300,000,000 » ({Odds.Format(5300000000)})`)
check(Odds.Format(1) == "1 in 1" and Odds.Format(999) == "1 in 999" and Odds.Format(1000) == "1 in 1,000", "O2 1, 999, 1,000")
check(Odds.Format(123456.4) == "1 in 123,456", `O3 arrondi ({Odds.Format(123456.4)})`)
check(Odds.Format(2e15) == "1 in 2Qa" and Odds.Format(0 / 0) == "1 in 1", `O4 très grand, NaN ({Odds.Format(2e15)})`)
local box = VfxCfg.RarestDisplay.OddsBox
local weights = ShelfOpenC.BoxRarityOdds[box]
local total = 0
for _, w in weights do
	total += w
end
local common, mythic, secret, tutorial
for _, item in ItemsC.List do
	if item.TutorialOnly then
		tutorial = tutorial or item
	elseif item.Rarity == "Common" and item.Zone == 2 then
		common = common or item
	elseif item.Rarity == "Mythic" then
		mythic = mythic or item
	elseif item.Rarity == "Secret" then
		secret = secret or item
	end
end
local pc = weights.Common / total / #ItemsC.ByZone[2].Common
check(math.abs(Odds.Chance(common.Id, nil, box) - pc) < 1e-12, `O5 Commun zone 2 : poids / total / objets ({Odds.Chance(common.Id, nil, box)} ≈ {pc})`)
local ps = weights.Secret / total / #ItemsC.Secrets * (MutC.SizeById.Colossal.Chance / 100) * (MutC.EffectById.Rainbow.Chance / 100)
local got = Odds.Chance(secret.Id, { Size = "Colossal", Effect = "Rainbow" }, box)
check(got ~= nil and math.abs(got / ps - 1) < 1e-9, `O6 Secret Colossal Rainbow, toutes zones ({got} ≈ {ps})`)
check(Odds.OneIn(secret.Id, { Size = "Colossal", Effect = "Rainbow" }, box) == math.round(1 / ps), `O7 OneIn = 1 / chance arrondi ({Odds.Format(Odds.OneIn(secret.Id, { Size = "Colossal", Effect = "Rainbow" }, box))})`)
check(Odds.OneIn(secret.Id, { Size = "Nope" }, box) == Odds.OneIn(secret.Id, nil, box), "O8 mutation inconnue ignorée")
check(tutorial == nil or Odds.OneIn(tutorial.Id, nil, box) == nil, "O9 objet TutorialOnly : pas de chance")
check(Odds.OneIn("Nope", nil, box) == nil and Odds.OneIn(common.Id, nil, "Nope") == nil, "O10 objet ou caisse inconnus : nil")

print("\n== C. Codage des leaderboards (Config/Leaderboard)")
for _, v in { 1, 12.5, 1234, 9.9e14, 3.3e20, 1e33 } do
	local e = LB.Encode("Income", v)
	local d = LB.Decode("Income", e)
	check(e == math.floor(e) and e < 2 ^ 53 and math.abs(d / v - 1) < 1e-9, `C1 revenu {v} : entier {e} relu {d}`)
end
check(LB.Encode("Income", 1001) > LB.Encode("Income", 1000), "C2 codage croissant")
check(LB.Encode("Income", -5) == 0 and LB.Encode("Income", 0 / 0) == 0 and LB.Encode("Speed", 0) == 0, "C3 valeur invalide : 0")
check(LB.Encode("Speed", 123.9) == 123 and LB.Decode("Speed", 123) == 123, "C4 vitesse : entier vers le bas")
check(LB.StoreName("Income", false) == "Leaderboard_Income" and LB.StoreName("Speed", true) == "Leaderboard_Speed_DEV" and LB.StoreName("X", false) == nil, "C5 noms des stores (suffixe DEV)")

print("\n== R. Grand socle RarestDisplay")
do
	local bb = new("BillboardGui", { Name = "BB_RarestDisplay", MaxDistance = 200 })
	new("TextLabel", { Name = "Header", Text = "RAREST PULL" }, bb)
	new("TextLabel", { Name = "Rarity", Text = "?" }, bb)
	new("TextLabel", { Name = "ItemName", Text = "?" }, bb)
	new("TextLabel", { Name = "Mutation", Text = "?" }, bb)
	new("TextLabel", { Name = "Odds", Text = "?" }, bb)
	bb.Parent = UI
end
local plot = new("Model", { Name = "PLOT_Shop_01" })
local pedestal = new("Model", { Name = "RarestPedestal" }, plot)
local plate = new("Part", { Name = "TopPlate", CFrame = CFrame.new(0, 4, 0) }, pedestal)
local oldPoint = new("Attachment", { Name = "RarestLabelPoint", CFrame = CFrame.new(0, 1, 0) }, plate)
new("Attachment", { Name = "RarestSlot", CFrame = CFrame.new(0, 0.5, 0) }, plate)
local display = new("Model", { Name = "RarestDisplay" }, plot)
local base = new("Part", { Name = "Base", CFrame = CFrame.new(20, 1, 0), Size = Vector3.new(12, 2, 8) }, display)
local itemPoint = new("Attachment", { Name = "ItemPoint", CFrame = CFrame.new(0, 1, 0) }, base)
local labelPoint = new("Attachment", { Name = "LabelPoint", CFrame = CFrame.new(0, 12, 0) }, base)
local items = folder(plot, "DisplayItems")
plot.Parent = Workspace
addTag(plot, "PlayerPlot")
local function exposed(item, income, size, effect)
	local m = new("Model", { Name = "DisplayItem_" .. item.Id })
	local part = new("Part", { Name = "Body", CFrame = CFrame.new(-30, 2, 0), Size = Vector3.new(3, 4, 3) }, m)
	m.PrimaryPart = part
	m:SetAttribute("ItemId", item.Id)
	m:SetAttribute("Rarity", item.Rarity)
	m:SetAttribute("Income", income)
	m:SetAttribute("ItemUid", "uid-" .. item.Id)
	m:SetAttribute("MutationSize", size)
	m:SetAttribute("MutationEffect", effect)
	m.Parent = items
	return m
end
local mCommon = exposed(common, 999)
local mMythic = exposed(mythic, 5, "Big", "Gold")
mMythic:ScaleTo(1.5)
step(1.1)
local bbs = named(labelPoint, VfxCfg.Rarest.CopyName)
check(#bbs == 1 and bbs[1].Adornee == labelPoint, "R1 une copie de BB_RarestDisplay sur LabelPoint")
check(#named(oldPoint, VfxCfg.Rarest.CopyName) == 0, "R2 l'ancien socle n'a rien quand RarestDisplay existe")
local gui = bbs[1]
check(gui ~= nil and gui:FindFirstChild("Header", true) ~= nil and gui:FindFirstChild("Header", true).Text == "RAREST PULL", "R3 copie de BB_RarestDisplay, Header de Clément gardé")
local function text(name)
	local l = gui and gui:FindFirstChild(name, true)
	if l == nil then
		return nil, nil
	end
	return l.Text, l.Visible
end
local rarityText = text("Rarity")
check(rarityText == "MYTHIC" and sameColor(gui:FindFirstChild("Rarity", true).TextColor3, RaritiesC.ById.Mythic.Color), `R4 Rarity MYTHIC à sa couleur ({rarityText})`)
check(text("ItemName") == mythic.DisplayName, `R5 ItemName = {mythic.DisplayName}`)
local mt, mv = text("Mutation")
check(mt == "BIG · GOLD" and mv == true, `R6 Mutation « BIG · GOLD » visible ({mt})`)
local expected = Odds.Format(Odds.OneIn(mythic.Id, { Size = "Big", Effect = "Gold" }, box))
local ot, ov = text("Odds")
check(ot == expected and ov == true and string.match(ot or "", "^1 in [%d,]+$") ~= nil, `R7 Odds « {expected} » ({ot})`)
local copies = named(display, VfxCfg.Rarest.ItemName)
local copy = copies[1]
check(#copies == 1 and #named(pedestal, VfxCfg.Rarest.ItemName) == 0, "R8 l'objet est posé dans RarestDisplay, pas sur l'ancien socle")
local body = copy and copy:FindFirstChild("Body")
local src = mMythic:FindFirstChild("Body")
check(body ~= nil and (body.Size - src.Size).Magnitude < 1e-6 and math.abs(body.Size.Y - 6) < 1e-6, `R9 taille réelle (mutation Big comprise, jamais réduite) : {body and body.Size}`)
check(copy ~= nil and (copy:GetPivot().Position - itemPoint.WorldPosition).Magnitude < 1e-6, "R10 pivot de l'objet sur ItemPoint")
check(body ~= nil and body.Anchored == true and body.CanCollide == false, "R11 copie ancrée, sans collision")
-- Sans mutation : ligne Mutation cachée.
mMythic:SetAttribute("MutationSize", nil)
mMythic:SetAttribute("MutationEffect", nil)
step(1.1)
mt, mv = text("Mutation")
ot = text("Odds")
check(mv == false and mt == "", "R12 sans mutation : Mutation cachée")
check(ot == Odds.Format(Odds.OneIn(mythic.Id, nil, box)), `R13 Odds recalculée sans mutation ({ot})`)
-- Le plus rare part : l'objet suivant.
mMythic:Destroy()
step(1.1)
check(text("ItemName") == common.DisplayName and #named(display, VfxCfg.Rarest.ItemName) == 1, "R14 l'objet suivant prend la place")
-- BB_RarestDisplay absent : BB_Rarest sur LabelPoint, Odds affichée.
UI:FindFirstChild("BB_RarestDisplay"):Destroy()
display.Parent = nil
step(1.1)
display.Parent = plot
step(1.1)
bbs = named(labelPoint, VfxCfg.Rarest.CopyName)
gui = bbs[1]
check(#bbs == 1 and gui:FindFirstChild("Title", true) ~= nil, "R15 BB_RarestDisplay absent : BB_Rarest sur LabelPoint")
ot, ov = text("Odds")
check(ov == true and ot == Odds.Format(Odds.OneIn(common.Id, nil, box)), `R16 Odds affichée sur le grand socle ({ot})`)
-- RarestDisplay retiré : l'ancien socle comme avant (Odds caché, objet sur RarestSlot).
display:Destroy()
step(1.1)
local old = named(oldPoint, VfxCfg.Rarest.CopyName)
check(#old == 1 and #named(labelPoint, VfxCfg.Rarest.CopyName) == 0, "R17 sans RarestDisplay : BB_Rarest sur l'ancien socle")
local oldOdds = old[1] and old[1]:FindFirstChild("Odds", true)
check(oldOdds ~= nil and oldOdds.Visible == false, "R18 ancien socle : Odds caché, comme avant")
check(#named(pedestal, VfxCfg.Rarest.ItemName) == 1, "R19 ancien socle : objet sur RarestSlot")
mCommon:Destroy()
step(1.1)
check(Vfx.GetState().Rarest == 0, "R20 plus rien d'exposé : rien")

summary()
