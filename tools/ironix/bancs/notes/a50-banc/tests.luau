---------------------------------------------------------------- scénarios a50 (L-090, L-089 point 4)
local playerGui = P1.PlayerGui
local TEMPLATE_IMAGE = "rbxassetid://template"

local function el(root, name)
	return root:FindFirstChild(name, true)
end

-- Icônes livrées : Fists et Wrench (comme en Studio le 2026-11-09), plus un faux Decal à Texture
-- vide pour Crowbar (pas encore importé : ne compte pas) et un Hammer rangé dans un sous-dossier.
local assets = folder(ReplicatedStorage, "Assets")
local icons = folder(assets, "Icons")
new("Decal", { Name = "ICON_TOOL_Fists", Texture = "rbxassetid://1001" }, icons)
new("Decal", { Name = "ICON_TOOL_Wrench", Texture = "rbxassetid://1002" }, icons)
new("Decal", { Name = "ICON_TOOL_Crowbar", Texture = "" }, icons)
new("Decal", { Name = "ICON_TOOL_Hammer", Texture = "rbxassetid://1004" }, folder(icons, "Tools"))

-- Copie grise de UI_WeaponShop (Template comme celui de Clément : Icon enfant direct, une autre
-- image nommée Icon plus bas dans BuyButton).
local function makeWeaponScreen()
	local screen = new("ScreenGui", { Name = "UI_WeaponShop", Enabled = true })
	screen:SetAttribute("ScreenGroup", "Menu")
	local window = new("Frame", { Name = "Window" }, screen)
	new("TextButton", { Name = "CloseButton", Text = "X" }, window)
	local list = new("ScrollingFrame", { Name = "List" }, window)
	local template = new("Frame", { Name = "Template", Visible = false }, list)
	local clip = new("Frame", { Name = "Clip" }, template)
	new("ImageLabel", { Name = "Rays", Image = "rbxassetid://rays" }, clip)
	new("ImageLabel", { Name = "Icon", Image = TEMPLATE_IMAGE }, template)
	new("TextLabel", { Name = "ItemName", Text = "Tool" }, template)
	new("TextLabel", { Name = "Power", Text = "Power" }, template)
	local buy = new("TextButton", { Name = "BuyButton", Text = "Buy" }, template)
	new("ImageLabel", { Name = "CashIcon", Image = "rbxassetid://cash" }, buy)
	new("TextLabel", { Name = "Price", Text = "$0" }, buy)
	new("TextButton", { Name = "EquipButton", Text = "Equip" }, template)
	screen.Parent = playerGui
	return screen, list
end

local function row(list, toolId)
	for _, child in list:GetChildren() do
		if string.match(child.Name, "_" .. toolId .. "$") then
			return child
		end
	end
	return nil
end

local function directIcon(r)
	return r:FindFirstChild("Icon")
end

print("\n== I. Icônes des armes (L-090)")
local screen, list = makeWeaponScreen()
step(0.05)
check(logCount("[WeaponShop] UI_WeaponShop branché : 7 outil(s)", "PRINT", "client") == 1, "I1 écran branché : 7 outils")
check(directIcon(row(list, "Fists")).Image == "rbxassetid://1001", "I2 Fists : Icon = Texture de ICON_TOOL_Fists")
check(directIcon(row(list, "Wrench")).Image == "rbxassetid://1002", "I3 Wrench : Icon = Texture de ICON_TOOL_Wrench")
check(directIcon(row(list, "Hammer")).Image == "rbxassetid://1004", "I4 Hammer : icône trouvée dans un sous-dossier d'Assets/Icons")
check(directIcon(row(list, "Crowbar")).Image == TEMPLATE_IMAGE, "I5 Crowbar : Decal à Texture vide = pas livré, image du Template gardée")
local keptOk = true
for _, id in { "Sledgehammer", "FireAxe", "AngleGrinder" } do
	if directIcon(row(list, id)).Image ~= TEMPLATE_IMAGE then
		keptOk = false
	end
end
check(keptOk, "I6 Sledgehammer, FireAxe, AngleGrinder : image du Template gardée")
check(el(row(list, "Fists"), "Rays").Image == "rbxassetid://rays" and el(row(list, "Fists"), "CashIcon").Image == "rbxassetid://cash", "I7 les autres images de la carte ne bougent pas")
check(el(list, "Template"):FindFirstChild("Icon").Image == TEMPLATE_IMAGE, "I8 Template intact")
local missing = logCount("pas encore dans ReplicatedStorage/Assets/Icons", "PRINT", "client")
check(missing == 4, "I9 une ligne par icône manquante (Crowbar, Sledgehammer, FireAxe, AngleGrinder) : " .. missing)
check(logCount("[WeaponShop]", "WARN", "client") == 0 and FAILS == 0, "I10 aucun avertissement ni erreur")

-- Écran recréé (ResetOnSpawn) : rebranché, pas de nouvelle ligne pour les mêmes icônes.
screen:Destroy()
step(0.05)
screen, list = makeWeaponScreen()
step(0.05)
check(directIcon(row(list, "Wrench")).Image == "rbxassetid://1002", "I11 écran recréé : icônes reposées")
check(logCount("pas encore dans ReplicatedStorage/Assets/Icons", "PRINT", "client") == 4, "I12 écran recréé : pas de ligne de plus (une seule par icône, par session)")

print("\n== S. Un seul écran du groupe ScreenGroup à la fois (L-089 point 4)")
local Motion = requireModule(StarterPlayerScripts.Client.Controllers.UI.Motion, "client")
local prompt
for _, d in WEAPON_SHOP:GetDescendants() do
	if d.ClassName == "ProximityPrompt" and d.Name == "WeaponShopPrompt" then
		prompt = d
	end
end
at(ROOT1, SHOP_SPOT)

-- Un écran du groupe avec contrôleur (fermeture enregistrée), un sans contrôleur, un d'un autre
-- groupe et un sans attribut.
local function grouped(name, group, enabled)
	local gui = new("ScreenGui", { Name = name, Enabled = enabled })
	if group then
		gui:SetAttribute("ScreenGroup", group)
	end
	new("Frame", { Name = "Root" }, gui)
	gui.Parent = playerGui
	return gui
end
local index = grouped("UI_Index", "Menu", false)
local rewards = grouped("UI_Rewards", "Menu", false)
local other = grouped("UI_Other", "Popup", false)
local hud = grouped("UI_HUD", nil, true)
local indexClosed = 0
Motion.SetCloser(index, function()
	indexClosed += 1
	Motion.Close(index)
end)

Motion.Open(index)
Motion.Open(rewards)
Motion.Open(other)
step(1)
check(index.Enabled == false and indexClosed == 1, "S1 Rewards ouvert : Index fermé par sa fonction de fermeture")
check(rewards.Enabled == true and other.Enabled == true and hud.Enabled == true, "S2 Rewards ouvert ; autre groupe et écran sans attribut pas touchés")

prompt.Triggered:Fire(P1)
step(1)
check(screen.Enabled == true and rewards.Enabled == false, "S3 boutique d'armes ouverte : Rewards (sans contrôleur) fermé par Motion.Close")
check(other.Enabled == true and hud.Enabled == true and indexClosed == 1, "S4 autre groupe, HUD et Index déjà fermé pas touchés")

Motion.Open(index)
step(1)
check(index.Enabled == true and screen.Enabled == false, "S5 Index ouvert : boutique d'armes fermée par son contrôleur")
-- Fermée par son propre chemin : l'écran ne se rouvre pas, et s'éloigner du comptoir ne fait rien.
at(ROOT1, FAR_SPOT)
step(1)
check(screen.Enabled == false and index.Enabled == true and FAILS == 0, "S6 s'éloigner ensuite : rien ne bouge, aucune erreur")
at(ROOT1, SHOP_SPOT)
prompt.Triggered:Fire(P1)
step(1)
check(screen.Enabled == true and index.Enabled == false and indexClosed == 2, "S7 l'invite rouvre la boutique d'armes et ferme Index")
at(ROOT1, FAR_SPOT)
step(1)
check(screen.Enabled == false, "S8 l'état « ouvert » est revenu : s'éloigner referme la boutique")

-- Réouverture d'un écran pendant sa fermeture : les autres du groupe se ferment quand même.
TIMED_TWEENS = true
at(ROOT1, SHOP_SPOT)
Motion.Open(index)
step(1)
prompt.Triggered:Fire(P1) -- ferme Index (animé)
step(0.02)
check(Motion.GetState(index) == "Closing", "S9 Index en train de se fermer")
Motion.Open(index) -- rattrapé pendant la fermeture
step(1)
check(index.Enabled == true and screen.Enabled == false, "S10 Index rattrapé pendant sa fermeture : la boutique d'armes se ferme")
-- Un écran déjà en train de se fermer n'est pas refermé (pas de 2e appel à sa fonction).
local before = indexClosed
prompt.Triggered:Fire(P1)
step(0.02)
Motion.Open(rewards)
step(1)
check(indexClosed == before + 1, "S11 écran déjà en fermeture : sa fonction n'est pas rappelée")
check(rewards.Enabled == true and index.Enabled == false and screen.Enabled == false, "S12 Rewards seul ouvert du groupe")
TIMED_TWEENS = false

-- SetCloser(gui, nil) retire la fonction : fermeture par Motion.Close.
Motion.SetCloser(index, nil)
Motion.Open(index)
step(1)
local count = indexClosed
Motion.Open(rewards)
step(1)
check(index.Enabled == false and indexClosed == count, "S13 fonction retirée : Index fermé par Motion.Close")
check(FAILS == 0, "S14 aucune erreur dans une tâche")

summary()
