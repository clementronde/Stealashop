--!nocheck
-- Scénario « panel » (a177, vague 55, Cantin : « il est dans le mur ») : le panneau de repérage (nom, $/s, « 40/40 »)
-- est posé devant la porte, côté rue, à PvP.ShopPanelForward studs du plan de la vitre et au-dessus d'elle, hors du
-- volume Bounds ; vrai pour une boutique tournée de 90° (avant vers +X).
startSkills()
local PvP = sharedModule("Config/PvP")
local function owner(name)
	local data = newProfile()
	addItem(data, name .. "-soda", "Z1_CanetteDeSoda", 1)
	return join(name, data)
end
local ada = owner("Ada")
local bob = join("Bob", newProfile())
local cy = owner("Cy")
advance(1.2)
startClient(bob)

local function panelOf(shop)
	local gui = bob.PlayerGui:FindFirstChild("ShopInfo_" .. shop.Name)
	local point = if gui then gui.Adornee else nil
	return gui, point
end

for _, who in { ada, cy } do
	local shop = shopOf(who)
	local S = refsOfShop(shop)
	section(`panneau de la boutique de {who.Name} ({shop.Name})`)
	moveTo(bob, S.outside + S.front * -1)
	advance(0.6)
	local text = PvPController.GetPanelText(shop)
	check(text ~= nil and text.HP == "40/40", `panneau affiché, « {text and text.HP} »`)
	local gui, point = panelOf(shop)
	check(gui ~= nil and point ~= nil and point.Name == "ShopInfoPoint", "panneau accroché à son point ShopInfoPoint")
	if point then
		local pos = point.WorldPosition
		local bounds = shop:FindFirstChild("Bounds")
		local door = shop:FindFirstChild("Window", true)
		local cf, size = door:GetBoundingBox()
		local ahead = (pos - cf.Position):Dot(S.front)
		print(`  mesure : {shop.Name} : {string.format("%.2f", ahead)} studs devant la porte, {string.format("%.2f", pos.Y - (cf.Position.Y + size.Y / 2))} au-dessus`)
		check(not insideBox(bounds, pos), "hors du volume Bounds")
		check(math.abs(ahead - PvP.ShopPanelForward) < 0.01, `côté rue, à {PvP.ShopPanelForward} studs du plan de la porte`)
		check(pos.Y > cf.Position.Y + size.Y / 2, "au-dessus de la porte")
		local side = (pos - cf.Position) - S.front * ahead
		check(Vector3.new(side.X, 0, side.Z).Magnitude < 0.01, "au milieu de la porte")
	end
	moveTo(bob, HUB_CENTER)
	advance(0.6)
end

section("sortie")
check(not logHas("tick :", "WARN"), "aucune erreur dans les boucles des services")
summary("scénario panel")
