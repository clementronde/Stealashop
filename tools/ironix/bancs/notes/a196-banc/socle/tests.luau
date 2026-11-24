---------------------------------------------------------------- banc a196, partie socle (vague 60, T-096)
-- « BEST ITEM » : l'objet exposé au plus gros revenu (attribut Income de DisplayService), titre écrit dans Header /
-- Title, revenu/s dans Income (sinon dans Odds), copie de l'objet changée quand on expose mieux.
local VfxCfg = requireModule(ReplicatedStorage.Shared.Config.Vfx, "client")
local ItemsC = requireModule(ReplicatedStorage.Shared.Config.Items, "client")
local FormatC = requireModule(ReplicatedStorage.Shared.Format, "client")
local Odds = requireModule(ReplicatedStorage.Shared.ItemOdds, "client")
requireModule(CHASE_MODULE, "client")
requireModule(CONTROLLERS.ShelfBoxController, "client")
requireModule(CONTROLLERS.DisplayController, "client")
requireModule(ReplicatedStorage.Shared.Net.Net, "server")
local Vfx = requireModule(VFX_MODULE, "client")
taskLib.spawn(Vfx.Start)
step(0.1)
local R = VfxCfg.Rarest
check(R.Pick == "Income" and R.Title == "BEST ITEM" and R.IncomeField == "Income" and R.IncomeFallback == "Odds", "S0 réglages : Pick Income, BEST ITEM, Income, repli Odds")

local function named(parent, name)
	local out = {}
	for _, child in parent:GetChildren() do
		if child.Name == name then
			table.insert(out, child)
		end
	end
	return out
end
local common, mythic, legendary
for _, item in ItemsC.List do
	if not item.TutorialOnly then
		if item.Rarity == "Common" and item.Zone == 2 then
			common = common or item
		elseif item.Rarity == "Mythic" then
			mythic = mythic or item
		elseif item.Rarity == "Legendary" then
			legendary = legendary or item
		end
	end
end

local bb = new("BillboardGui", { Name = "BB_RarestDisplay", MaxDistance = 200 })
new("TextLabel", { Name = "Header", Text = "RAREST PULL" }, bb)
new("TextLabel", { Name = "Rarity", Text = "?" }, bb)
new("TextLabel", { Name = "ItemName", Text = "?" }, bb)
new("TextLabel", { Name = "Mutation", Text = "?" }, bb)
new("TextLabel", { Name = "Odds", Text = "?" }, bb)
bb.Parent = UI
local plot = new("Model", { Name = "PLOT_Shop_01" })
local pedestal = new("Model", { Name = "RarestPedestal" }, plot)
local plate = new("Part", { Name = "TopPlate", CFrame = CFrame.new(0, 4, 0) }, pedestal)
local oldPoint = new("Attachment", { Name = "RarestLabelPoint", CFrame = CFrame.new(0, 1, 0) }, plate)
new("Attachment", { Name = "RarestSlot", CFrame = CFrame.new(0, 0.5, 0) }, plate)
local display = new("Model", { Name = "RarestDisplay" }, plot)
local base = new("Part", { Name = "Base", CFrame = CFrame.new(20, 1, 0), Size = Vector3.new(12, 2, 8) }, display)
new("Attachment", { Name = "ItemPoint", CFrame = CFrame.new(0, 1, 0) }, base)
local labelPoint = new("Attachment", { Name = "LabelPoint", CFrame = CFrame.new(0, 12, 0) }, base)
local items = folder(plot, "DisplayItems")
plot.Parent = Workspace
addTag(plot, "PlayerPlot")
local function exposed(item, income, uid)
	local m = new("Model", { Name = "DisplayItem_" .. uid })
	local part = new("Part", { Name = "Body", CFrame = CFrame.new(-30, 2, 0), Size = Vector3.new(3, 4, 3) }, m)
	m.PrimaryPart = part
	m:SetAttribute("ItemId", item.Id)
	m:SetAttribute("Rarity", item.Rarity)
	m:SetAttribute("Income", income)
	m:SetAttribute("ItemUid", uid)
	m.Parent = items
	return m
end
local function gui()
	return named(labelPoint, R.CopyName)[1]
end
local function text(name)
	local g = gui()
	local l = g and g:FindFirstChild(name, true)
	if l == nil then
		return nil, nil
	end
	return l.Text, l.Visible
end
local function copyId()
	local list = named(display, R.ItemName)
	return list[1] and list[1]:GetAttribute("ItemId"), #list
end

-- S1. Le plus gros revenu passe avant le plus rare.
exposed(common, 999, "uid-b")
local mMythic = exposed(mythic, 5, "uid-a")
step(1.1)
check(text("ItemName") == common.DisplayName, `S1 Commun à 999 $/s avant Mythique à 5 $/s ({text("ItemName")})`)
check(text("Header") == "BEST ITEM", `S1 Header « BEST ITEM » ({text("Header")})`)
local ot, ov = text("Odds")
check(ot == FormatC.income(999) and ov == true, `S1 sans Income : revenu/s dans Odds ({ot})`)
local id, n = copyId()
check(id == common.Id and n == 1, `S1 la copie sur le socle est l'objet au plus gros revenu ({id}, {n})`)

-- S2. On expose mieux : le socle change.
mMythic:SetAttribute("Income", 2500)
step(1.1)
check(text("ItemName") == mythic.DisplayName and text("Odds") == FormatC.income(2500), `S2 revenu monté : Mythique à {text("Odds")}`)
id, n = copyId()
check(id == mythic.Id and n == 1, `S2 copie refaite : l'objet au plus gros revenu, une seule ({id}, {n})`)
local mLeg = exposed(legendary, 4000, "uid-c")
step(1.1)
check(text("ItemName") == legendary.DisplayName and text("Rarity") == "LEGENDARY", `S2 nouvel objet mieux payé : Légendaire ({text("ItemName")})`)

-- S3. Même revenu : le plus rare, puis le plus petit ItemUid.
mLeg:SetAttribute("Income", 2500)
step(1.1)
check(text("ItemName") == mythic.DisplayName, `S3 même revenu : le plus rare (Mythique) ({text("ItemName")})`)
local mMythic2 = exposed(mythic, 2500, "uid-0")
step(1.1)
local list = named(display, R.ItemName)
check(#list == 1 and text("ItemName") == mythic.DisplayName, `S3 même revenu, même rareté : le plus petit ItemUid, une seule copie ({#list})`)
mMythic2:Destroy()
step(1.1)

-- S4. Income livré par Clément : le revenu y va, Odds garde la chance.
new("TextLabel", { Name = "Income", Text = "?" }, bb)
display.Parent = nil
step(1.1)
display.Parent = plot
step(1.1)
local it, iv = text("Income")
check(it == FormatC.income(2500) and iv == true, `S4 Income « {it} »`)
ot = text("Odds")
check(ot == Odds.Format(Odds.OneIn(mythic.Id, nil, VfxCfg.RarestDisplay.OddsBox)), `S4 Odds garde la chance ({ot})`)
check(text("Header") == "BEST ITEM", "S4 Header « BEST ITEM »")

-- S5. Ancien socle (sans RarestDisplay) : Title « BEST ITEM », revenu dans Odds (pas d'Income dans BB_Rarest).
display:Destroy()
step(1.1)
local old = named(oldPoint, R.CopyName)[1]
local title = old and old:FindFirstChild("Title", true)
local odds = old and old:FindFirstChild("Odds", true)
check(old ~= nil and title ~= nil and title.Text == "BEST ITEM", `S5 ancien socle : Title « BEST ITEM » ({title and title.Text})`)
check(odds ~= nil and odds.Visible == true and odds.Text == FormatC.income(2500), `S5 ancien socle : revenu dans Odds ({odds and odds.Text})`)
check(#named(pedestal, R.ItemName) == 1, "S5 ancien socle : l'objet sur RarestSlot")
summary()
