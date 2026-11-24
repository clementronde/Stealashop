--!nocheck
-- Banc a170, scénario « contract » (lu après setup.luau du banc a39, copie a95) : les restes du colis porté dans un
-- arbre de Studio d'aujourd'hui sont des notes du vrai ContractChecker, jamais des problèmes.

local UI = sharedModule("Contract/UI", "server")
local Animations = sharedModule("Contract/Animations", "server")
local MarkerSounds = sharedModule("Anim/MarkerSounds", "server")
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
local function warnsWith(word)
	local out = {}
	for _, line in LOG do
		if line.side == "server" and line.kind == "WARN" and string.find(line.text, word, 1, true) then
			table.insert(out, line.text)
		end
	end
	return out
end
local function shout()
	for _, line in LOG do
		if line.side == "server" and line.kind == "WARN" then
			print("    " .. line.text)
		end
	end
end
local function contractOk(label)
	local text, kind = summaryLine()
	check(kind == "PRINT" and string.find(text, "Contrat : OK", 1, true) ~= nil, `{label} : « {text} »`)
	if kind ~= "PRINT" then
		shout()
	end
end

section("Contract : listes")
local inventoryBoxes = {}
for _, screen in UI.Screens do
	check(screen.Name ~= "UI_Unbox", `{screen.Name} : pas UI_Unbox`)
	if screen.Name == "UI_Inventory" then
		for _, element in screen.Elements do
			if string.find(element.Path, "Boxes", 1, true) then
				table.insert(inventoryBoxes, element.Path)
			end
		end
	end
end
check(#inventoryBoxes == 0, `UI_Inventory sans élément Boxes ({inventoryBoxes[1] or ""})`)
local kept = {}
for _, board in UI.Billboards do
	kept[board.Name] = true
end
check(kept.BB_OpenTimer == nil, "BB_OpenTimer plus dans UI.Billboards")
for _, name in { "BB_Box", "BB_Carry", "BB_Item" } do -- BB_AntiTheft : pas au contrat (repli V0 du code)
	check(kept[name] == true, `{name} gardé au contrat`)
end
local anims = {}
for _, spec in Animations.Player do
	anims[spec.Name] = true
end
check(anims.Unbox == nil and anims.Celebrate == nil, "Unbox et Celebrate plus dans Animations.Player")
check(anims.Place == true and anims.Grab == true and anims.CarryIdle == true and anims.CarryRun == true, "Place, Grab, CarryIdle, CarryRun gardés")
check(Animations.Retired.Unbox ~= nil and Animations.Retired.Celebrate ~= nil, "Unbox et Celebrate dans Animations.Retired")
local unboxMarker = false
for _, entry in MarkerSounds.Player do
	if entry.Anim == "Unbox" then
		unboxMarker = true
	end
end
check(not unboxMarker, "MarkerSounds.Player sans Unbox/Open")
check(UI.Retired ~= nil and UI.Retired.Screens.UI_Unbox ~= nil and UI.Retired.Billboards.BB_OpenTimer ~= nil, "UI.Retired : UI_Unbox et BB_OpenTimer")

section("ContractChecker : la place du banc a39, sans les restes")
run()
contractOk("départ")

-- Restes d'aujourd'hui chez Clément : l'écran UI_Unbox, BB_OpenTimer, les animations Unbox et Celebrate.
local unbox = make("ScreenGui", { Name = "UI_Unbox", Enabled = false }, StarterGui)
make("TextLabel", { Name = "Rarity", Text = "" }, unbox)
make("TextButton", { Name = "ContinueButton", Text = "" }, unbox)
local uiFolder = ASSETS:FindFirstChild("UI") or folder(ASSETS, "UI")
local timer = make("BillboardGui", { Name = "BB_OpenTimer" }, uiFolder)
make("TextLabel", { Name = "Label", Text = "" }, timer)
local animFolder = ASSETS:FindFirstChild("Animations") or folder(ASSETS, "Animations")
local playerFolder = animFolder:FindFirstChild("Player") or folder(animFolder, "Player")
make("Animation", { Name = "Unbox", AnimationId = "rbxassetid://1" }, playerFolder)
make("Animation", { Name = "Celebrate", AnimationId = "rbxassetid://2" }, playerFolder)

section("ContractChecker : restes d'aujourd'hui")
run()
check(logHas("StarterGui.UI_Unbox : colis porté et ouvert en base retirés", "PRINT", "server"), "UI_Unbox : une note « peut être retiré »")
check(logHas("BB_OpenTimer : colis porté et ouvert en base retirés", "PRINT", "server"), "BB_OpenTimer : une note")
check(logHas("Player.Unbox : ouverture des colis en base retirée", "PRINT", "server"), "animation Unbox : une note")
check(logHas("Player.Celebrate : ouverture des colis en base retirée", "PRINT", "server"), "animation Celebrate : une note")
for _, word in { "Unbox", "OpenTimer", "Celebrate" } do
	local warns = warnsWith(word)
	check(#warns == 0, `aucun problème ni avertissement sur {word} ({warns[1] or ""})`)
end
contractOk("avec les restes")

section("ContractChecker : onglet et section des colis dans UI_Inventory")
local inventory = make("ScreenGui", { Name = "UI_Inventory", Enabled = false }, StarterGui)
local tabs = make("Frame", { Name = "Tabs" }, inventory)
make("TextButton", { Name = "BoxesTab", Text = "" }, tabs)
local list = make("ScrollingFrame", { Name = "List" }, inventory)
make("Frame", { Name = "BoxesSection" }, list)
run()
check(logHas("StarterGui.UI_Inventory.Tabs.BoxesTab : colis porté", "PRINT", "server"), "BoxesTab : une note")
check(logHas("StarterGui.UI_Inventory.BoxesSection : colis porté", "PRINT", "server"), "BoxesSection : une note")
local warns = warnsWith("Boxes")
check(#warns == 0, `aucun problème sur BoxesTab ou BoxesSection ({warns[1] or ""})`)
inventory:Destroy()

section("ContractChecker : restes retirés par Clément")
unbox:Destroy()
timer:Destroy()
for _, name in { "Unbox", "Celebrate" } do
	local anim = playerFolder:FindFirstChild(name)
	if anim then
		anim:Destroy()
	end
end
run()
check(not logHas("colis porté et ouvert en base retirés", nil, "server"), "plus aucune note des restes d'UI")
check(not logHas("ouverture des colis en base retirée", nil, "server"), "plus aucune note des animations retirées")
contractOk("restes retirés")

summary("scénario contract")
