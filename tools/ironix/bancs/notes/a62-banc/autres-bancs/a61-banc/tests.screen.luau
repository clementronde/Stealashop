--!nocheck
-- Scénario « screen » (L-079, L-091 point 6) : l'écran UI_Inventory. Barre Roblox coupée au démarrage ;
-- écran fermé jusqu'au bouton InventoryButton du HUD ; un seul écran du groupe Menu (UI_Other se ferme) ;
-- onglets Items, Boxes, Tools, Potions (Selected et section visibles), Items au départ puis le dernier
-- choisi ; Potions vide sans erreur ; CloseButton, 2e appui du bouton ; cartes retirées à la fermeture ;
-- ScrollTrack suit la liste ; contrat UI : chaque nom lu par le code existe une seule fois dans le relevé.

advance(1000)
startServer()
local data = newProfile()
addItem(data, "a", "Z1_Banane", nil, 1, 1)
addItem(data, "b", "Z3_Smartphone", 1, 3, 2)
local ada = join("Ada", data)
advance(1.5)
buildInventoryUi(ada)
startClient(ada)
advance(0.5)
local Inventory = clientModule("InventoryController")
local Motion = requireModule(CONTROLLERS:FindFirstChild("UI"):FindFirstChild("Motion"), "client")

section("démarrage")
check(not logHas("[Loader", "WARN"), "aucun module en échec au chargement")
check(#COREGUI_CALLS >= 1 and COREGUI_CALLS[1].kind == "Enum.CoreGuiType.Backpack" and COREGUI_CALLS[1].enabled == false, "barre d'outils de Roblox coupée au démarrage")
check(not INV.screen.Enabled and not Inventory.GetState().Open, "UI_Inventory fermé (copie de StarterGui arrivée allumée)")
check(not INV.templates.Items.Visible and not INV.templates.Boxes.Visible and not INV.templates.Tools.Visible, "les Template restent cachés")
check(INV.sections.Items.cards:FindFirstChild("Preview_1") == nil, "carte d'exemple Preview_1 retirée")
check(INV.other.Enabled, "UI_Other allumé (autre écran du groupe Menu)")

section("ouverture par InventoryButton")
click(INV.invButton)
check(INV.screen.Enabled and Inventory.GetState().Open and Motion.GetState(INV.screen) == "Open", "écran ouvert (Motion)")
check(not INV.other.Enabled, "un seul écran du groupe Menu : UI_Other fermé")
check(Inventory.GetState().Tab == "Items" and shown(INV.sections.Items.frame) and not shown(INV.sections.Boxes.frame) and not shown(INV.sections.Tools.frame) and not shown(INV.sections.Potions.frame), "Items au départ : seule ItemsSection visible")
check(shown(INV.tabs.Items.selected) and not shown(INV.tabs.Boxes.selected) and not shown(INV.tabs.Tools.selected) and not shown(INV.tabs.Potions.selected), "Selected sur ItemsTab seulement")
local _, n = cardsOf("Items")
check(n == 2 and countLabel("Items") == "2", `2 cartes d'objets, CountLabel « 2 » ({n}, {countLabel("Items")})`)
check(INV.counter.Text == "1 / 30 items" and INV.displays.Text == "1 / 4 displays", `Counter et Displays ({INV.counter.Text} ; {INV.displays.Text})`)

section("onglets")
click(INV.tabs.Boxes.button)
check(Inventory.GetState().Tab == "Boxes" and shown(INV.sections.Boxes.frame) and not shown(INV.sections.Items.frame), "BoxesTab : BoxesSection seule visible")
check(shown(INV.tabs.Boxes.selected) and not shown(INV.tabs.Items.selected), "Selected suit l'onglet")
check(countLabel("Boxes") == "0", "aucun colis : CountLabel « 0 »")
click(INV.tabs.Tools.button)
check(shown(INV.sections.Tools.frame) and shown(INV.tabs.Tools.selected) and not shown(INV.sections.Boxes.frame), "ToolsTab : ToolsSection")
local tools, tn = cardsOf("Tools")
check(tn == 2 and tools.Tool_Fists ~= nil and tools.Tool_Bat ~= nil and countLabel("Tools") == "2", "outils : les poings et la batte")
clearLog()
click(INV.tabs.Potions.button)
local _, pn = cardsOf("Potions")
check(shown(INV.sections.Potions.frame) and shown(INV.tabs.Potions.selected) and pn == 0, "PotionsTab : section visible et vide")
check(not logHas("", "WARN"), "Potions : aucune erreur")
INV.list.CanvasPosition = Vector2.new(0, 120)
click(INV.tabs.Items.button)
check(INV.list.CanvasPosition.Y == 0, "changer d'onglet remonte la liste")

section("fermeture, réouverture sur le dernier onglet")
click(INV.tabs.Potions.button)
click(INV.close)
check(not INV.screen.Enabled and not Inventory.GetState().Open, "CloseButton : fermé")
local _, left = cardsOf("Items")
check(left == 0, "cartes retirées une fois l'écran éteint")
click(INV.invButton)
check(INV.screen.Enabled and Inventory.GetState().Tab == "Potions" and shown(INV.sections.Potions.frame), "rouvert sur le dernier onglet (Potions)")
click(INV.invButton)
check(not INV.screen.Enabled, "2e appui sur InventoryButton : fermé")
-- Un autre écran du groupe s'ouvre : l'inventaire est fermé par son contrôleur.
click(INV.invButton)
Motion.Open(INV.other)
flush()
check(INV.other.Enabled and not INV.screen.Enabled and not Inventory.GetState().Open, "UI_Other ouvert : l'inventaire se ferme (Motion.SetCloser)")

section("ScrollTrack suit la liste")
click(INV.invButton)
click(INV.tabs.Items.button)
INV.list.AbsoluteCanvasSize = Vector2.new(400, 1200) -- 300 visibles sur 1 200
INV.list.CanvasPosition = Vector2.new(0, 450) -- à mi-course (900 à défiler)
flush()
check(near(INV.track.Size.Y.Scale, 0.8 * 0.25, 1e-6) and INV.track.Size.X.Offset == 6, `hauteur = part visible de la piste ({INV.track.Size})`)
check(near(INV.track.Position.Y.Scale, 0.1 + 0.8 * 0.75 * 0.5, 1e-6) and INV.track.Position.X.Scale == 1 and INV.track.Position.X.Offset == -8, `place = mi-course ({INV.track.Position})`)
INV.list.AbsoluteCanvasSize = Vector2.new(400, 200) -- rien à défiler
flush()
check(near(INV.track.Size.Y.Scale, 0.8, 1e-6) and near(INV.track.Position.Y.Scale, 0.1, 1e-6), "rien à défiler : le curseur remplit la piste")

section("API : SelectTab, Toggle")
Inventory.SelectTab("Boxes")
check(Inventory.GetState().Tab == "Boxes" and shown(INV.sections.Boxes.frame), "SelectTab(\"Boxes\")")
Inventory.SelectTab("Nope")
check(Inventory.GetState().Tab == "Boxes", "onglet inconnu : ignoré")
Inventory.Toggle()
flush()
check(not INV.screen.Enabled, "Toggle : fermé")

section("écran recréé (ResetOnSpawn) : rebranché, fermé")
local old = INV.screen
old:Destroy()
buildInventoryUi(ada)
flush()
check(not INV.screen.Enabled, "nouvel écran fermé")
click(INV.invButton)
check(INV.screen.Enabled and Inventory.GetState().Open, "le bouton du nouveau HUD ouvre le nouvel écran")
local _, fresh = cardsOf("Items")
check(fresh == 2, "cartes dans le nouvel écran")

section("contrat UI : UI_Inventory et InventoryButton")
local function screenSpec(name)
	for _, s in UIContract.Screens do
		if s.Name == name then
			return s
		end
	end
	return nil
end
local function checkSpec(spec, gui)
	local missing, dup, badClass, shownTemplate = {}, {}, {}, {}
	for _, element in spec.Elements do
		local current = gui
		for segment in string.gmatch(element.Path, "[^%.]+") do
			local matches = Find.all(current, segment)
			if #matches == 0 then
				table.insert(missing, element.Path)
				current = nil
				break
			elseif #matches > 1 then
				table.insert(dup, element.Path)
			end
			current = matches[1]
		end
		if current then
			if element.Class and not current:IsA(element.Class) then
				table.insert(badClass, element.Path)
			end
			if element.Template and current.Visible then
				table.insert(shownTemplate, element.Path)
			end
		end
	end
	return missing, dup, badClass, shownTemplate
end
local spec = screenSpec("UI_Inventory")
check(spec ~= nil and spec.Class == "ScreenGui" and #spec.Elements == 58, `UI_Inventory au contrat : 58 éléments (7, 8 d'onglets, 16 + 15 + 12 des sections) ({spec and #spec.Elements})`)
-- Le relevé de Studio (écran neuf, pas encore branché) : copie de buildInventoryUi sans client.
local probe = make("Folder", { Name = "Probe" }, nil)
local savedInv = INV
local fakeOwner = { FindFirstChild = function() return probe end }
buildInventoryUi(fakeOwner)
local survey = INV
INV = savedInv
local missing, dup, badClass, shownTemplate = checkSpec(spec, survey.screen)
check(#missing == 0, `tout nom lu existe dans le relevé (manquants : {table.concat(missing, ", ")})`)
check(#dup == 0, `aucun nom en double (2.2) : {table.concat(dup, ", ")}`)
check(#badClass == 0 and #shownTemplate == 0, `classes et Template cachés : {table.concat(badClass, ", ")} {table.concat(shownTemplate, ", ")}`)
local hudSpec = screenSpec("UI_HUD")
local hasButton = false
for _, element in hudSpec.Elements do
	if element.Path == "InventoryButton" and element.Class == "GuiButton" then
		hasButton = true
	end
end
check(hasButton and Find.path(survey.hud, "InventoryButton") ~= nil, "UI_HUD.InventoryButton au contrat (bouton)")
local reserved = {}
for _, d in survey.screen:GetDescendants() do
	if table.find(UIContract.ReservedNames, d.Name) then
		table.insert(reserved, d.Name)
	end
end
check(#reserved == 0, "aucun nom réservé (Name, Text, Size…) dans l'écran")

summary("scénario screen")
