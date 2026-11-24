--!nocheck
-- Scénario « bandeau » (a227, vague 69, L-175) : UI_TheftAlert v3 de Clément, un bandeau seul (Banner.Title décoratif) ;
-- ThiefName, ItemName et Arrow gardés dans Banner.Unused caché, puis supprimés. L'alerte s'affiche dans les deux cas,
-- sans erreur, sans écran V0 et sans Beam V0 au sol.

startServer()

local ada = join("Ada", victimProfile())
local bob = join("Bob", newProfile())
local cy = join("Cy", newProfile())
giveBat(ada)
local function v3Screen(parent, withUnused)
	local screen = make("ScreenGui", { Name = "UI_TheftAlert", Enabled = true, ResetOnSpawn = true })
	local banner = make("Frame", { Name = "Banner", Visible = true }, screen)
	make("TextLabel", { Name = "Title", Text = "YOUR BASE IS BEING ROBBED!" }, banner)
	if withUnused then
		local unused = make("Frame", { Name = "Unused", Visible = false }, banner)
		make("TextLabel", { Name = "ThiefName", Text = "PLAYER" }, unused)
		make("TextLabel", { Name = "ItemName", Text = "ITEM" }, unused)
		make("ImageLabel", { Name = "Arrow", Rotation = 0, Visible = true }, unused)
	end
	screen.Parent = parent
	return screen
end
local screen = v3Screen(ada.PlayerGui, true)
startClient(ada)
advance(0.5)
local adaShop = shopOf(ada)

section("v3 avec Banner.Unused")
check(screen.Enabled == false, "éteint au repos")
check(breakDoor(bob, adaShop), "porte d'Ada cassée par Bob")
check(steal(bob, adaShop, 1), "Bob prend la Canette de soda")
frame()
local s = state()
check(s.Active and not s.Fallback and screen.Enabled == true, "alerte sur l'écran de Clément, allumé")
check(screen.Banner.Title.Text == "YOUR BASE IS BEING ROBBED!", "Banner.Title décoratif pas touché")
check(screen.Banner.Unused.Visible == false, "Banner.Unused reste caché")
check(s.ThiefName == "BOB" and s.ItemName == "SODA CAN", "pseudo et objet écrits dans Banner.Unused (invisibles)")
check(CAMERA:FindFirstChild("TheftAlertArrow") == nil and ada.PlayerGui:FindFirstChild("TheftAlertV0") == nil, "ni Beam V0 ni écran V0")
runHome(bob, adaShop)
check(not state().Active and screen.Enabled == false, "dépôt de Bob : alerte finie")

section("v3 sans Banner.Unused (bandeau seul)")
screen:Destroy()
local bare = v3Screen(ada.PlayerGui, false)
advance(0.25)
check(steal(cy, adaShop, 2), "Cy prend le Paquet de chips (porte encore cassée)")
frame()
s = state()
check(s.Active and not s.Fallback and bare.Enabled == true and bare.Banner.Visible == true, "alerte sur le bandeau de Clément")
check(not s.Arrow and s.ThiefName == nil and s.ItemName == nil, "sans ThiefName, ItemName ni Arrow : rien à écrire, aucune flèche")
for _ = 1, 10 do
	frame()
end
check(CAMERA:FindFirstChild("TheftAlertArrow") == nil and ada.PlayerGui:FindFirstChild("TheftAlertV0") == nil, "ni Beam V0 ni écran V0")
check(s.Highlights == 1 and alertHighlightOf(cy) ~= nil, "Cy toujours surligné à travers les murs")
runHome(cy, adaShop)
check(not state().Active and bare.Enabled == false, "dépôt de Cy : alerte finie")
check(not logHas("[TheftAlertController]", "WARN"), "aucune erreur du contrôleur")

summary("scénario bandeau")
