--!nocheck
-- Scénario « best » (a316, demandes de Clément du 2026-11-23) sur le faux Roblox du banc a29 (copie a36), comme a185 :
--   L-295 : présentoir DisplaySlot_01 monté à y 2,75 (FitSize 6,5 × 12,5 × 6) : l'objet exposé a son pivot (bas au
--           centre) sur la place, donc sur le dessus du socle ; fitFactor (DisplayService) réduit au plus à 12,5 de haut.
--   L-296 : BestIcon (ImageLabel, enfant de BestItem, caché dans le gabarit) reçoit l'image ICON_ du meilleur objet,
--           change avec lui, reste caché et vide sans icône livrée, et quand la boutique n'a plus rien d'exposé.
-- Faux Model:GetScale et Model:ScaleTo (absents du faux Roblox d'a29 ; la voie FitSize de DisplayService les appelle) :
-- pièces sans rotation, positions et tailles mises à l'échelle autour du pivot.
if Methods.GetScale == nil then
	function Methods.GetScale(self)
		return rawget(self, "_a316scale") or 1
	end
	function Methods.ScaleTo(self, scale)
		local k = scale / (rawget(self, "_a316scale") or 1)
		local pivot = Methods.GetPivot(self).Position
		for _, d in Methods.GetDescendants(self) do
			if d:IsA("BasePart") then
				local p = d.CFrame.Position
				d.Size = d.Size * k
				d.CFrame = CFrame.new(pivot + (p - pivot) * k)
			end
		end
		rawset(self, "_a316scale", scale)
	end
end
local assets = ReplicatedStorage:FindFirstChild("Assets") or folder(ReplicatedStorage, "Assets")
local ui = assets:FindFirstChild("UI") or folder(assets, "UI")
local bb = make("BillboardGui", { Name = "BB_ShopInfo", Size = UDim2.fromScale(19, 7.5) }, ui)
local panel = make("Frame", { Name = "Panel" }, bb)
make("TextLabel", { Name = "OwnerName", Text = "Alice's Shop" }, panel)
make("TextLabel", { Name = "Income", Text = "+$0/s" }, panel)
local hpLine = make("Frame", { Name = "HPLine" }, panel)
make("ImageLabel", { Name = "HPIcon", Image = "" }, hpLine)
make("TextLabel", { Name = "DoorLabel", Text = "DOOR" }, hpLine)
make("TextLabel", { Name = "HP", Text = "7/40" }, hpLine)
local best = make("TextLabel", { Name = "BestItem", Text = "Golden Lucky Cat", Visible = true }, panel)
make("TextLabel", { Name = "BestLabel", Text = "BEST ITEM" }, best)
make("ImageLabel", { Name = "BestIcon", Image = "", Visible = false }, best)
local pill = make("Frame", { Name = "Status", Visible = true }, bb)
make("TextLabel", { Name = "Label", Text = "LOCKED 23s" }, pill)

-- Icônes livrées : la canette et le PC ; le donut n'en a pas.
local icons = assets:FindFirstChild("Icons") or folder(assets, "Icons")
make("Decal", { Name = "ICON_Z1_CanetteDeSoda", Texture = "rbxassetid://1001" }, icons)
make("Decal", { Name = "ICON_Z3_PcGamer", Texture = "rbxassetid://2002" }, icons)

-- L-295 : la place 1 de la boutique 1 à y 2,75 au-dessus du sol (le faux sol est à 0,15 de son pivot), FitSize de Clément.
local FIT = Vector3.new(6.5, 12.5, 6)
local shop1 = SHOPS[1].model
local slot1 = shop1:FindFirstChild("DisplaySlot_01", true)
local slotLocal = slot1.CFrame.Position
slot1.CFrame = CFrame.new(slotLocal.X, 2.75 - 0.15, slotLocal.Z)
slot1:SetAttribute("FitSize", FIT)
SHOPS[1].S.slots[1] = SHOPS[1].S.origin * Vector3.new(slotLocal.X, 2.75, slotLocal.Z)

startSkills()
local adaData = newProfile()
addItem(adaData, "ada-soda", "Z1_CanetteDeSoda", 1)
addItem(adaData, "ada-pc", "Z3_PcGamer", 2)
local ada = join("Ada", adaData)
local cydData = newProfile()
addItem(cydData, "cyd-donut", "Z1_Donut", 1)
local cyd = join("Cyd", cydData)
local bob = join("Bob", newProfile())
advance(1.2)
startClient(bob)

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-3)
end

section("L-295 : objet posé sur une place à y 2,75")
local shop = shopOf(ada)
check(shop == shop1, "Ada a la boutique 1 (place montée)")
local model = displayModel(shop, 1)
check(model ~= nil, "la canette est exposée sur la place 1")
if model then
	local pivot = model:GetPivot().Position
	local world = slot1.WorldPosition
	check(near(pivot.Y, world.Y) and near(pivot.X, world.X) and near(pivot.Z, world.Z), `pivot de l'objet sur la place (y {pivot.Y} ; place y {world.Y})`)
	check(near(world.Y - SHOPS[1].S.origin.Position.Y, 2.75), "la place est à 2,75 au-dessus du pivot de la boutique")
	local lowest = math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			lowest = math.min(lowest, d.CFrame.Position.Y - d.Size.Y / 2)
		end
	end
	check(lowest >= world.Y - 0.01, `aucune pièce visible sous le dessus du socle (plus bas {lowest})`)
end
-- fitFactor de DisplayService, extrait tel quel : boîte de 0 à FitSize.Y au-dessus du pivot.
do
	local text = SOURCES["server/Services/DisplayService.luau"]
	local from = string.find(text, "-- Coins d'une pièce (demi-taille × signe), pour fitFactor.", 1, true)
	local to = string.find(text, "-- a234 : portée de chaque lumière", 1, true)
	check(from ~= nil and to ~= nil and from < to, "DisplayService : bloc fitFactor trouvé")
	if from and to then
		local chunk = loadstring(string.sub(text, from, to - 1) .. "\nreturn fitFactor", "=fitFactor")
		setfenv(chunk, setmetatable({ Attributes = { Idle = { Name = "Idle" } }, Vector3 = Vector3 }, { __index = getfenv(1) }))
		local fitFactor = chunk()
		local pivot = CFrame.new(10, 2.75, -30)
		local function item(height)
			local m = make("Model", { Name = "Tall" })
			make("Part", { Name = "Body", Size = Vector3.new(2, height, 2), CFrame = CFrame.new(10, 2.75 + height / 2, -30) }, m)
			return m
		end
		check(near(fitFactor(item(25), pivot, FIT), 0.5), "25 de haut sur la place à 2,75 : ×0,5 (12,5 de haut, sous le plafond)")
		check(near(fitFactor(item(12.5), pivot, FIT), 1), "12,5 de haut : tient (×1), mesuré depuis la place et non depuis le sol")
	end
end

-- Panneau de repérage vu par Bob devant une boutique.
local function look(plot)
	local S = refsOfShop(plot)
	moveTo(bob, S.outside + S.front * -1)
	advance(0.6)
	return bob.PlayerGui:FindFirstChild("ShopInfo_" .. plot.Name)
end
local function state(g)
	local item = if g then g:FindFirstChild("BestItem", true) else nil
	local icon = if g then g:FindFirstChild("BestIcon", true) else nil
	return item, icon
end

section("L-296 : BestIcon du meilleur objet")
local g = look(shop)
check(g ~= nil and g:FindFirstChild("Panel") ~= nil, "le panneau est la copie de BB_ShopInfo")
local item, icon = state(g)
check(item ~= nil and item.Visible == true and item.Text == "Gaming PC", `BestItem : « {item and item.Text} » (le PC rapporte plus que la canette)`)
check(icon ~= nil and icon:IsA("ImageLabel"), "BestIcon trouvé sous BestItem")
check(icon ~= nil and icon.Image == "rbxassetid://2002" and icon.Visible == true, `BestIcon : ICON_Z3_PcGamer montrée ({icon and icon.Image}, Visible = {tostring(icon and icon.Visible)})`)
local label = if g then g:FindFirstChild("BestLabel", true) else nil
check(label ~= nil and label.Text == "BEST ITEM", "BestLabel laissé tel quel (décor)")
local hpIcon = if g then g:FindFirstChild("HPIcon", true) else nil
check(hpIcon ~= nil and hpIcon.Image == "", "HPIcon : image vide gardée (L-296 : ne pas la remplir)")
local text = PvPController.GetPanelText(shop)
check(text ~= nil and text.BestIcon == "rbxassetid://2002" and text.BestItem == "Gaming PC", "GetPanelText : BestItem et BestIcon")

section("L-296 : le meilleur objet change")
DisplayService.Unplace(ada, "ada-pc")
advance(0.6)
item, icon = state(g)
check(item ~= nil and item.Visible == true and item.Text == "Soda Can", `BestItem : « {item and item.Text} »`)
check(icon ~= nil and icon.Image == "rbxassetid://1001" and icon.Visible == true, `BestIcon : ICON_Z1_CanetteDeSoda ({icon and icon.Image})`)

section("L-296 : plus rien d'exposé")
DisplayService.Unplace(ada, "ada-soda")
advance(0.6)
item, icon = state(g)
check(item ~= nil and item.Visible == false, "BestItem caché")
check(icon ~= nil and icon.Image == "" and icon.Visible == false, `BestIcon vidé et caché ({icon and icon.Image}, Visible = {tostring(icon and icon.Visible)})`)
text = PvPController.GetPanelText(shop)
check(text ~= nil and text.BestIcon == nil and text.BestItem == nil, "GetPanelText : ni BestItem ni BestIcon")

section("L-296 : icône pas livrée")
local cydShop = shopOf(cyd)
local g2 = look(cydShop)
local item2, icon2 = state(g2)
check(item2 ~= nil and item2.Visible == true and item2.Text == "Donut", `BestItem : « {item2 and item2.Text} »`)
check(icon2 ~= nil and icon2.Image == "" and icon2.Visible == false, "BestIcon reste caché et vide (pas d'ICON_Z1_Donut)")

section("sortie")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")
summary("scénario best")
