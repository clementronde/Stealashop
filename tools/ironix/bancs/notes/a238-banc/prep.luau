--!nocheck
-- a238 (vague 71, L-213 point 1) : écran v2 d'a208 complété comme la maquette de Clément du 16/11 (ajouts purs) :
-- UIPadding de List (4 px en haut, 12 en bas), AutomaticCanvasSize = Y, List.Content mesuré à 1 644 px (AbsoluteSize,
-- posé à la main : le faux Roblox ne calcule pas les tailles), Clip.Watermark (la basket) dans chaque Template, et
-- l'icône de zZz (UI_Icon_Sleep) en Decal dans Assets.
HUD = buildHud(PLAYER_GUI)
V2 = buildRobuxShopV2(PLAYER_GUI)
P1:SetAttribute("Income", 100)
LIST = v2El(V2, "List")
CONTENT = LIST:FindFirstChild("Content")
make("UIPadding", { Name = "UIPadding", PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 12) }, LIST)
LIST.AutomaticCanvasSize = Enum.AutomaticSize.Y
LIST.CanvasSize = UDim2.new(0, 0, 0, 0)
CONTENT.AbsoluteSize = Vector2.new(400, 1644)
BASKET = "rbxassetid://238000"
SLEEP_ICON = "rbxassetid://238001"
for _, name in { "GamepassesSection", "BoostsSection", "CashSection" } do
	local template = v2El(V2, name .. ".Grid.Template")
	local clip = make("Frame", { Name = "Clip" }, template)
	make("ImageLabel", { Name = "Watermark", Image = BASKET }, clip)
end
make("Decal", { Name = "UI_Icon_Sleep", Texture = SLEEP_ICON }, folder(ASSETS, "Icons238"))
function openShop()
	click(hudButton(HUD, "RobuxShopButton"))
	advance(0.5)
end
