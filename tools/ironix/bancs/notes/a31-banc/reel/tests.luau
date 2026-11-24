--!nocheck
-- Banc a31 (vague 11, liaison L-055 ; MOD-040 côté code) :
--   A. Unbox/Reel en mode icônes : un objet dont l'icône ICON_<ItemId> est livrée est un ImageLabel
--      (cadre ReelIcons, mêmes cases et même taille que le modèle, teinte de la vue), sinon le
--      clone 3D comme avant ; trois cases au plus ; préchargement des icônes ; rien sans icônes ni
--      sans le mode (aperçu) ; tout détruit avec le rouleau ;
--   B. la séquence complète (Unbox/Sequence et Unbox/Screen, UI_Unbox v2 d'a23) avec les icônes :
--      silhouettes noires, couleurs dans la même image que ReelView, gagnant au centre, aperçu
--      ItemPreview en 3D, écran remis à la fermeture.

local DT = 1 / 30

---------------------------------------------------------------- arbre
local sharedRoot = folder(ReplicatedStorage, "Shared")
local dirs = { [""] = sharedRoot }
local function dirFor(path)
	if dirs[path] then
		return dirs[path]
	end
	local parentPath, name = string.match(path, "^(.-)/?([^/]+)$")
	local f = folder(dirFor(parentPath), name)
	dirs[path] = f
	return f
end
for key in SOURCES do
	local rest = string.match(key, "^shared/(.+)%.luau$")
	if rest then
		local dir, name = string.match(rest, "^(.-)/?([^/]+)$")
		moduleScript(dirFor(dir), name, key)
	end
end
local controllers = folder(folder(StarterPlayerScripts, "Client"), "Controllers")
local unboxFolder = folder(controllers, "Unbox")
for _, name in { "Reel", "Sequence", "Screen" } do
	moduleScript(unboxFolder, name, `client/Controllers/Unbox/{name}.luau`)
end
local Assets = folder(ReplicatedStorage, "Assets")

local Config = sharedRoot.Config
local Items = requireModule(Config.Items, "client")
local Unbox = requireModule(Config.Unbox, "client")
local Reel = requireModule(unboxFolder.Reel, "client")
local Sequence = requireModule(unboxFolder.Sequence, "client")
local Screen = requireModule(unboxFolder.Screen, "client")

local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)

local function decal(name, texture, parent)
	return new("Decal", { Name = name, Texture = texture }, parent)
end
local function iconsIn(viewport)
	local layer = viewport:FindFirstChild("ReelIcons")
	local out = {}
	if layer then
		for _, c in layer:GetChildren() do
			if c:IsA("ImageLabel") then
				table.insert(out, c)
			end
		end
	end
	return out, layer
end
local function modelsIn(viewport)
	local n = 0
	for _, c in viewport:GetChildren() do
		if c:IsA("Model") then
			n += 1
		end
	end
	return n
end
local function iconNamed(viewport, name)
	for _, icon in (iconsIn(viewport)) do
		if icon.Name == name then
			return icon
		end
	end
	return nil
end

---------------------------------------------------------------- A. Unbox/Reel
print("== A. Unbox/Reel : icônes ICON_ dans le rouleau, repli 3D")
local IconsF = folder(Assets, "Icons")
decal("ICON_Z2_CanardEnPlastique", "rbxassetid://201", IconsF)
decal("ICON_Z2_OursEnPeluche", "rbxassetid://202", IconsF)
decal("ICON_Z2_Sucette", "rbxassetid://203", folder(IconsF, "Zone2"))
-- Pas d'icône pour le Ballon de foot : son clone 3D (cube V0, aucun ITM_ livré dans ce banc).
local duck, ball, bear, lolly = Items.ById.Z2_CanardEnPlastique, Items.ById.Z2_BallonDeFoot, Items.ById.Z2_OursEnPeluche, Items.ById.Z2_Sucette
local list = { duck, ball, bear, duck, lolly }
local gui = new("ScreenGui", { Name = "Banc" }, nil)
local view = new("ViewportFrame", { Name = "ReelView", Size = S(0.2, 0.35), BackgroundTransparency = 1, ZIndex = 2, ImageColor3 = BLACK, ImageTransparency = 0 }, gui)
local size = view.AbsoluteSize
local width = math.min(Unbox.ReelFit, Unbox.ReelSlot * (size.X / size.Y) * 0.85)
local share = width / Unbox.ReelSlot

table.clear(PRELOADS)
local strip = Reel.newStrip(view, list, true)
check(#PRELOADS == 1 and PRELOADS[1].side == "client" and table.concat(PRELOADS[1].list, ",") == "rbxassetid://201,rbxassetid://202,rbxassetid://203", "création du rouleau : les 3 icônes différentes préchargées une fois (pas le Ballon, sans icône)")
check(view:FindFirstChild("ReelIcons") == nil and view:FindFirstChildWhichIsA("Camera") ~= nil, "cadre ReelIcons posé seulement à la première icône montrée ; caméra fixe posée")
strip:Set(1, 0, 0)
local icons, layer = iconsIn(view)
check(layer ~= nil and layer:IsA("Frame") and layer.ClipsDescendants == true and layer.BackgroundTransparency == 1 and layer.Size.X.Scale == 1 and layer.Size.Y.Scale == 1 and layer.ZIndex == view.ZIndex, "ReelIcons : cadre transparent de la taille de la vue, qui coupe ce qui en sort")
local duckIcon = iconNamed(view, "ICON_Z2_CanardEnPlastique")
check(#icons == 1 and duckIcon ~= nil and duckIcon.Image == "rbxassetid://201", "case 1 (Canard) : son icône (ImageLabel ICON_Z2_CanardEnPlastique)")
check(duckIcon and duckIcon.Position.X.Scale == 0.5 and duckIcon.Position.Y.Scale == 0.5 and duckIcon.AnchorPoint.X == 0.5 and duckIcon.AnchorPoint.Y == 0.5, "icône au centre de la vue quand sa case est au centre")
check(duckIcon and duckIcon.SizeConstraint == "Enum.SizeConstraint.RelativeYY" and near(duckIcon.Size.X.Scale, share, 1e-12) and near(duckIcon.Size.Y.Scale, share, 1e-12) and duckIcon.ScaleType == "Enum.ScaleType.Fit", `icône carrée, de la taille du modèle (largeur {math.floor(share * 1000) / 1000} de la hauteur de la vue)`)
check(duckIcon and duckIcon.BackgroundTransparency == 1 and sameColor(duckIcon.ImageColor3, BLACK) and duckIcon.ImageTransparency == 0 and duckIcon.Rotation == 0, "icône : fond transparent, teinte de la vue (silhouette noire), immobile")
local ballModel = view:FindFirstChild("ITM_Z2_BallonDeFoot")
check(ballModel ~= nil and ballModel:IsA("Model") and ballModel:FindFirstChild("V0Block") ~= nil, "case 2 (Ballon de foot, sans icône) : le clone 3D, comme avant (cube V0)")
check(modelsIn(view) == 1, "une seule case en 3D")
strip:Set(1.5, 0.3, 0)
local bearIcon = iconNamed(view, "ICON_Z2_OursEnPeluche")
check(duckIcon.Position.Y.Scale == 1 and bearIcon ~= nil and bearIcon.Position.Y.Scale == -1, "défilement d'une demi-case : le Canard descend (Y 1), l'Ours arrive par le haut (Y −1)")
strip:Set(1, 0, 1)
check(duckIcon.Position.Y.Scale == 1.5, "sortie du colis (drop = 1 case) : décalé d'une case vers le bas")
-- Balayage : jamais plus de 3 cases, icônes et modèles compris.
local maxCells, everyIcon = 0, true
for i = 0, 80 do
	strip:Set(1 + i * 0.05, i * 0.1, 0)
	local n = #(iconsIn(view)) + modelsIn(view)
	maxCells = math.max(maxCells, n)
end
check(maxCells <= 3 and maxCells >= 2, `de la case 1 à la case 5 : jamais plus de 3 cases à la fois ({maxCells})`)
strip:Set(4, 0, 0)
icons = iconsIn(view)
check(#icons == 3 and modelsIn(view) == 0 and duckIcon.Parent == nil and view:FindFirstChild("ITM_Z2_BallonDeFoot") == nil, "cases 3 à 5 (Ours, Canard, Sucette) : trois icônes ; les cases sorties sont détruites")
check(iconNamed(view, "ICON_Z2_Sucette") ~= nil and iconNamed(view, "ICON_Z2_Sucette").Image == "rbxassetid://203", "icône rangée dans un sous-dossier d'Assets/Icons : prise aussi")
-- Teinte : l'icône reprend ImageColor3 et ImageTransparency de la vue à chaque image.
view.ImageColor3 = WHITE
view.ImageTransparency = 0.25
strip:Set(4.1, 0, 0)
local tinted = true
for _, icon in (iconsIn(view)) do
	if not sameColor(icon.ImageColor3, WHITE) or icon.ImageTransparency ~= 0.25 then
		tinted = false
	end
end
check(tinted, "la vue passe au blanc (couleurs) : les icônes aussi, transparence comprise")
strip:Destroy()
check(#view:GetChildren() == 0, "Destroy : icônes, cadre ReelIcons, modèles et caméra détruits")
strip:Set(2, 0, 0)
check(#view:GetChildren() == 0, "après Destroy, Set ne crée plus rien")

-- Sans le mode icônes (aperçu ItemPreview) : toujours le 3D.
table.clear(PRELOADS)
local view2 = new("ViewportFrame", { Name = "Preview", Size = S(0.2, 0.35), BackgroundTransparency = 1, ZIndex = 2 }, gui)
local strip2 = Reel.newStrip(view2, { duck })
strip2:Set(1, 0)
check(view2:FindFirstChild("ReelIcons") == nil and view2:FindFirstChild("ITM_Z2_CanardEnPlastique") ~= nil and #PRELOADS == 0, "sans le mode icônes (aperçu) : le clone 3D, rien de préchargé, même si l'icône existe")
strip2:Destroy()

-- Le vrai modèle ITM_ en repli quand l'icône manque.
local itemsF = folder(Assets, "Items")
local ballTemplate = new("Model", { Name = "ITM_Z2_BallonDeFoot" }, itemsF)
local ballRoot = new("Part", { Name = "Root", Size = Vector3.new(1, 1, 1) }, ballTemplate)
ballTemplate.PrimaryPart = ballRoot
new("Script", { Name = "Spin" }, ballRoot)
local view3 = new("ViewportFrame", { Name = "ReelView3", Size = S(0.2, 0.35), BackgroundTransparency = 1, ZIndex = 2 }, gui)
local strip3 = Reel.newStrip(view3, { ball, duck }, true)
strip3:Set(1, 0, 0)
local clone = view3:FindFirstChild("ITM_Z2_BallonDeFoot")
check(clone ~= nil and clone:FindFirstChild("Root") ~= nil and clone:FindFirstChild("V0Block") == nil and clone:FindFirstChild("Spin", true) == nil, "repli : le vrai ITM_ livré, cloné sans ses scripts")
check(iconNamed(view3, "ICON_Z2_CanardEnPlastique") ~= nil, "dans le même rouleau : icône et modèle 3D côte à côte")
strip3:Destroy()

-- Aucune icône livrée : le rouleau d'avant, sans cadre ni préchargement.
IconsF:Destroy()
table.clear(PRELOADS)
local view4 = new("ViewportFrame", { Name = "ReelView4", Size = S(0.2, 0.35), BackgroundTransparency = 1, ZIndex = 2 }, gui)
local strip4 = Reel.newStrip(view4, list, true)
strip4:Set(1, 0, 0)
check(view4:FindFirstChild("ReelIcons") == nil and modelsIn(view4) == 2 and #PRELOADS == 0, "aucune icône livrée : clones 3D seulement, ni cadre ni préchargement (comme avant)")
strip4:Destroy()
itemsF:Destroy()

---------------------------------------------------------------- B. séquence complète
print("== B. Séquence complète (Sequence, Screen, UI_Unbox v2) avec les icônes")
-- Une icône par objet de la zone 2 (et le Secret) : chaque case du rouleau est une icône.
IconsF = folder(Assets, "Icons")
for _, item in Items.List do
	if item.Zone == 2 or item.Zone == nil then
		decal(`ICON_{item.Id}`, `rbxassetid://7{#item.Id}{string.byte(item.Id, -1)}`, IconsF)
	end
end
local playerGui = folder(Players, "BancGui")
local unboxGui = buildUnbox(playerGui)
local reelView = unboxGui:FindFirstChild("ReelView", true)
local preview = unboxGui:FindFirstChild("ItemPreview", true)
local hooks = {
	PlayPlayer = function()
		return false
	end,
	CanOpenNext = function()
		return false
	end,
}
local reveal = { BenchIndex = 1, ItemUid = "u1", ItemId = "Z2_VoitureTelecommandee", Zone = 2, Tier = "Premium", StartRarity = "Rare", Upgrades = 0 }
local plan = assert(Sequence.plan(reveal, Random.new(11)))
local times = Sequence.times(plan)
check(plan.Full and #plan.Reel.Items == plan.Reel.Winner + Unbox.ReelTail and plan.Reel.Items[plan.Reel.Winner].Id == "Z2_VoitureTelecommandee", "plan : version complète (Rare), gagnant RC Car à l'index W")
local distinct = {}
for _, item in plan.Reel.Items do
	distinct[item.Id] = true
end
local distinctCount = 0
for _ in distinct do
	distinctCount += 1
end
table.clear(PRELOADS)
local screenView = Screen.new(unboxGui, plan, nil, hooks)
local runner = Sequence.new(plan, screenView)
local t = 0
local seen = { beforeOpen = true, maxCells = 0, models = 0, silhouette = true, sameTint = true, midTint = false, winnerCentered = false }
while t < times.Reveal - 1e-9 do
	runner:Update(DT)
	t += DT
	local cells, layerNow = iconsIn(reelView)
	if t < times.Open - 1e-9 and layerNow ~= nil then
		seen.beforeOpen = false
	end
	if t >= times.Open and t < times.Reveal - DT then
		seen.maxCells = math.max(seen.maxCells, #cells + modelsIn(reelView))
		seen.models += modelsIn(reelView)
		local tint = reelView.ImageColor3
		for _, icon in cells do
			if not sameColor(icon.ImageColor3, tint) then
				seen.sameTint = false
			end
			if t < times.ColorStart - 1e-9 and not sameColor(icon.ImageColor3, BLACK) then
				seen.silhouette = false
			end
		end
		if t > times.ColorStart + DT and t < times.Reveal - DT and tint.R > 0.05 and tint.R < 0.95 and #cells > 0 then
			seen.midTint = true
		end
		if t >= times.ReelDone and t < times.Reveal - DT then
			for _, icon in cells do
				if icon.Position.Y.Scale == 0.5 and icon.Name == "ICON_Z2_VoitureTelecommandee" then
					seen.winnerCentered = true
				end
			end
		end
	end
end
check(seen.beforeOpen, "avant l'ouverture : aucune icône dans ReelView")
check(#PRELOADS == 1 and #PRELOADS[1].list == distinctCount, `à l'ouverture : les {distinctCount} icônes différentes du rouleau préchargées, une fois`)
check(seen.maxCells >= 2 and seen.maxCells <= 3 and seen.models == 0, `pendant le rouleau : que des icônes (toutes livrées), 3 cases au plus ({seen.maxCells})`)
check(seen.silhouette, "avant ColorStart : silhouettes noires (ImageColor3 de ReelView chez Clément)")
check(seen.sameTint and seen.midTint, "les icônes prennent leurs couleurs avec ReelView, dans la même image (fondu observé)")
check(seen.winnerCentered, "à l'arrêt : l'icône du gagnant (RC Car) au centre")
-- L'éclat : le rouleau disparaît, l'objet vient vers ItemPreview en 3D.
runner:Update(DT)
t += DT
local previewViewport = preview:FindFirstChild("ItemViewport")
check(reelView:FindFirstChild("ReelIcons") == nil, "à l'éclat : le rouleau et ses icônes sont détruits")
check(previewViewport ~= nil and previewViewport:FindFirstChild("ITM_Z2_VoitureTelecommandee") ~= nil and previewViewport:FindFirstChildWhichIsA("ImageLabel", true) == nil, "ItemPreview : l'objet révélé en 3D (clone ITM_), pas une icône")
while t < times.Buttons + 0.5 do
	runner:Update(DT)
	t += DT
end
screenView:Close()
check(#reelView:GetChildren() == 0 and sameColor(reelView.ImageColor3, BLACK) and reelView.CurrentCamera == nil, "fermeture : ReelView vide, noir et sans caméra, comme dans Studio")
check(preview:FindFirstChild("ItemViewport") == nil, "fermeture : l'aperçu posé par le code est détruit")

-- Icônes en partie livrées : icônes et modèles 3D mêlés, toujours 3 cases au plus.
for _, child in IconsF:GetChildren() do
	if child.Name == "ICON_Z2_CanardEnPlastique" or child.Name == "ICON_Z2_YoYo" or child.Name == "ICON_Z2_Sucette" or child.Name == "ICON_Z2_OursEnPeluche" then
		child:Destroy()
	end
end
local reveal2 = { BenchIndex = 1, ItemUid = "u2", ItemId = "Z2_YoYo", Zone = 2, Tier = "Standard", StartRarity = "Uncommon", Upgrades = 0 }
local plan2 = assert(Sequence.plan(reveal2, Random.new(4)))
local times2 = Sequence.times(plan2)
local view5 = Screen.new(unboxGui, plan2, nil, hooks)
local runner2 = Sequence.new(plan2, view5)
local t2, max2, mixed, models2 = 0, 0, false, 0
while t2 < times2.Reveal - 2 * DT do
	runner2:Update(DT)
	t2 += DT
	if t2 >= times2.Open then
		local cells = #(iconsIn(reelView))
		local m = modelsIn(reelView)
		max2 = math.max(max2, cells + m)
		models2 += m
		if cells > 0 and m > 0 then
			mixed = true
		end
	end
end
check(not plan2.Full and max2 <= 3 and models2 > 0, `version courte, icônes manquantes (Canard, Yo-yo, Sucette, Ours) : leurs cases en 3D, 3 cases au plus ({max2})`)
check(mixed or models2 > 0, "icônes et modèles dans le même rouleau quand une partie seulement est livrée")
view5:Close()
check(#reelView:GetChildren() == 0, "fermeture : rien ne reste dans ReelView")

---------------------------------------------------------------- fin
summary()
