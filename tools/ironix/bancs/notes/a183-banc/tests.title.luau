--!nocheck
---------------------------------------------------------------- a183, scénario « title » : RebirthTitleController
local TITLE_MODULE = moduleScript(CONTROLLERS, "RebirthTitleController", "client/Controllers/RebirthTitleController.luau")
local RebirthsC = requireModule(ReplicatedStorage.Shared.Config.Rebirths, "client")
local uiAssets = ReplicatedStorage.Assets.UI
local function newCharacter(name, withHead)
	local character = new("Model", { Name = name })
	if withHead then
		new("Part", { Name = "Head" }, character)
	end
	character.Parent = Workspace
	return character
end
local function titles(character)
	local list = {}
	local head = character:FindFirstChild("Head")
	for _, child in if head then head:GetChildren() else {} do
		if child.Name == "BB_RebirthTitle" then
			table.insert(list, child)
		end
	end
	return list
end
local function textOf(character)
	local list = titles(character)
	return if #list == 1 then list[1].TitleLabel.Text else `{#list} billboard(s)`
end
new("Part", { Name = "Head" }, P1.Character)
local P2 = new("Player", { Name = "Bob", UserId = 102, DisplayName = "Bob" })
local char2 = newCharacter("Bob", true)
P2.Character = char2
P2.Parent = Players
P2:SetAttribute("Rebirths", 3)

section("T1. Billboard pas encore livré : rien, une ligne en Studio")
check(RebirthsC.Title.Billboard == "BB_RebirthTitle" and RebirthsC.Title.Label == "TitleLabel" and RebirthsC.Title.FromLevel == 1, "T1a Config/Rebirths.Title : BB_RebirthTitle, TitleLabel, dès la 1re")
local TITLE = requireModule(TITLE_MODULE, "client")
taskLib.spawn(TITLE.Start)
step(0.1)
check(#titles(char2) == 0 and #titles(P1.Character) == 0, "T1b aucun titre posé")
check(logHas("[RebirthTitle] BB_RebirthTitle absent de ReplicatedStorage.Assets.UI"), "T1c une ligne dans la sortie")
check(not logHas("attempt to"), "T1d aucune erreur")

section("T2. Billboard livré : REBIRTH n sur la tête")
local model = new("BillboardGui", { Name = "BB_RebirthTitle", StudsOffset = Vector3.new(0, 2.5, 0), Enabled = false }, uiAssets)
new("TextLabel", { Name = "TitleLabel", Text = "REBIRTH 1" }, model)
P2:SetAttribute("Rebirths", 4)
step(0.1)
local posed = titles(char2)[1]
check(textOf(char2) == "REBIRTH 4", `T2a Bob, 4 renaissances : « REBIRTH 4 » ({textOf(char2)})`)
check(posed and posed.Adornee == char2.Head and posed.Enabled == true and posed.StudsOffset == Vector3.new(0, 2.5, 0), "T2b Adornee = Head, allumé, StudsOffset de Clément gardé")
check(model.TitleLabel.Text == "REBIRTH 1" and model.Enabled == false and model.Parent == uiAssets, "T2c le modèle de Clément n'est pas touché")
P2:SetAttribute("Rebirths", 5)
step(0.1)
check(textOf(char2) == "REBIRTH 5" and titles(char2)[1] == posed, "T2d 5 renaissances : même billboard, texte mis à jour")
check(#titles(P1.Character) == 0, "T2e le joueur local, sans attribut : pas de titre")
P1:SetAttribute("Rebirths", 1)
step(0.1)
check(textOf(P1.Character) == "REBIRTH 1", "T2f le joueur local, 1 renaissance : « REBIRTH 1 »")

section("T3. Sous le palier ou renaissance coupée : titre retiré")
P1:SetAttribute("Rebirths", 0)
step(0.1)
check(#titles(P1.Character) == 0, "T3a 0 renaissance : titre retiré")
P2:SetAttribute("Rebirths", nil)
step(0.1)
check(#titles(char2) == 0, "T3b attribut retiré (renaissance coupée) : titre retiré")
P2:SetAttribute("Rebirths", "7")
step(0.1)
check(#titles(char2) == 0, "T3c attribut illisible : pas de titre")

section("T4. Nouveau personnage, tête en retard, joueur arrivé après")
P2:SetAttribute("Rebirths", 2)
step(0.1)
local char3 = newCharacter("Bob", true)
P2.Character = char3
P2.CharacterAdded:Fire(char3)
step(0.1)
check(textOf(char3) == "REBIRTH 2", `T4a nouveau personnage : titre reposé ({textOf(char3)})`)
local char4 = newCharacter("Bob", false)
P2.Character = char4
P2.CharacterAdded:Fire(char4)
step(0.2)
new("Part", { Name = "Head" }, char4)
step(0.3)
check(textOf(char4) == "REBIRTH 2", `T4b tête arrivée après le personnage : titre posé ({textOf(char4)})`)
local P3 = new("Player", { Name = "Cy", UserId = 103, DisplayName = "Cy" })
local char5 = newCharacter("Cy", true)
P3.Character = char5
P3:SetAttribute("Rebirths", 12)
P3.Parent = Players
step(0.1)
if #titles(char5) == 0 then
	Players.PlayerAdded:Fire(P3) -- faux Roblox sans PlayerAdded automatique
	step(0.1)
end
check(textOf(char5) == "REBIRTH 12", `T4c joueur arrivé après : « REBIRTH 12 » ({textOf(char5)})`)
check(not logHas("attempt to"), "T4d aucune erreur dans la sortie")

summary()
