---------------------------------------------------------------- banc a80 (vague 26, L-097 points 6 et 7)
-- Collé après setup.luau, setup-a60.luau et setup-a75.luau. Vrais VfxController et UiFeelController ;
-- ChaseController, ShelfBoxController et DisplayController bouchonnés et pilotables.
SOURCES["stub/ChaseController"] = [==[
local C = { chased = false, distance = nil, guard = nil }
function C.IsChased()
	return C.chased
end
function C.GetDistance()
	return C.distance
end
function C.IsClose()
	return false
end
function C.GetGuard()
	return if C.chased then C.guard else nil
end
return C
]==]
SOURCES["stub/ShelfBoxController"] = [==[
local S = { reserved = {}, calls = 0 }
function S.Reserve(key, count)
	S.calls += 1
	S.reserved[key] = count
end
return S
]==]
SOURCES["stub/DisplayController"] = [==[
local D = { listeners = {} }
function D.OnCollect(fn)
	table.insert(D.listeners, fn)
	return function() end
end
function D.Fire(amount, slot, position)
	for _, fn in D.listeners do
		fn(amount, slot, position)
	end
end
return D
]==]
moduleScript(CONTROLLERS, "ShelfBoxController", "stub/ShelfBoxController")
moduleScript(CONTROLLERS, "DisplayController", "stub/DisplayController")
VFX_MODULE = moduleScript(CONTROLLERS, "VfxController", "client/Controllers/VfxController.luau")

-- Modèles de Clément tels que relevés dans Studio le 2026-11-11.
local FX = folder(ASSETS, "FX")
new("Highlight", { Name = "FX_ChaseHighlight", OutlineColor = Color3.new(1, 0.1, 0.1) }, FX)
local function flyerModel(name, partName)
	local model = new("Model", { Name = name })
	local part = new("Part", { Name = partName, Size = Vector3.new(1.4, 0.05, 0.7) }, model)
	new("Attachment", { Name = "TrailA" }, part)
	new("Attachment", { Name = "TrailB" }, part)
	new("Trail", { Name = "Trail" }, part)
	model.PrimaryPart = part
	model.Parent = FX
end
flyerModel("FX_Collect_Bill", "Bill")
flyerModel("FX_Collect_Coin", "Coin")
do
	local model = new("Model", { Name = "FX_Escape" })
	model:SetAttribute("Duration", 2)
	local root = new("Part", { Name = "Root", Transparency = 1, Anchored = true, Size = Vector3.new(1, 1, 1) }, model)
	local burstAtt = new("Attachment", { Name = "Burst", CFrame = CFrame.new(0, 2.5, 0) }, root)
	for _, spec in { { "Confetti", 70 }, { "Stars", 24 } } do
		local e = new("ParticleEmitter", { Name = spec[1], Enabled = false }, burstAtt)
		e:SetAttribute("EmitCount", spec[2])
	end
	local light = new("PointLight", { Name = "Light", Brightness = 3, Enabled = false }, burstAtt)
	light:SetAttribute("FadeTime", 0.5)
	local ground = new("Attachment", { Name = "Ground", CFrame = CFrame.new(0, 0.1, 0) }, root)
	local ring = new("ParticleEmitter", { Name = "Ring", Enabled = false }, ground)
	ring:SetAttribute("EmitCount", 1)
	model.PrimaryPart = root
	model.Parent = FX
end
do
	local model = new("Model", { Name = "FX_TruckDust" })
	model:SetAttribute("Duration", 2.5)
	local root = new("Part", { Name = "Root", Transparency = 1, Size = Vector3.new(1, 1, 1) }, model)
	for _, name in { "WheelRear_L", "WheelRear_R", "WheelFront_L", "WheelFront_R" } do
		local att = new("Attachment", { Name = name }, root)
		local e = new("ParticleEmitter", { Name = "Dust", Enabled = false }, att)
		e:SetAttribute("EmitCount", 10)
	end
	model.PrimaryPart = root
	model.Parent = FX
end
local UI = ASSETS:FindFirstChild("UI")
do
	local bb = new("BillboardGui", { Name = "BB_Rarest", MaxDistance = 200 })
	new("ImageLabel", { Name = "Rays", Rotation = 0 }, bb)
	local plaque = new("Frame", { Name = "Plaque" }, bb)
	local content = new("Frame", { Name = "Content" }, plaque)
	new("TextLabel", { Name = "Title", Text = "RAREST PULL" }, content)
	new("TextLabel", { Name = "Rarity", Text = "MYTHIC" }, content)
	new("TextLabel", { Name = "ItemName", Text = "Donut" }, content)
	new("TextLabel", { Name = "Odds", Text = "Normal · 1 in 400" }, content)
	new("ImageLabel", { Name = "CrownIcon", Rotation = 0 }, bb)
	bb.Parent = UI
end

local function emitted(name, from)
	local total, n = 0, 0
	for i = (from or 0) + 1, #EMITS do
		if EMITS[i].name == name then
			total += EMITS[i].count
			n += 1
		end
	end
	return total, n
end
local function named(parent, name)
	local out = {}
	for _, child in parent:GetChildren() do
		if child.Name == name then
			table.insert(out, child)
		end
	end
	return out
end

local VfxCfg = requireModule(ReplicatedStorage.Shared.Config.Vfx, "client")
local RaritiesC = requireModule(ReplicatedStorage.Shared.Config.Rarities, "client")
local ItemsC = requireModule(ReplicatedStorage.Shared.Config.Items, "client")
local Chase = requireModule(CHASE_MODULE, "client")
local Shelf = requireModule(CONTROLLERS.ShelfBoxController, "client")
local Display = requireModule(CONTROLLERS.DisplayController, "client")
requireModule(ReplicatedStorage.Shared.Net.Net, "server")
local Vfx = requireModule(VFX_MODULE, "client")
local Feel = requireModule(FEEL_MODULE, "client")
taskLib.spawn(Vfx.Start)
taskLib.spawn(Feel.Start)
step(0.1)

print("\n== V1. Contour rouge du vigile en poursuite (FX_ChaseHighlight)")
local guard = new("Model", { Name = "Guard_Z1" }, Workspace)
new("Part", { Name = "HumanoidRootPart" }, guard)
Chase.guard = guard
Chase.chased = true
step(1 / 30)
local hl = named(guard, VfxCfg.Chase.CopyName)
check(#hl == 1 and hl[1].ClassName == "Highlight" and hl[1].Adornee == guard, "V1a une copie du Highlight dans le vigile, Adornee = vigile")
check(Shelf.reserved[VfxCfg.Chase.ReserveKey] == 1, "V1b une place de Highlight gardée par ShelfBoxController")
step(0.5)
check(#named(guard, VfxCfg.Chase.CopyName) == 1, "V1c toujours une seule copie")
hl[1]:Destroy() -- vigile sorti du streaming puis revenu : la copie est reposée
step(1 / 30)
check(#named(guard, VfxCfg.Chase.CopyName) == 1, "V1d copie reposée si elle disparaît")
Chase.chased = false
step(1 / 30)
check(#named(guard, VfxCfg.Chase.CopyName) == 0 and Shelf.reserved[VfxCfg.Chase.ReserveKey] == 0, "V1e fin de poursuite : copie retirée, place rendue")
check(Vfx.GetState().ChaseGuard == nil, "V1f GetState().ChaseGuard vide")
P1:SetAttribute("VfxEnabled", false)
Chase.chased = true
step(1 / 30)
check(#named(guard, VfxCfg.Chase.CopyName) == 1, "V1g VISUAL EFFECTS OFF : le contour reste")
Chase.chased = false
P1:SetAttribute("VfxEnabled", nil)
step(1 / 30)

print("\n== V2. Billets et pièces du ramassage (FX_Collect_Bill, FX_Collect_Coin)")
check(Vfx.CollectCount(10) == 5 and Vfx.CollectCount(1) == 5, "V2a 5 au plus petit montant")
check(Vfx.CollectCount(1000) == 7 and Vfx.CollectCount(1e6) == 10, "V2b 7 pour 1 K, 10 pour 1 M")
check(Vfx.CollectCount(1e15) == 12, "V2c au plus 12")
check(Vfx.CollectCount(0) == 0, "V2d rien pour 0 $")
local hud = makeHud()
local pad = Vector3.new(10, 1, 5)
Display.Fire(1000, 1, pad)
local bills, coins = #named(Workspace, "FX_Collect_Bill"), #named(Workspace, "FX_Collect_Coin")
check(bills + coins == 7 and bills >= 1 and coins >= 1, `V2e 7 copies, billets et pièces ({bills} + {coins})`)
local first = named(Workspace, "FX_Collect_Bill")[1]
check(first.PrimaryPart.CanCollide == false and first.PrimaryPart.CanQuery == false and first.PrimaryPart.Anchored == true, "V2f ancrées, sans collision ni requête")
step(VfxCfg.Collect.PopTime)
local y = first:GetPivot().Position.Y
check(y >= pad.Y + VfxCfg.Collect.PopHeight[1] - 0.3, `V2g jaillit vers le haut en {VfxCfg.Collect.PopTime} s (y = {y})`)
step(0.25)
local scale = first:GetScale()
check(scale < 1, `V2h rapetisse en filant vers le compteur ({scale})`)
step(6 * VfxCfg.Collect.Stagger + VfxCfg.Collect.FlyTime[2] + 0.1)
check(#named(Workspace, "FX_Collect_Bill") + #named(Workspace, "FX_Collect_Coin") == 0 and Vfx.GetState().Flyers == 0, "V2i tous détruits à l'arrivée")
hud.Enabled = false
Display.Fire(50, 2, pad)
local riser = named(Workspace, "FX_Collect_Bill")[1]
step(VfxCfg.Collect.PopTime + 0.3)
check(riser.PrimaryPart.LocalTransparencyModifier > 0, "V2j sans compteur à l'écran : monte et s'efface")
step(1)
check(Vfx.GetState().Flyers == 0, "V2k puis détruit")
P1:SetAttribute("VfxEnabled", false)
Display.Fire(1e6, 3, pad)
check(#named(Workspace, "FX_Collect_Bill") + #named(Workspace, "FX_Collect_Coin") == 0, "V2l VISUAL EFFECTS OFF : aucun billet")
P1:SetAttribute("VfxEnabled", nil)

print("\n== V3. Arrivée en zone safe (FX_Escape)")
makeEscape()
local e0 = #EMITS
Feel.Escape("Premium")
step(1 / 30)
local copies = named(Workspace, "FX_Escape")
check(#copies == 1, "V3a UiFeelController.Escape pose une copie de FX_Escape")
local copy = copies[1]
local foot = copy:GetPivot().Position
check(near(foot.Y, 0, 1e-3) and near(foot.X, 0, 1e-3), `V3b aux pieds du joueur ({foot})`)
check(emitted("Confetti", e0) == 70 and emitted("Stars", e0) == 24 and emitted("Ring", e0) == 1, "V3c Emit(EmitCount) : 70 confettis, 24 étoiles, 1 anneau")
local light = copy:FindFirstChild("Light", true)
check(light.Enabled == true and light.Brightness > 2, "V3d lumière allumée")
step(0.55)
check(light.Brightness < 0.05, `V3e éteinte en FadeTime ({light.Brightness})`)
step(1.5)
check(#named(Workspace, "FX_Escape") == 0 and Vfx.GetState().Bursts == 0, "V3f détruite après Duration (2 s)")
P1:SetAttribute("VfxEnabled", false)
e0 = #EMITS
local off = Vfx.Escape()
check(off ~= nil and #EMITS == e0 and off:FindFirstChild("Light", true).Enabled == false, "V3g VISUAL EFFECTS OFF : ni particule ni lumière")
P1:SetAttribute("VfxEnabled", nil)
step(2.1)
check(#named(Workspace, "FX_Escape") == 0, "V3h détruite quand même")

print("\n== V4. Poussière du camion (FX_TruckDust)")
local function truck(attrs)
	local model = new("Model", { Name = "EventTruck" })
	local root = new("Part", { Name = "Root", CFrame = CFrame.new(-75, 0, 322) }, model)
	model.PrimaryPart = root
	for k, v in attrs do
		model:SetAttribute(k, v)
	end
	model.Parent = Workspace
	addTag(model, "EventTruck")
	return model
end
e0 = #EMITS
local t1 = truck({ SpawnedAt = Workspace:GetServerTimeNow() })
local dust = named(Workspace, "FX_TruckDust")
local dTotal, dN = emitted("Dust", e0)
check(#dust == 1 and dTotal == 40 and dN == 4, `V4a arrivée : une copie, 4 × Emit(10) ({dTotal}, {dN})`)
check(#dust == 1 and near(dust[1]:GetPivot().Position.X, -75, 1e-3) and near(dust[1]:GetPivot().Position.Z, 322, 1e-3), "V4b posée au pivot du camion")
step(2.6)
check(#named(Workspace, "FX_TruckDust") == 0, "V4c détruite après Duration (2,5 s)")
e0 = #EMITS
local t2 = truck({ SpawnedAt = Workspace:GetServerTimeNow() - 30 })
check(#named(Workspace, "FX_TruckDust") == 0, "V4d camion vu tard (streaming) : pas de poussière")
t2:Destroy()
check(#named(Workspace, "FX_TruckDust") == 0, "V4e sortie du streaming (sans LeftAt) : rien")
t1:SetAttribute("LeftAt", Workspace:GetServerTimeNow())
t1:Destroy()
check(#named(Workspace, "FX_TruckDust") == 1, "V4f départ (LeftAt) : poussière")
local t3 = truck({ SpawnedAt = Workspace:GetServerTimeNow() - 30, ExplodedAt = Workspace:GetServerTimeNow() - 5 })
t3:SetAttribute("LeftAt", Workspace:GetServerTimeNow())
t3:Destroy()
check(#named(Workspace, "FX_TruckDust") == 1, "V4g retrait après l'explosion : pas de poussière")
step(2.6)

print("\n== V5. BB_Rarest sur le socle de chaque boutique")
local epic, common
for _, item in ItemsC.List do
	if item.Rarity == "Epic" and epic == nil then
		epic = item
	elseif item.Rarity == "Common" and common == nil then
		common = item
	end
end
local plot = new("Model", { Name = "PLOT_Shop_01" })
local pedestal = new("Model", { Name = "RarestPedestal" }, plot)
local plate = new("Part", { Name = "TopPlate", CFrame = CFrame.new(0, 4, 0) }, pedestal)
local point = new("Attachment", { Name = "RarestLabelPoint", CFrame = CFrame.new(0, 1, 0) }, plate)
local items = folder(plot, "DisplayItems")
plot.Parent = Workspace
addTag(plot, "PlayerPlot")
step(1.1)
check(#named(point, VfxCfg.Rarest.CopyName) == 0, "V5a aucun objet exposé : pas de billboard")
local function display(item, income)
	local m = new("Model", { Name = "DisplayItem_" .. item.Id })
	m:SetAttribute("ItemId", item.Id)
	m:SetAttribute("Rarity", item.Rarity)
	m:SetAttribute("Income", income)
	m:SetAttribute("ItemUid", "uid-" .. item.Id)
	m.Parent = items
	return m
end
local mCommon = display(common, 999)
local mEpic = display(epic, 5)
step(1.1)
local bbs = named(point, VfxCfg.Rarest.CopyName)
check(#bbs == 1 and bbs[1].Adornee == point, "V5b une copie de BB_Rarest sur RarestLabelPoint")
local bb = bbs[1]
local rarityLabel, nameLabel, odds = bb:FindFirstChild("Rarity", true), bb:FindFirstChild("ItemName", true), bb:FindFirstChild("Odds", true)
check(rarityLabel.Text == "EPIC" and sameColor(rarityLabel.TextColor3, RaritiesC.ById.Epic.Color), `V5c Rarity « EPIC » à la couleur de la rareté ({rarityLabel.Text})`)
check(nameLabel.Text == epic.DisplayName, `V5d ItemName = {epic.DisplayName} (le plus rare, pas le plus gros revenu)`)
check(odds.Visible == false, "V5e Odds caché (chance du tirage absente)")
check(bb:FindFirstChild("Title", true).Text == "RAREST PULL", "V5f Title de Clément gardé")
local rays, crown = bb:FindFirstChild("Rays", true), bb:FindFirstChild("CrownIcon", true)
local r0 = rays.Rotation
step(0.5)
check(rays.Rotation ~= r0 and crown.Rotation ~= 0, `V5g Rays tourne, CrownIcon se balance ({rays.Rotation}, {crown.Rotation})`)
mEpic:Destroy()
step(1.1)
check(#named(point, VfxCfg.Rarest.CopyName) == 1 and nameLabel.Text == common.DisplayName and rarityLabel.Text == "COMMON", "V5h l'objet suivant prend la place")
P1:SetAttribute("VfxEnabled", false)
step(1.1)
check(#named(point, VfxCfg.Rarest.CopyName) == 1, "V5i VISUAL EFFECTS OFF : BB_Rarest reste")
P1:SetAttribute("VfxEnabled", nil)
mCommon:Destroy()
step(1.1)
check(#named(point, VfxCfg.Rarest.CopyName) == 0 and Vfx.GetState().Rarest == 0, "V5j plus rien d'exposé : billboard retiré")

summary()
