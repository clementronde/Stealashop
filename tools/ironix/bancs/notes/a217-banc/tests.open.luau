---------------------------------------------------------------- scénario open d'a217 (vague 65)
-- Après setup.luau du banc a50 (serveur, Net, WeaponShopController démarré) ; AuraShopController monté ici, sur la
-- carte grise du banc a186 (fonds des paliers, textures FX_ blanches). Assets garni de FILLER pièces, comme un vrai
-- Assets plein de modèles. Mesures par ouverture : lignes copiées depuis List.Template, instances d'Assets
-- parcourues (GetDescendants sur Assets), temps de l'ouverture (os.clock, faux Roblox).
-- Contrôles (après a217) : 2e ouverture sans ligne neuve ni passe sur Assets ; contenu juste après un achat et un
-- équipement (écran ouvert ou fermé) ; onglet ; icônes et effets toujours posés ; cascade (StaggerScale) à chaque
-- ouverture ; écran recréé : tout relu une fois.
local FILLER = 20000
-- Faux Roblox : AbsolutePosition des cadres (ordre de lecture de la cascade de Motion), absente du banc a50.
for _, class in { "Frame", "TextButton", "TextLabel", "ImageLabel", "ImageButton", "ScrollingFrame" } do
	PROPS[class] = PROPS[class] or {}
	if PROPS[class].AbsolutePosition == nil then
		PROPS[class].AbsolutePosition = Vector2.new(0, 0)
	end
end
local playerGui = P1.PlayerGui
local hex = Color3.fromHex
local WHITE = Color3.new(1, 1, 1)
local GREY = hex("8a8f99")
local function near3(a, b)
	return a ~= nil and b ~= nil and math.abs(a.R - b.R) < 1e-4 and math.abs(a.G - b.G) < 1e-4 and math.abs(a.B - b.B) < 1e-4
end
local function el(root, name)
	return root:FindFirstChild(name, true)
end

-- Fonds des paliers (ceux du banc a186, sans décor animé : seul le palier compte ici).
local TIERS = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Divine" }
local assets = folder(ReplicatedStorage, "Assets")
local bgs = folder(folder(assets, "UI"), "ShopCardBg")
for _, id in TIERS do
	local f = new("Frame", { Name = id, Size = UDim2.fromScale(1, 1) })
	for k, v in { Rarity = id, RarityColor = WHITE, BorderColor = WHITE, BorderThickness = 2.5, IconScale = 0.8, IconGrey = if id == "Common" then 0.55 else 0, StudsTransparency = 0.9, RaysSpin = 0, GlowPulse = 0 } do
		f:SetAttribute(k, v)
	end
	new("UIGradient", { Name = "Colors" }, f)
	f.Parent = bgs
end
-- Textures d'effet (blanches) de chaque aura et trail de la boutique, sauf le dernier trail (sa carte garde l'image du
-- Template) ; et l'icône de boutique ICON_ (en couleurs) du 2e trail, qui passe avant sa texture FX_.
local Cosmetics = requireModule(ReplicatedStorage.Shared.Config.Cosmetics, "client")
local fx = folder(assets, "FX")
local FX_IMAGE = {}
local all = {}
for _, def in Cosmetics.Auras do table.insert(all, def) end
for _, def in Cosmetics.Trails do table.insert(all, def) end
local lastTrail = Cosmetics.Trails[#Cosmetics.Trails]
local iconTrail = Cosmetics.Trails[2]
-- Modèle d'effet du même nom qu'une texture, rangé avant elle (L-042) : pas un Decal, ignoré.
new("Frame", { Name = all[1].Texture }, folder(assets, "AModels217"))
for i, def in all do
	if def ~= lastTrail then
		FX_IMAGE[def.Id] = "rbxassetid://fx" .. i
		new("Decal", { Name = def.Texture, Texture = FX_IMAGE[def.Id] }, fx)
	end
end
local ICON_IMAGE = "rbxassetid://icon217"
new("Decal", { Name = "ICON_" .. string.sub(iconTrail.Texture, 4), Texture = ICON_IMAGE }, folder(assets, "Icons"))
local filler = folder(assets, "Filler")
for index = 1, FILLER do
	new("Part", { Name = "Part_" .. index }, filler)
end

-- Carte grise (celle du banc a186).
local function makeTemplate(list)
	local template = new("Frame", { Name = "Template", Visible = false }, list)
	local card = new("Frame", { Name = "Card", ClipsDescendants = true }, template)
	new("UIStroke", { Color = hex("1e1e1e"), Thickness = 2.5 }, card)
	local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1) }, card)
	new("UIGradient", { Name = "Colors" }, fill)
	new("ImageLabel", { Name = "Studs", Image = "rbxassetid://studs", ImageTransparency = 0.94 }, card)
	local content = new("Frame", { Name = "Content" }, card)
	new("TextLabel", { Name = "ItemName", Text = "Spark" }, content)
	new("TextLabel", { Name = "RarityLabel", Text = "", TextColor3 = hex("8d939e") }, content)
	local area = new("Frame", { Name = "IconArea" }, content)
	new("ImageLabel", { Name = "Icon", Image = "rbxassetid://template", Size = UDim2.fromScale(0.92 * 0.62, 0.62), ZIndex = 7 }, area)
	new("ImageLabel", { Name = "IconShadow", Image = "", ImageColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(0.92 * 0.62 * 1.06, 0.62 * 1.06), ZIndex = 6 }, area)
	local band = new("Frame", { Name = "BonusBand" }, content)
	new("TextLabel", { Name = "Bonus", Text = "x2" }, band)
	local row = new("Frame", { Name = "ButtonRow" }, content)
	local buy = new("TextButton", { Name = "BuyButton", Text = "" }, row)
	new("TextLabel", { Name = "Price", Text = "$500" }, buy)
	new("TextButton", { Name = "EquipButton", Text = "Equip" }, row)
	-- Contour de survol (HoverCard.Outline) : la carte entre dans la cascade d'ouverture de Motion (OpenStagger).
	new("UIStroke", { Name = "HoverOutline" }, template)
	return template
end
local screen = new("ScreenGui", { Name = "UI_AuraShop", Enabled = true })
screen:SetAttribute("ScreenGroup", "Menu")
local root = new("Frame", { Name = "Root" }, screen)
new("TextButton", { Name = "CloseButton", Text = "X" }, root)
local tabs = new("Frame", { Name = "Tabs" }, root)
new("TextButton", { Name = "AurasTab", Text = "Auras" }, tabs)
new("TextButton", { Name = "TrailsTab", Text = "Trails" }, tabs)
local list = new("ScrollingFrame", { Name = "List" }, root)
local template = makeTemplate(list)
template:SetAttribute("TrailIconRotation", 90)

local function rows()
	local out = {}
	for _, child in list:GetChildren() do
		if string.sub(child.Name, 1, 5) == "Item_" then
			out[string.sub(child.Name, 6)] = child
		end
	end
	return out
end
local function countRows()
	local n = 0
	for _ in rows() do
		n += 1
	end
	return n
end
local function promptIn(model, name)
	for _, d in model:GetDescendants() do
		if d.ClassName == "ProximityPrompt" and d.Name == name then
			return d
		end
	end
	return nil
end

-- Compteurs : copies du Template (une ligne) et instances d'Assets parcourues.
local COUNT = { clones = 0, assets = 0 }
local baseClone = Methods.Clone
Methods.Clone = function(self)
	if rawget(self, "_props").Name == "Template" then
		COUNT.clones += 1
	end
	return baseClone(self)
end
local baseDescendants = Methods.GetDescendants
Methods.GetDescendants = function(self)
	local out = baseDescendants(self)
	if self == assets then
		COUNT.assets += #out
	end
	return out
end

local auraModule = moduleScript(StarterPlayerScripts.Client.Controllers, "AuraShopController", "client/Controllers/AuraShopController.luau")
local AuraShopController = requireModule(auraModule, "client")
screen.Parent = playerGui
taskLib.spawn(AuraShopController.Start)
step(0.1)
local prompt = promptIn(AURA_SHOP, "AuraShopPrompt")
at(ROOT1, AURA_SPOT)
local UiMotion = requireModule(ReplicatedStorage.Shared.Config.UiMotion, "client")
local STAGGER = UiMotion.OpenStagger
-- Lignes qui attendent leur entrée (UIScale passager de Motion), juste après l'ouverture.
local function cascading()
	local n = 0
	for _, row in rows() do
		local scale = row:FindFirstChild(STAGGER.ScaleName)
		if scale and scale:IsA("UIScale") and near(scale.Scale, STAGGER.From) then
			n += 1
		end
	end
	return n
end
local opening = 0
local function open()
	opening += 1
	COUNT.clones, COUNT.assets = 0, 0
	local t0 = os.clock()
	prompt.Triggered:Fire(P1)
	local spent = os.clock() - t0
	local seen = { clones = COUNT.clones, assets = COUNT.assets, ms = spent * 1000, cascade = cascading() }
	print(string.format("  MESURE ouverture %d : %d ligne(s) copiée(s), %d instance(s) d'Assets parcourue(s), %.1f ms (faux Roblox), cascade sur %d ligne(s)",
		opening, seen.clones, seen.assets, seen.ms, seen.cascade))
	step(1)
	return seen
end
local function close()
	screen.Root.CloseButton.Activated:Fire()
	step(1)
end
local function buttons(row)
	return el(row, "BuyButton").Visible, el(row, "EquipButton").Visible, el(row, "EquipButton").Text
end
-- Icône et effet d'une ligne : ICON_ si livrée, sinon FX_ teinte de l'objet, sinon l'image du Template ; palier.
local function iconOk(def, row)
	local icon = el(row, "IconArea").Icon
	local shadow = el(row, "IconArea").IconShadow
	local want = if def == iconTrail then ICON_IMAGE else FX_IMAGE[def.Id] or "rbxassetid://template"
	local tinted = FX_IMAGE[def.Id] ~= nil and def ~= iconTrail
	local color = if tinted then (if def.Order == 1 then def.Color:Lerp(GREY, 0.55) else def.Color) else WHITE
	local rot = if def.Kind == "Trail" then 90 else 0
	return icon.Image == want and shadow.Image == want and near3(icon.ImageColor3, color) and icon.Rotation == rot
		and row.Card.Fill:GetAttribute("Rarity") == TIERS[def.Order]
end
local function allIconsOk(defs)
	local r = rows()
	for _, def in defs do
		if r[def.Id] == nil or not iconOk(def, r[def.Id]) then
			return false, def.Id
		end
	end
	return true, ""
end

if not A217_AFTER and MESURE ~= true then
	print("\n== Mesure avant a217")
	open()
	close()
	open()
	close()
	summary()
	return
end

print("\n== 1re ouverture : lignes construites une fois")
local first = open()
check(screen.Enabled, "1 la boutique s'ouvre")
check(first.clones == #Cosmetics.Auras, "2 lignes d'auras copiées (" .. first.clones .. ")")
check(first.assets > FILLER and first.assets <= FILLER + 200, "3 Assets parcouru une seule fois (" .. first.assets .. " instances)")
check(first.cascade == #Cosmetics.Auras, "4 cascade : chaque ligne attend son entrée (" .. first.cascade .. ")")
local ok, bad = allIconsOk(Cosmetics.Auras)
check(ok, "5 icônes et effets posés (FX_ teintée, palier, visuel droit) " .. bad)
local keep = rows()[Cosmetics.Auras[1].Id]
check(el(keep, "Price").Text == Format.money(Cosmetics.Auras[1].Price) and el(keep, "ItemName").Text == Cosmetics.Auras[1].DisplayName, "6 nom et prix")

print("\n== fermeture puis 2e ouverture : aucune ligne neuve")
close()
check(screen.Enabled == false, "7 CloseButton ferme l'écran")
check(countRows() == #Cosmetics.Auras, "8 lignes gardées écran fermé (" .. countRows() .. ")")
local second = open()
check(second.clones == 0, "9 2e ouverture : aucune ligne copiée (" .. second.clones .. ")")
check(second.assets == 0, "10 2e ouverture : Assets pas parcouru (" .. second.assets .. ")")
check(second.cascade == #Cosmetics.Auras, "11 cascade jouée de nouveau (" .. second.cascade .. ")")
check(rows()[Cosmetics.Auras[1].Id] == keep and countRows() == #Cosmetics.Auras, "12 les mêmes lignes, sans doublon")
ok, bad = allIconsOk(Cosmetics.Auras)
check(ok, "13 icônes et effets toujours posés " .. bad)

print("\n== achat et équipement")
local a1 = Cosmetics.Auras[1]
local a2 = Cosmetics.Auras[2] or Cosmetics.Auras[1]
local b, e, t = buttons(rows()[a1.Id])
check(b == true and e == false, "14 pas possédée : BuyButton visible, EquipButton caché")
P1:SetAttribute("OwnedCosmetics", a1.Id) -- comme CosmeticService après BuyItem
step(0.1)
b, e, t = buttons(rows()[a1.Id])
check(b == false and e == true and t == "Equip", "15 achat écran ouvert : EquipButton « Equip »")
P1:SetAttribute("EquippedAura", a1.Id)
step(0.1)
b, e, t = buttons(rows()[a1.Id])
check(t == "Unequip", "16 équipée écran ouvert : « Unequip »")
close()
P1:SetAttribute("OwnedCosmetics", a1.Id .. "," .. a2.Id) -- achat reçu écran fermé
P1:SetAttribute("EquippedAura", a2.Id)
step(0.1)
local third = open()
local _, e1, t1 = buttons(rows()[a1.Id])
local b2, e2, t2 = buttons(rows()[a2.Id])
check(e1 and (a1 == a2 or t1 == "Equip") and not b2 and e2 and t2 == "Unequip", "17 achat et équipement reçus écran fermé : justes à la réouverture")
check(third.clones == 0 and third.assets == 0, "18 sans ligne neuve ni passe sur Assets (" .. third.clones .. ", " .. third.assets .. ")")

print("\n== onglets")
screen.Root.Tabs.TrailsTab.Activated:Fire()
step(0.5)
local r = rows()
check(r[Cosmetics.Trails[1].Id] ~= nil and r[a1.Id] == nil and countRows() == #Cosmetics.Trails, "19 onglet Trails : lignes des trails")
ok, bad = allIconsOk(Cosmetics.Trails)
check(ok, "20 trails : ICON_ avant FX_, FX_ teintée, sans texture l'image du Template, couchés " .. bad)
local keptTrail = r[Cosmetics.Trails[1].Id]
close()
local fourth = open()
check(fourth.clones == 0 and fourth.assets == 0 and rows()[Cosmetics.Trails[1].Id] == keptTrail, "21 rouverte sur Trails : mêmes lignes, sans passe sur Assets")
check(fourth.cascade == #Cosmetics.Trails, "22 cascade jouée (" .. fourth.cascade .. ")")
COUNT.assets = 0
screen.Root.Tabs.AurasTab.Activated:Fire()
step(0.5)
check(countRows() == #Cosmetics.Auras and COUNT.assets == 0, "23 retour aux auras : lignes refaites sans relire Assets")
local _, ea, ta = buttons(rows()[a2.Id])
check(ea and ta == "Unequip", "24 état des boutons repris")
close()

print("\n== réouverture pendant la fermeture")
open()
screen.Root.CloseButton.Activated:Fire()
step(0.02)
local fifth = open()
check(screen.Enabled and countRows() == #Cosmetics.Auras and fifth.clones == 0, "25 rouverte pendant sa sortie : lignes là, aucune copie")
close()

print("\n== nouvel écran (ResetOnSpawn) : textures relues une fois")
local copy = screen:Clone()
for _, child in copy.Root.List:GetChildren() do
	if string.sub(child.Name, 1, 5) == "Item_" then
		child:Destroy()
	end
end
screen:Destroy()
copy.Parent = playerGui
step(0.1)
screen = copy
list = copy.Root.List
local sixth = open()
check(sixth.clones == #Cosmetics.Auras and sixth.assets > FILLER and sixth.assets <= FILLER + 200, "26 lignes et textures refaites pour le nouvel écran (" .. sixth.clones .. ", " .. sixth.assets .. ")")
ok, bad = allIconsOk(Cosmetics.Auras)
check(ok, "27 icônes posées " .. bad)
close()
local seventh = open()
check(seventh.clones == 0 and seventh.assets == 0, "28 puis de nouveau rien de relu")
close()

print("\n== Decal livré en cours de partie")
local late = "rbxassetid://late217"
new("Decal", { Name = "ICON_" .. string.sub(a1.Texture, 4), Texture = late }, folder(assets, "Icons"))
local eighth = open()
check(eighth.clones == 0 and eighth.assets == 0, "30 réouverture : rien de refait ni relu (lignes en place)")
COUNT.assets = 0
screen.Root.Tabs.TrailsTab.Activated:Fire()
step(0.2)
screen.Root.Tabs.AurasTab.Activated:Fire()
step(0.2)
check(el(rows()[a1.Id], "IconArea").Icon.Image == late, "31 lignes refaites (onglet) : la nouvelle icône ICON_ posée")
check(COUNT.assets > FILLER and COUNT.assets <= FILLER + 200, "32 Assets relu une seule fois pour les deux onglets (" .. COUNT.assets .. ")")
close()

check(logCount("[AuraShop]", "WARN", "client") == 0, "29 aucun avertissement de la boutique d'auras")
summary()
