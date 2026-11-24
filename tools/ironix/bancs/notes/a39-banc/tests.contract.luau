--!nocheck
-- Scénario « contract » : ShopPad, enfant facultatif (une pièce) des comptoirs WeaponShop, AuraShop et
-- RobuxShop (Contract/Models), et l'écran UI_Rebirth (Contract/UI), lus par le vrai ContractChecker
-- sur une fausse place : comptoirs sans plaque = avertissements (pas des problèmes), plaque posée =
-- rien à dire, plaque mal livrée = problème ; UI_Rebirth conforme = rien à dire, mal livré = problème,
-- absent = pas encore livré.

local Models = sharedModule("Contract/Models", "server")
local UI = sharedModule("Contract/UI", "server")
local weapon = makeStall("ENV_Hub_WeaponStall", "WeaponShop", WEAPON_PIVOT, false)
local aura = makeStall("ENV_Hub_AuraStall", "AuraShop", AURA_PIVOT, false)
local robux = makeStall("ENV_Hub_RobuxStall", "RobuxShop", ROBUX_PIVOT, false)
local rebirth = buildRebirth(StarterGui)
local Checker = requireModule(CHECKER_MODULE, "server")

local function run()
	clearLog()
	Checker.Start()
	flush()
end
local function summaryLine()
	for _, line in LOG do
		if line.side == "server" and string.find(line.text, "[Contrat] Contrat :", 1, true) then
			return line.text, line.kind
		end
	end
	return "?", "?"
end
local function lineWith(pattern, kind)
	return logHas(pattern, kind, "server")
end
local function shout()
	for _, line in LOG do
		if line.side == "server" and line.kind == "WARN" then
			print("    " .. line.text)
		end
	end
end
local NOTE = "(facultative : marcher dessus ouvre l'écran du comptoir ; sans elle, seule l'invite « Shop » l'ouvre, L-071)"

section("Contract/Models : comptoirs et ShopPad")
local specs = { Models.WeaponShopCounter, Models.AuraShopCounter, Models.RobuxShopCounter }
for index, tag in { "WeaponShop", "AuraShop", "RobuxShop" } do
	local spec = specs[index]
	local pad = spec and spec.Parts[1]
	check(spec ~= nil and spec.Tag == tag and spec.Category == "Boutiques d'achat" and #spec.Parts == 1, `comptoir {tag} au contrat (catégorie « Boutiques d'achat »)`)
	check(pad ~= nil and pad.Name == "ShopPad" and pad.Class == "BasePart" and pad.Optional == true, `{tag} : ShopPad, une pièce (BasePart), facultative`)
	check(table.find(Models.List, spec) ~= nil, `{tag} : dans Models.List (rapport)`)
end
check(Models.List[#Models.List] == Models.RobuxShopCounter and table.find(Models.List, Models.BoxTrail) < table.find(Models.List, Models.WeaponShopCounter), "à la fin du rapport, après les modèles d'avant")

section("Contract/UI : UI_Rebirth")
local screen = nil
for _, entry in UI.Screens do
	if entry.Name == "UI_Rebirth" then
		screen = entry
	end
end
check(screen ~= nil and screen.Class == "ScreenGui", "UI_Rebirth au contrat (ScreenGui)")
local paths = {}
for _, element in screen and screen.Elements or {} do
	paths[element.Path] = element.Class or true
end
for _, path in { "Level", "CashRequirement.CashAmount", "CashRequirement.CashBar.Fill", "CashRequirement.CashLabel", "ItemRequirement.Icon", "ItemRequirement.ItemName", "ItemRequirement.Rarity", "ItemRequirement.Status", "GainList", "ConfirmButton.Disabled", "ConfirmButton.Ready", "ConfirmButton.Confirm", "Hint" } do
	check(paths[path] ~= nil, `élément {path}`)
end
check(paths.CloseButton == "GuiButton" and paths.ConfirmButton == "GuiButton", "CloseButton et ConfirmButton : des boutons")
local reserved = {}
for _, name in UI.ReservedNames do
	reserved[name] = true
end
local clash = {}
for path in paths do
	for segment in string.gmatch(path, "[^%.]+") do
		if reserved[segment] then
			table.insert(clash, segment)
		end
	end
end
check(#clash == 0, `aucun nom qui est une propriété Roblox ({table.concat(clash, ", ")})`)

section("ContractChecker : comptoirs sans plaque")
run()
local text, kind = summaryLine()
for _, name in { "ENV_Hub_WeaponStall", "ENV_Hub_AuraStall", "ENV_Hub_RobuxStall" } do
	check(lineWith(`[Contrat] Boutiques d'achat · Workspace.Map.Hub.Stalls.{name}.ShopPad introuvable {NOTE}`, "WARN"), `{name} sans ShopPad : avertissement (orange)`)
end
check(not lineWith("blocs de greybox", nil), "pas pris pour des blocs de greybox")
check(kind == "PRINT" and string.find(text, "[Contrat] Contrat : OK · 3 avertissement(s)", 1, true) == 1, `pas des problèmes : « {text} »`)
check(not lineWith("UI · UI_Rebirth", nil), "UI_Rebirth conforme (relevé de Studio) : rien à dire")
if kind ~= "PRINT" then
	shout()
end

section("ContractChecker : plaques posées")
local pads = {}
for index, model in { weapon, aura, robux } do
	local pivot = ({ WEAPON_PIVOT, AURA_PIVOT, ROBUX_PIVOT })[index]
	pads[index] = makePad(model, Vector3.new(pivot.X, 0.1, pivot.Z + 6))
end
run()
text, kind = summaryLine()
check(not lineWith("Boutiques d'achat", nil), "trois ShopPad (Part) : rien à dire")
check(kind == "PRINT" and string.find(text, "[Contrat] Contrat : OK", 1, true) == 1 and not string.find(text, "avertissement", 1, true), `« {text} »`)
local nested = make("Model", { Name = "Floor" }, aura)
pads[2].Parent = nested
run()
check(not lineWith("Boutiques d'achat", nil), "ShopPad rangée dans un sous-modèle du comptoir : trouvée (Contract/Find)")
pads[2].Parent = aura
nested:Destroy()

section("ContractChecker : plaques mal livrées")
pads[1]:Destroy()
local modelPad = make("Model", { Name = "ShopPad" }, weapon)
make("Part", { Name = "Plate" }, modelPad)
pads[2].Name = "Shoppad"
make("Part", { Name = "ShopPad" }, make("Model", { Name = "Deco" }, robux)) -- une 2e plaque
run()
text, kind = summaryLine()
check(lineWith("Workspace.Map.Hub.Stalls.ENV_Hub_WeaponStall.ShopPad doit être un BasePart (trouvé : Model)", "WARN"), "ShopPad en Model : problème")
check(lineWith("Workspace.Map.Hub.Stalls.ENV_Hub_AuraStall.ShopPad introuvable (« Shoppad » trouvé : le renommer en ShopPad)", "WARN"), "« Shoppad » : problème, avec le nom exact")
check(lineWith("Workspace.Map.Hub.Stalls.ENV_Hub_RobuxStall : 2 éléments nommés ShopPad, un seul attendu", "WARN"), "deux ShopPad : problème")
check(kind == "WARN" and string.find(text, "[Contrat] Contrat : 3 problème(s)", 1, true) == 1, `« {text} »`)
if kind ~= "WARN" then
	shout()
end
modelPad:Destroy()
pads[2].Name = "ShopPad"
robux.Deco:Destroy()
makePad(weapon, Vector3.new(WEAPON_PIVOT.X, 0.1, WEAPON_PIVOT.Z + 6))

section("ContractChecker : UI_Rebirth mal livré")
local hint = rebirthEl(rebirth, "Hint")
hint.Parent = nil
local fill = rebirthEl(rebirth, "CashBar.Fill")
fill.Name = "Filling"
local confirm = rebirthEl(rebirth, "ConfirmButton")
local frame = make("Frame", { Name = "ConfirmButton" }, confirm.Parent)
for _, child in confirm:GetChildren() do
	child.Parent = frame
end
confirm:Destroy()
local extraLevel = make("TextLabel", { Name = "Level", Text = "?" }, rebirth.Root)
run()
text, kind = summaryLine()
check(lineWith("[Contrat] UI · UI_Rebirth.Hint introuvable", "WARN"), "Hint absent : problème")
check(lineWith("UI_Rebirth.CashRequirement.CashBar.Fill introuvable", "WARN"), "CashBar.Fill renommé : problème")
check(lineWith("UI_Rebirth.ConfirmButton doit être un bouton (TextButton ou ImageButton) (trouvé : Frame)", "WARN"), "ConfirmButton en Frame : problème")
check(lineWith("UI_Rebirth.Level : 2 éléments portent ce nom", "WARN"), "deux Level : problème")
check(kind == "WARN" and string.find(text, "[Contrat] Contrat : 4 problème(s)", 1, true) == 1, `« {text} »`)
if kind ~= "WARN" then
	shout()
end
extraLevel:Destroy()

section("ContractChecker : UI_Rebirth absent")
rebirth:Destroy()
run()
text, kind = summaryLine()
check(lineWith("[Contrat] UI · UI_Rebirth absent : écran pas encore livré", "PRINT"), "UI_Rebirth absent : « pas encore livré »")
check(kind == "PRINT" and string.find(text, "Contrat : OK", 1, true) ~= nil, `« {text} »`)

summary("scénario contract")
