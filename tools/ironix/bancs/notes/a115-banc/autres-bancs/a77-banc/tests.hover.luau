---------------------------------------------------------------- scénario « hover » (a77, vague 25) : seul l'élément du dessus réagit au survol
-- Ajouts au faux Roblox (locales du stubs, même fichier) : Active, PlayerGui:GetGuiObjectsAtPosition
-- (liste HITS posée par le test), UserInputService:GetMouseLocation et GuiService:GetGuiInset.
PROPS.Frame.Active = false
PROPS.TextButton.Active = true
PROPS.ImageButton.Active = true
PROPS.ImageLabel.Active = false
PROPS.TextLabel.Active = false
HITS = {}
QUERIES = {}
MOUSE = Vector2.new(100, 136)
INSET = Vector2.new(0, 36)
Methods.GetGuiObjectsAtPosition = function(self, x, y)
	table.insert(QUERIES, { x = x, y = y })
	if HITS_AT_RAW_ONLY and y ~= MOUSE.Y then
		return {}
	end
	return HITS
end
do
	local base = games.client.GetService
	games.client.GetService = function(self, name)
		if name == "UserInputService" then
			return { GetMouseLocation = function() return MOUSE end }
		elseif name == "GuiService" then
			return { GetGuiInset = function() return INSET, Vector2.new(0, 0) end }
		end
		return base(self, name)
	end
end

local Motion = requireModule(MOTION_MODULE, "client")
Motion.SetSoundPlayer(function() end)
local Hv = UiMotionC.Hover

local hud = new("ScreenGui", { Name = "UI_HUD" }, PLAYER_GUI)
local rail = new("Frame", { Name = "LeftRail", BackgroundTransparency = 1 }, hud)
local shop = new("TextButton", { Name = "RobuxShopButton" }, rail)
local icon = new("ImageLabel", { Name = "Icon" }, shop)
local index = new("ScreenGui", { Name = "UI_Index_v3", Enabled = true }, PLAYER_GUI)
index:SetAttribute("ScreenGroup", "Menu")
local root = new("Frame", { Name = "Root", BackgroundTransparency = 1 }, index)
local panel = new("Frame", { Name = "Panel" }, root)
local tabs = new("Frame", { Name = "MutationTabs", BackgroundTransparency = 1 }, root)
local tab = new("TextButton", { Name = "ShinyTab" }, tabs)
Motion.Button(shop)
Motion.Button(tab)

local function grown(button)
	local s = scaleNamed(button, Hv.ScaleName)
	return s ~= nil and near(s.Scale, Hv.To, 1e-4)
end
local function leave(button)
	button.MouseLeave:Fire()
	step(Hv.Time + 0.1)
end

print("\n== H1. Onglet de mutation au-dessus du bouton Shop du HUD")
HITS = { tab, tabs, root, shop, icon, rail }
QUERIES = {}
shop.MouseEnter:Fire()
tab.MouseEnter:Fire()
step(Hv.Time + 0.1)
check(not grown(shop) and countClass(shop, "UIScale") == 0, "H1a bouton du HUD recouvert : pas de survol")
check(grown(tab), "H1b onglet du dessus : survol accepté")
check(#QUERIES > 0 and QUERIES[1].x == 100 and QUERIES[1].y == 100, "H1c coordonnées : souris moins le décalage du haut (GetGuiInset)")
leave(shop)
leave(tab)

print("\n== H2. Bouton du HUD seul sous la souris (icône d'abord, cadre transparent du menu ignoré)")
HITS = { root, icon, shop, rail }
shop.MouseEnter:Fire()
step(Hv.Time + 0.1)
check(grown(shop), "H2a bouton du dessus (son icône en premier) : survol accepté")
leave(shop)
check(countClass(shop, "UIScale") == 0, "H2b sortie : retour à 1")

print("\n== H3. Écran Menu ouvert : son panneau visible recouvre le bouton")
HITS = { panel, root, icon, shop, rail }
shop.MouseEnter:Fire()
step(Hv.Time + 0.1)
check(not grown(shop), "H3a panneau d'un écran Menu par-dessus : pas de survol")
index.Enabled = false
shop.MouseEnter:Fire()
step(Hv.Time + 0.1)
check(grown(shop), "H3b écran Menu fermé : survol accepté")
leave(shop)
index.Enabled = true

print("\n== H4. Cadre Active d'un autre écran par-dessus")
local other = new("ScreenGui", { Name = "UI_Other" }, PLAYER_GUI)
local blocker = new("Frame", { Name = "Blocker", BackgroundTransparency = 1, Active = true }, other)
HITS = { blocker, shop }
shop.MouseEnter:Fire()
step(Hv.Time + 0.1)
check(not grown(shop), "H4a cadre Active par-dessus : pas de survol")

print("\n== H5. Coordonnées : liste trouvée seulement à la position brute, ou pas du tout")
HITS = { tab, shop }
HITS_AT_RAW_ONLY = true
shop.MouseEnter:Fire()
step(Hv.Time + 0.1)
check(not grown(shop), "H5a position brute essayée ensuite : recouvert, pas de survol")
HITS_AT_RAW_ONLY = false
HITS = { tab }
shop.MouseEnter:Fire()
step(Hv.Time + 0.1)
check(grown(shop), "H5b bouton absent des listes : survol accepté, comme avant")
leave(shop)

print("\n== H6. Carte (HoverCard) recouverte")
local list = new("Frame", { Name = "Rows", BackgroundTransparency = 1 }, root)
local card = new("TextButton", { Name = "Card" }, list)
local outline = new("Frame", { Name = UiMotionC.HoverCard.Outline, Visible = false }, card)
Motion.HoverCard(card)
HITS = { tab, card }
card.MouseEnter:Fire()
step(0.5)
check(outline.Visible == false, "H6a carte recouverte : pas de HoverOutline")
HITS = { card, list }
card.MouseEnter:Fire()
step(0.5)
check(outline.Visible == true, "H6b carte du dessus : HoverOutline visible")
card.MouseLeave:Fire()
step(0.5)
check(outline.Visible == false, "H6c sortie : HoverOutline rendu")
summary()
