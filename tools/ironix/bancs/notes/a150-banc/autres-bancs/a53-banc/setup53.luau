--!nocheck
-- Mise en place du banc a53 (DEV-101, récompenses quotidiennes et de temps de jeu), après celle d'a51
-- (setup51.luau, copie telle quelle : hub, zone safe, 6 boutiques, colis dans l'inventaire) :
--   - vrai RewardService (serveur) ; vrais RewardsController et Controllers/UI/Motion (client) ;
--   - TelemetryService du banc : LogEconomy noté dans TELEMETRY, LogEvent noté dans EVENTS ;
--   - écrans du relevé de Studio de Clément (UI_HUD.SocialRow.RewardsButton, UI_Rewards) faits par
--     buildUi(player) dans son PlayerGui, avant startClient.

SOURCES["stub/TelemetryService"] = [==[
local TelemetryService = { Priority = 210 }
function TelemetryService.LogEconomy(player, kind, amount, sku, fields)
	table.insert(TELEMETRY, { player = player, kind = kind, amount = amount, sku = sku, t = os.clock(), cash = player:GetAttribute("Cash") })
	return true
end
function TelemetryService.LogEvent(player, key, fields, value)
	table.insert(EVENTS, { player = player, key = key, fields = fields or {}, value = value, t = os.clock() })
	return true
end
return TelemetryService
]==]
EVENTS = {}

moduleScript(SERVICES, "RewardService", "server/Services/RewardService.luau")
moduleScript(CONTROLLERS, "RewardsController", "client/Controllers/RewardsController.luau")
moduleScript(folder(CONTROLLERS, "UI"), "Motion", "client/Controllers/UI/Motion.luau")

local baseStartServer = startServer
function startServer()
	baseStartServer()
	RewardService = serverModule("RewardService")
	Rewards = sharedModule("Config/Rewards")
	Mutations = sharedModule("Config/Mutations")
end

DAY = 86400

-- Avance l'horloge des récompenses de n jours (le crochet Studio du service, comme la recette Play).
function days(n)
	Workspace:SetAttribute("RewardTest", `days {n}`)
	flush()
	advance(0.1)
end
function addPlay(player, seconds)
	Workspace:SetAttribute("RewardTest", `play {player.Name} {seconds}`)
	flush()
	advance(0.1)
end
function claimDaily(player)
	advance(0.6) -- ClaimDaily : 2 appels par seconde au plus (Net)
	fireAs(player, "ClaimDaily")
	flush()
end
function claimPlay(player, minutes)
	advance(1.05) -- ClaimPlaytime : 4 appels par seconde au plus (seconde glissante)
	fireAs(player, "ClaimPlaytime", minutes)
	flush()
end
function stateOf(player)
	return RewardService.GetState(player)
end
function telemetryOf(player, kind)
	local out = {}
	for _, e in TELEMETRY do
		if e.player == player and (kind == nil or e.kind == kind) then
			table.insert(out, e)
		end
	end
	return out
end
function eventsOf(player, key)
	local out = {}
	for _, e in EVENTS do
		if e.player == player and (key == nil or e.key == key) then
			table.insert(out, e)
		end
	end
	return out
end
-- Colis de l'inventaire (Spot absent) du profil, comptés.
function storedBoxes(player)
	local n, list = 0, {}
	for uid, box in dataOf(player).Boxes do
		if type(box) == "table" and box.Spot == nil then
			n += 1
			list[uid] = box
		end
	end
	return n, list
end
-- Profil v8 neuf (newProfile d'a51 en v6, mis en v8 ici : Boxes par uid, sans BoxQueue, Rewards).
function newProfile8()
	local data = newProfile(6)
	data.Version = 8
	data.BoxQueue = nil
	data.Rewards = { Daily = { Streak = 0, LastDay = 0 }, Playtime = { Day = 0, Seconds = 0, Claimed = {} } }
	return data
end

---------------------------------------------------------------- écrans de Clément (relevé du 2026-11-09)
UI = {}
function buildUi(player)
	local gui = player:FindFirstChild("PlayerGui")
	local hud = make("ScreenGui", { Name = "UI_HUD" }, gui)
	local social = make("Frame", { Name = "SocialRow" }, hud)
	make("TextButton", { Name = "InviteButton" }, social)
	local button = make("TextButton", { Name = "RewardsButton", Text = "" }, social)
	make("ImageLabel", { Name = "RewardsIcon" }, button)
	make("TextLabel", { Name = "RewardsLabel", Text = "Rewards" }, button)
	local alert = make("Frame", { Name = "RewardsAlert", Visible = false }, button)

	local screen = make("ScreenGui", { Name = "UI_Rewards", Enabled = false }, nil)
	screen:SetAttribute("ScreenGroup", "Menu")
	local root = make("Frame", { Name = "Root" }, screen)
	make("Frame", { Name = "WindowShadow" }, root)
	local window = make("Frame", { Name = "Window" }, root)
	local header = make("Frame", { Name = "Header" }, window)
	make("TextLabel", { Name = "Title", Text = "Rewards" }, header)
	local close = make("TextButton", { Name = "CloseButton" }, header)
	make("TextLabel", { Name = "XLabel", Text = "X" }, close)
	local dailyPage = make("Frame", { Name = "DailyPage" }, window)
	local streak = make("Frame", { Name = "Streak" }, dailyPage)
	local names = { "5 min of income", "Standard Box", "15 min of income", "Premium Box", "x2 Cash 15 min", "30 min of income", "Luxe Box" }
	local dayFrames = {}
	for d = 1, 7 do
		local f = make("Frame", { Name = `Day{d}` }, streak)
		make("Frame", { Name = "DayShadow" }, f)
		make("ImageLabel", { Name = "Glow" }, f)
		make("TextLabel", { Name = "DayLabel", Text = `Day {d}` }, f)
		make("ImageLabel", { Name = "Icon", Image = `rbxassetid://{500 + d}` }, f)
		make("TextLabel", { Name = "RewardName", Text = names[d] }, f)
		local today = make("Frame", { Name = "Today", Visible = d == 1 }, f) -- maquette : Today sur Day1
		local tag = make("Frame", { Name = "TodayTag" }, today)
		make("TextLabel", { Name = "TodayLabel", Text = "TODAY" }, tag)
		local claimed = make("Frame", { Name = "Claimed", Visible = false }, f)
		make("ImageLabel", { Name = "CheckIcon" }, claimed)
		dayFrames[d] = { frame = f, today = today, claimed = claimed }
	end
	local claimButton = make("TextButton", { Name = "DailyClaimButton", Text = "" }, dailyPage)
	make("Frame", { Name = "Studs" }, claimButton)
	local claimLabel = make("TextLabel", { Name = "ClaimLabel", Text = "CLAIM" }, claimButton)
	local playPage = make("Frame", { Name = "PlaytimePage", Visible = false }, window)
	local list = make("ScrollingFrame", { Name = "List" }, playPage)
	make("UIListLayout", { Name = "UIListLayout" }, list)
	local function row(name, visible, rewardText, image)
		local f = make("Frame", { Name = name, Visible = visible }, list)
		make("ImageLabel", { Name = "Icon", Image = image }, f)
		make("TextLabel", { Name = "RewardName", Text = rewardText }, f)
		make("TextLabel", { Name = "Timer", Text = "Ready!" }, f)
		local cb = make("TextButton", { Name = "ClaimButton", Text = "" }, f)
		make("Frame", { Name = "Studs" }, cb)
		make("TextLabel", { Name = "ClaimLabel", Text = "CLAIM" }, cb)
		local claimed = make("Frame", { Name = "Claimed", Visible = false }, f)
		local content = make("Frame", { Name = "Content" }, claimed)
		make("ImageLabel", { Name = "CheckIcon" }, content)
		make("TextLabel", { Name = "ClaimedLabel", Text = "CLAIMED" }, content)
		return f
	end
	local template = row("Template", false, "Gift at 5 min", "rbxassetid://600")
	-- Exemples de Clément : Preview_1 à Preview_3 seulement (le 4e palier garde le texte et l'icône du Template).
	for n = 1, 3 do
		row(`Preview_{n}`, true, `Preview gift {n}`, `rbxassetid://{610 + n}`)
	end
	local tabs = make("Frame", { Name = "Tabs" }, root)
	local dailyTab = make("TextButton", { Name = "DailyTab", Text = "" }, tabs)
	local dailySelected = make("ImageLabel", { Name = "Selected", Visible = true }, dailyTab)
	make("ImageLabel", { Name = "TabIcon" }, dailyTab)
	make("TextLabel", { Name = "TabLabel", Text = "Daily" }, dailyTab)
	local playTab = make("TextButton", { Name = "PlaytimeTab", Text = "" }, tabs)
	local playSelected = make("ImageLabel", { Name = "Selected", Visible = false }, playTab)
	make("ImageLabel", { Name = "TabIcon" }, playTab)
	make("TextLabel", { Name = "TabLabel", Text = "Playtime" }, playTab)
	screen.Parent = gui

	UI = {
		hud = hud,
		button = button,
		alert = alert,
		screen = screen,
		close = close,
		days = dayFrames,
		claimButton = claimButton,
		claimLabel = claimLabel,
		dailyPage = dailyPage,
		playPage = playPage,
		list = list,
		template = template,
		dailyTab = dailyTab,
		playTab = playTab,
		dailySelected = dailySelected,
		playSelected = playSelected,
	}
	return UI
end
-- Ligne clonée d'un palier (Tier_<minutes>) et ses éléments.
function rowOf(minutes)
	local f = UI.list:FindFirstChild(`Tier_{minutes}`)
	if f == nil then
		return nil
	end
	return {
		frame = f,
		name = f:FindFirstChild("RewardName"),
		icon = f:FindFirstChild("Icon"),
		timer = f:FindFirstChild("Timer"),
		claimButton = f:FindFirstChild("ClaimButton"),
		claimed = f:FindFirstChild("Claimed"),
	}
end
function click(button)
	button.Activated:Fire()
	flush()
end

---------------------------------------------------------------- copie d'a61 (vague 21, L-079)
-- Plus de Tool de colis ni d'objet : l'inventaire est dans l'attribut InventoryState du Player
-- (InventoryService, texte de Shared/InventoryState) ; invOf = colis de l'inventaire (pas posés) et objets
-- non exposés, par clé « Box:<uid> » / « Item:<uid> » (comme les Tools d'avant).
function invOf(player)
	local out = {}
	local state = sharedModule("InventoryState").Decode(player:GetAttribute("InventoryState"))
	for _, box in state.Boxes do
		if not box.Placed then
			out["Box:" .. box.Uid] = box
		end
	end
	for _, item in state.Items do
		if item.Slot == nil then
			out["Item:" .. item.Uid] = item
		end
	end
	return out
end

---------------------------------------------------------------- copie d'a150 (vague 43, 2026-11-14)
-- Les récompenses « Box » donnent un objet (UnboxService.GiveItem) : uids des objets du profil, puis les
-- objets apparus depuis (liste d'entrées, avec leur uid).
function itemKeys(player)
	local keys = {}
	for uid in dataOf(player).Items do
		keys[uid] = true
	end
	return keys
end
function giftsSince(player, keys)
	local out = {}
	for uid, entry in dataOf(player).Items do
		if not keys[uid] then
			table.insert(out, { uid = uid, entry = entry })
		end
	end
	return out
end
-- Le Notify d'un objet offert : « <Rareté> Item: <nom avec mutation> ».
function giftText(entry)
	local def = Items.ById[entry.Id]
	local mutations = sharedModule("Config/Mutations")
	return `{Rarities.ById[def.Rarity].DisplayName} Item: {mutations.ItemName(def.DisplayName, entry.Mutation)}`
end
