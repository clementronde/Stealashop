---------------------------------------------------------------- scénario « hud3 » (a205, vague 63 ; L-202 point 1, L-192 Q1)
-- HUD v3 de Clément : plus de menu « More », petites icônes dans TopLeftRow (attribut FollowTopbarInset), calé sur
-- GuiService.TopbarInset (bord gauche Min.X + 8 px, centré dans la barre), RebirthButton montré à la renaissance.
P1:SetAttribute("Cash", 100)
P1:SetAttribute("Income", 1)
P1:SetAttribute("WalkSpeed", 16)
P1:SetAttribute("Damage", 1)
local Find = requireModule(ReplicatedStorage.Shared.Contract.Find, "client")
local AlertBadge = requireModule(ReplicatedStorage.Shared.AlertBadge, "client")
local Menu = requireModule(MENU_MODULE, "client")
local Hud = requireModule(HUD_MODULE, "client")
local GAP = HudCfgC.TopLeftRow.Gap
check(GAP == 8 and HudCfgC.TopLeftRow.Attribute == "FollowTopbarInset", "H0 Config/Hud.TopLeftRow : Gap 8 (Clément), attribut FollowTopbarInset")
check(HudCfgC.Menu == nil, "H0b plus de Config/Hud.Menu")

setTopbarInset(60, 900, 58)
local hud, row = makeV3Hud()
taskLib.spawn(Hud.Start)
taskLib.spawn(Menu.Start)
step(0.2)

print("\n== H1. Boutons trouvés dans TopLeftRow et dans les deux colonnes (mêmes recherches que leurs contrôleurs)")
for _, name in { "RewardsButton", "InviteButton" } do
	local found = Find.path(hud, name) -- RewardsController, InviteController
	check(found ~= nil and found.Parent == row and found:IsA("GuiButton"), `H1a {name} trouvé dans TopLeftRow (Find.path)`)
end
for _, name in { "SettingsButton", "RebirthButton" } do
	local all = Find.all(hud, name) -- SettingsController, RebirthController
	check(#all == 1 and all[1].Parent == row, `H1b {name} : un exemplaire, dans TopLeftRow (Find.all)`)
end
check(Find.path(el(hud, "RewardsButton"), "RewardsAlert") ~= nil, "H1c RewardsAlert sous RewardsButton (RewardsController)")
check(#AlertBadge.Find(hud, "RebirthAlert") == 1, "H1d RebirthAlert trouvée (RailAlertController)")
for _, name in { "IndexButton", "SkillTreeButton", "RobuxShopButton" } do
	check(#Find.all(hud, name) == 2, `H1e {name} : deux exemplaires (LeftRail, LeftRailTouch), tous deux branchés (Find.all)`)
end
local indexAlerts = AlertBadge.Find(hud, "IndexAlert")
check(#indexAlerts == 2, "H1f IndexAlert : les deux pastilles trouvées (AlertBadge.Find)")
AlertBadge.SetAll(indexAlerts, true)
check(indexAlerts[1].Visible and indexAlerts[2].Visible, "H1g les deux pastilles s'allument ensemble")
AlertBadge.SetAll(indexAlerts, false)
check(el(hud, "SettingsButton").Visible == true, "H1h SettingsButton laissé visible (Features.Settings)")

print("\n== H2. TopLeftRow calé sur la barre de Roblox")
local function pos()
	return row.Position.X.Offset, row.Position.Y.Offset, row.Position.X.Scale, row.Position.Y.Scale
end
local x, y, sx, sy = pos()
check(x == 60 + GAP and y == 7 and sx == 0 and sy == 0, `H2a inset 60 px, barre 58 : (68, 7) px ({x}, {y})`)
check(row.AbsolutePosition.Y + row.AbsoluteSize.Y / 2 == 29, `H2b centré dans la barre (milieu à 29 px : {row.AbsolutePosition.Y + row.AbsoluteSize.Y / 2})`)
setTopbarInset(104, 900, 58)
x, y = pos()
check(x == 104 + GAP and y == 7, `H2c TopbarInset change (104) : recalé ({x}, {y})`)
setTopbarInset(104, 900, 36)
x, y = pos()
check(x == 112 and y == -4, `H2d barre de 36 px (ancienne barre) : centré, (112, -4) ({x}, {y})`)
setTopbarInset(0, 0, 0)
x, y = pos()
check(x == 112 and y == -4, `H2e barre coupée (hauteur 0) : la place d'avant tient ({x}, {y})`)
check(Menu.PlaceTopLeftRow ~= nil, "H2f PlaceTopLeftRow exposé")
hud:Destroy()

print("\n== H3. Parent décalé (écran sous la barre, IgnoreGuiInset = false) et AnchorPoint")
setTopbarInset(60, 900, 58)
local hudB, rowB = makeV3Hud({ holder = UDim2.fromOffset(0, 58), anchor = Vector2.new(0.5, 0.5) })
step(0.1)
x, y = rowB.Position.X.Offset, rowB.Position.Y.Offset
check(x == 68 + 100 and y == 29 - 58, `H3a origine du parent retirée, AnchorPoint (0,5 ; 0,5) : (168, -29) ({x}, {y})`)
check(rowB.AbsolutePosition.X == 68 and rowB.AbsolutePosition.Y == 7, `H3b à l'écran : bord gauche 68, haut 7 ({rowB.AbsolutePosition.X}, {rowB.AbsolutePosition.Y})`)
hudB:Destroy()

print("\n== H4. Sans l'attribut FollowTopbarInset : la place de Clément")
local hudC, rowC = makeV3Hud({ follow = false })
step(0.1)
check(rowC.Position.X.Offset == 120 and rowC.Position.Y.Offset == -51, "H4a TopLeftRow pas touché (120, -51)")
setTopbarInset(80, 900, 58)
check(rowC.Position.X.Offset == 120, "H4b même quand TopbarInset change")

print("\n== H5. RebirthButton : caché tant que la renaissance est coupée, montré quand elle s'ouvre")
local rebirth = el(hudC, "RebirthButton")
check(rebirth.Visible == false, "H5a renaissance coupée (pas d'attribut Rebirths) : caché")
P1:SetAttribute("Rebirths", 0)
step(0.1)
check(rebirth.Visible == true, "H5b attribut Rebirths posé (RebirthService) : montré")
hudC:Destroy()
local hudD = makeV3Hud()
step(0.1)
check(el(hudD, "RebirthButton").Visible == true, "H5c HUD recréé avec la renaissance ouverte : montré")
P1:SetAttribute("Rebirths", nil)
hudD:Destroy()
local hudE = makeV3Hud()
step(0.1)
check(el(hudE, "RebirthButton").Visible == false, "H5d renaissance coupée : le nouveau HUD le garde caché")

check(not logHas("ERREUR"), "H9 aucune erreur")
summary()
