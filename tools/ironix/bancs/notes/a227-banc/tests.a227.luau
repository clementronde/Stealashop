--!nocheck
-- Banc a227 (vague 69, L-175) : UI_TheftAlert v3 de Clément (bandeau seul ; ThiefName, ItemName, Arrow gardés dans
-- Banner.Unused caché), puis Banner.Unused supprimé : le vrai ContractChecker n'y voit aucun problème, seulement
-- des avertissements « facultatif » quand les trois éléments manquent.

moduleScript(SERVICES, "ContractChecker", "server/Services/ContractChecker.luau")
local function theftScreen(withUnused)
	local screen = make("ScreenGui", { Name = "UI_TheftAlert", Enabled = false, ResetOnSpawn = true, IgnoreGuiInset = true })
	local banner = make("Frame", { Name = "Banner", Visible = true }, screen)
	make("TextLabel", { Name = "Title", Text = "YOUR BASE IS BEING ROBBED!" }, banner)
	if withUnused then
		local unused = make("Frame", { Name = "Unused", Visible = false }, banner)
		make("TextLabel", { Name = "ThiefName", Text = "PLAYER" }, unused)
		make("TextLabel", { Name = "ItemName", Text = "ITEM" }, unused)
		make("ImageLabel", { Name = "Arrow", Rotation = 0 }, unused)
	end
	screen.Parent = StarterGui
	return screen
end
local gui = theftScreen(true)
startServer()
local UI = sharedModule("Contract/UI")
local Checker = serverModule("ContractChecker")
local function rerun()
	clearLog()
	Checker.Start()
	flush()
end
local spec
for _, screen in UI.Screens do
	if screen.Name == "UI_TheftAlert" then
		spec = screen
	end
end
local byPath = {}
for _, element in spec.Elements do
	byPath[element.Path] = element
end

section("Contract/UI : UI_TheftAlert")
check(byPath.Banner ~= nil and not byPath.Banner.Optional, "Banner reste obligatoire")
check(byPath.ThiefName.Optional == true and byPath.ItemName.Optional == true and byPath.Arrow.Optional == true, "ThiefName, ItemName et Arrow facultatifs")
check(byPath.Arrow.Class == "ImageLabel", "Arrow reste une ImageLabel quand elle est là")

section("ContractChecker : v3 de Clément (éléments dans Banner.Unused)")
rerun()
check(logHas("[Contrat] Contrat :", nil, "server"), "le vérificateur tourne jusqu'au bout")
check(not logHas("UI · UI_TheftAlert", nil, "server"), "aucune ligne sur UI_TheftAlert")

section("ContractChecker : Banner.Unused supprimé (bandeau seul)")
gui:Destroy()
gui = theftScreen(false)
rerun()
check(logHas("UI_TheftAlert.ThiefName absent (facultatif)", "WARN", "server") and logHas("UI_TheftAlert.ItemName absent (facultatif)", "WARN", "server") and logHas("UI_TheftAlert.Arrow absent (facultatif)", "WARN", "server"), "trois avertissements « facultatif »")
check(logCount("UI · UI_TheftAlert", nil, "server") == 3, `rien d'autre sur UI_TheftAlert ({logCount("UI · UI_TheftAlert", nil, "server")} lignes)`)

section("ContractChecker : Arrow mal livrée")
gui.Banner.Title:Destroy()
make("Frame", { Name = "Arrow" }, gui.Banner)
rerun()
check(logHas("UI_TheftAlert.Arrow doit être un ImageLabel", "WARN", "server"), "une Arrow présente mais pas une ImageLabel : problème")

summary("scénario a227")
