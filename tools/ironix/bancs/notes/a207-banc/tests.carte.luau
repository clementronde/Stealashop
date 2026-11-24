--!nocheck
-- Scénario « carte » (a207, vague 63) : carte « ITEM SECURED! » (UI_Escape.Card) de CatchSceneController ; Rarity et
-- ItemName passent par Controllers/UI/RarityFx (dégradé fixe, reflet, arc-en-ciel selon la rareté). Mise en place
-- du banc a192 (scénario client, a42 copie a71), copiée de a192-banc/tests.client.luau (lignes 5 à 37).
--     mort au milieu ; deux captures d'affilée) ; K carte « ITEM SECURED! » avec et sans « NEW! ».
buildFeelAssets()
local Feel = sharedModule("Config/HeistFeel", "client")
local IndexCfg = sharedModule("Config/Index", "client")
local ItemsCfg = sharedModule("Config/Items", "client")
local item = nil
for _, def in ItemsCfg.List do
	if def.Zone ~= nil and item == nil then
		item = def
	end
end
local alice = newPlayer("Alice")
spawnCharacter(alice, Vector3.new(zoneMiddle(1), 3, 0))
make("TextLabel", { Name = "HeistHint", Text = "NOBODY SAW YOU... YET", Visible = false }, STARTER_CHASE)
copyScreen(alice, STARTER_CHASE)
local hud = make("ScreenGui", { Name = "UI_HUD" }, alice.PlayerGui)
local rail = make("Frame", { Name = "LeftRail", Visible = true }, hud)
local cashLabel = make("TextLabel", { Name = "Cash", Text = "$100", Visible = true }, hud)
local timer = make("TextLabel", { Name = "HeistTimer", Text = "HEIST: 6s", Visible = true }, hud)
local bottom = make("Frame", { Name = "BottomRow", Visible = true }, hud)
local drop = make("TextButton", { Name = "DropButton", Visible = true }, bottom)
local other = make("TextButton", { Name = "OtherButton", Visible = true }, bottom)
local hotbar = make("ScreenGui", { Name = "UI_Hotbar", Enabled = true }, alice.PlayerGui)
local notify = make("ScreenGui", { Name = "UI_Notify", Enabled = true }, alice.PlayerGui)
local shop = make("ScreenGui", { Name = "UI_WeaponShop", Enabled = false }, alice.PlayerGui)
Workspace.CurrentCamera = CAMERA
CAMERA.CameraType = "Enum.CameraType.Custom"
startClient(alice)
local Heist = clientModule("HeistController")
local Scene = clientModule("CatchSceneController")
local guard = buildGuard(alice, zoneMiddle(1) + 20)
local chaseGui = alice.PlayerGui:FindFirstChild("UI_Chase")

local RarityFx = requireModule(CONTROLLERS.UI.RarityFx, "client")
local Rarities = sharedModule("Config/Rarities", "client")
local function firstOf(rarity)
	for _, def in ItemsCfg.List do
		if def.Rarity == rarity then
			return def
		end
	end
	return nil
end

section("carte : nom et rareté avec RarityFx")
local escape = make("ScreenGui", { Name = "UI_Escape", Enabled = false }, alice.PlayerGui)
local card = make("Frame", { Name = "Card" }, escape)
local cName = make("TextLabel", { Name = "ItemName", Text = "", TextColor3 = Color3.fromHex("ffcc00") }, card)
local cRarity = make("TextLabel", { Name = "Rarity", Text = "", TextColor3 = Color3.fromHex("ffcc00") }, card)
make("TextLabel", { Name = "Income", Text = "" }, card)
make("TextLabel", { Name = "NewBadge", Text = "NEW!", Visible = false }, card)
make("ImageLabel", { Name = "ItemIcon" }, card)
local tried = 0
for _, rarity in { "Common", "Legendary", "Secret" } do
	local def = firstOf(rarity)
	if def then
		tried += 1
		local want = RarityFx.KindOf(rarity)
		serverFire("ItemSecured", alice, def.Id)
		advance(0.1)
		check(cName.Text == def.DisplayName and cRarity.Text == Rarities.ById[rarity].DisplayNameUpper, `{rarity} : « {cName.Text} », « {cRarity.Text} »`)
		check(want ~= nil and RarityFx.GetKind(cName) == want and RarityFx.GetKind(cRarity) == want, `{rarity} : ItemName et Rarity en {tostring(want)} ({tostring(RarityFx.GetKind(cName))}, {tostring(RarityFx.GetKind(cRarity))})`)
		local gName, gRarity = cName:FindFirstChild("RarityGradient"), cRarity:FindFirstChild("RarityGradient")
		check(gName ~= nil and gName.ClassName == "UIGradient" and gName.Enabled == true and gRarity ~= nil and gRarity.Enabled == true, `{rarity} : un UIGradient RarityGradient sur chaque texte`)
		check(cName.TextColor3 == Color3.new(1, 1, 1) and cRarity.TextColor3 == Color3.new(1, 1, 1), `{rarity} : textes en blanc (le dégradé porte la couleur)`)
	end
end
check(tried >= 2, `au moins deux raretés essayées ({tried})`)
local count = 0
for _, child in cName:GetChildren() do
	if child.ClassName == "UIGradient" then
		count += 1
	end
end
check(count == 1, `une carte après l'autre : un seul dégradé sur ItemName ({count})`)
check(not logHas("[CatchScene]", "WARN", "client"), "CatchScene : aucun avertissement")
summary("scénario carte")
