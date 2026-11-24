--!nocheck
-- Mise en place du banc a266 (vague 80 : quêtes quotidiennes DEV-132 / UI-130, roue de la fortune DEV-141), après
-- setup51 et setup53 (hub, boutiques, vrais DataService, UnboxService, MonetizationService, RewardService...) :
--   - vrais QuestService, WheelService, Prize/Grant (serveur), QuestController, WheelController (client) ;
--   - bouchons : PotionService (AddStock noté dans POTIONS, refus si POTION_FULL), BotService (OnTheft),
--     WindowService (OnBroken), PvPService refait (OnTheftEnded garde ses écouteurs) ;
--   - écouteurs de UnboxService.OnItemStowed gardés (STOWED) pour simuler un objet rangé.

POTIONS = {}
POTION_FULL = false
SOURCES["stub/PotionService"] = [==[
local PotionService = {}
function PotionService.AddStock(player, id, count)
	if POTION_FULL then
		return false
	end
	table.insert(POTIONS, { player = player, id = id, count = count })
	return true
end
return PotionService
]==]
PVP_ENDED = {}
SOURCES["stub/PvPService"] = [==[
local PvPService = {}
function PvPService.OnTheftStarted(_fn) return function() end end
function PvPService.OnTheftEnded(fn) table.insert(PVP_ENDED, fn) return function() end end
return PvPService
]==]
BOT_THEFT = {}
SOURCES["stub/BotService"] = [==[
local BotService = {}
function BotService.OnTheft(fn) table.insert(BOT_THEFT, fn) return function() end end
return BotService
]==]
BROKEN = {}
SOURCES["stub/WindowService"] = [==[
local WindowService = {}
function WindowService.OnBroken(fn) table.insert(BROKEN, fn) return function() end end
return WindowService
]==]
moduleScript(SERVICES, "PotionService", "stub/PotionService")
moduleScript(SERVICES, "BotService", "stub/BotService")
moduleScript(SERVICES, "WindowService", "stub/WindowService")
HAS_QUESTS = SOURCES["server/Services/QuestService.luau"] ~= nil
if HAS_QUESTS then
	moduleScript(SERVICES, "QuestService", "server/Services/QuestService.luau")
	moduleScript(SERVICES, "WheelService", "server/Services/WheelService.luau")
	moduleScript(folder(SERVICES, "Prize"), "Grant", "server/Services/Prize/Grant.luau")
	moduleScript(CONTROLLERS, "QuestController", "client/Controllers/QuestController.luau")
	moduleScript(CONTROLLERS, "WheelController", "client/Controllers/WheelController.luau")
end

STOWED = {}
TRAINING = {}
local startServer51 = startServer
function startServer()
	-- UnboxService chargé avant le Loader (même cache) : ses écouteurs « objet rangé » sont gardés.
	local unbox = serverModule("UnboxService")
	local subscribe = unbox.OnItemStowed
	unbox.OnItemStowed = function(fn)
		table.insert(STOWED, fn)
		return subscribe(fn)
	end
	startServer51()
	QuestService = serverModule("QuestService")
	WheelService = serverModule("WheelService")
	Quests = sharedModule("Config/Quests")
	Wheel = sharedModule("Config/Wheel")
	TrainingService = serverModule("TrainingService")
	TrainingService.IsTraining = function(player)
		return TRAINING[player] == true
	end
end

function fireList(list, ...)
	for _, fn in list do
		fn(...)
	end
	flush()
end
function questTest(text)
	Workspace:SetAttribute("QuestTest", text)
	flush()
end
function wheelTest(text)
	Workspace:SetAttribute("WheelTest", text)
	flush()
end
-- Pose les quêtes du jour d'un joueur (ids donnés, objectifs de Config ou donnés) et republie.
function setQuests(player, ids, goals)
	local list = {}
	for i, id in ids do
		local quest = Quests.ById[id]
		table.insert(list, { Id = id, Progress = 0, Goal = (goals and goals[i]) or quest.Goal or 1000, Claimed = 0 })
	end
	dataOf(player).Quests.List = list
	advance(1.1) -- QuestService republie à chaque tick (1 s)
end
function entryOf(player, id)
	for slot, entry in dataOf(player).Quests.List do
		if entry.Id == id then
			return entry, slot
		end
	end
	return nil
end
function claimQuest(player, slot)
	advance(0.6) -- ClaimQuest : 2 appels par seconde au plus
	fireAs(player, "ClaimQuest", slot)
	flush()
end
function spin(player)
	advance(1.05) -- SpinWheel : 1 appel par seconde au plus
	fireAs(player, "SpinWheel")
	flush()
end
function wheelResults(player)
	return remotes("WheelResult", function(e)
		return e.to == player
	end)
end

-- Écrans gris proposés à Clément (noms du rapport a266) : boutons du HUD dans LeftRail et LeftRailTouch,
-- UI_Quests (List.Template), UI_Wheel (Wheel.Segment_01 à 08, Pointer, Result, SpinButton, Timer, BuySpinButton).
QUI = {}
function buildQuestUi(player)
	local gui = player:FindFirstChild("PlayerGui")
	local hud = gui:FindFirstChild("UI_HUD")
	QUI.questButtons, QUI.questAlerts, QUI.wheelButtons, QUI.wheelAlerts = {}, {}, {}, {}
	for _, railName in { "LeftRail", "LeftRailTouch" } do
		local rail = make("Frame", { Name = railName }, hud)
		local qb = make("TextButton", { Name = "QuestsButton", Text = "" }, rail)
		table.insert(QUI.questButtons, qb)
		table.insert(QUI.questAlerts, make("Frame", { Name = "QuestsAlert", Visible = false }, qb))
		local wb = make("TextButton", { Name = "WheelButton", Text = "" }, rail)
		table.insert(QUI.wheelButtons, wb)
		table.insert(QUI.wheelAlerts, make("Frame", { Name = "WheelAlert", Visible = false }, wb))
	end

	local quests = make("ScreenGui", { Name = "UI_Quests", Enabled = false }, nil)
	quests:SetAttribute("ScreenGroup", "Menu")
	local window = make("Frame", { Name = "Window" }, quests)
	QUI.questClose = make("TextButton", { Name = "CloseButton" }, window)
	local list = make("ScrollingFrame", { Name = "List" }, window)
	make("UIListLayout", { Name = "UIListLayout" }, list)
	local template = make("Frame", { Name = "Template", Visible = true }, list)
	make("TextLabel", { Name = "QuestName", Text = "Quest" }, template)
	make("TextLabel", { Name = "ProgressLabel", Text = "0/0" }, template)
	local bar = make("Frame", { Name = "Bar" }, template)
	make("Frame", { Name = "Fill", Size = UDim2.new(0.5, 0, 1, 0) }, bar)
	make("TextLabel", { Name = "RewardLabel", Text = "Reward" }, template)
	make("ImageLabel", { Name = "Icon", Image = "rbxassetid://700" }, template)
	local claim = make("TextButton", { Name = "ClaimButton", Text = "" }, template)
	make("TextLabel", { Name = "ClaimLabel", Text = "CLAIM" }, claim)
	make("Frame", { Name = "Claimed", Visible = false }, template)
	QUI.questTimer = make("TextLabel", { Name = "Timer", Text = "" }, window)
	QUI.quests, QUI.list, QUI.template = quests, list, template
	quests.Parent = gui

	local wheelGui = make("ScreenGui", { Name = "UI_Wheel", Enabled = false }, nil)
	wheelGui:SetAttribute("ScreenGroup", "Menu")
	local wwin = make("Frame", { Name = "Window" }, wheelGui)
	QUI.wheelClose = make("TextButton", { Name = "CloseButton" }, wwin)
	local wheel = make("Frame", { Name = "Wheel", Rotation = 0 }, wwin)
	QUI.segments = {}
	for i = 1, 8 do
		local seg = make("Frame", { Name = string.format("Segment_%02d", i), Rotation = 0 }, wheel)
		make("ImageLabel", { Name = "Icon", Image = "rbxassetid://800" }, seg)
		make("TextLabel", { Name = "Amount", Text = "?" }, seg)
		if i <= 4 then
			make("TextLabel", { Name = "Chance", Text = "" }, seg) -- Chance facultatif : 4 segments seulement
		end
		QUI.segments[i] = seg
	end
	make("ImageLabel", { Name = "Pointer" }, wwin)
	QUI.result = make("TextLabel", { Name = "Result", Text = "", Visible = true }, wwin)
	QUI.spinButton = make("TextButton", { Name = "SpinButton", Text = "" }, wwin)
	QUI.spinLabel = make("TextLabel", { Name = "SpinLabel", Text = "SPIN!" }, QUI.spinButton)
	QUI.wheelTimer = make("TextLabel", { Name = "Timer", Text = "" }, wwin)
	local buy = make("TextButton", { Name = "BuySpinButton", Text = "" }, wwin)
	QUI.price = make("TextLabel", { Name = "PriceLabel", Text = "R$ ?" }, buy)
	QUI.wheelGui, QUI.wheel = wheelGui, wheel
	wheelGui.Parent = gui
	return QUI
end
function questRow(slot)
	local f = QUI.list:FindFirstChild(`Quest_{slot}`)
	if f == nil then
		return nil
	end
	return {
		frame = f,
		name = f:FindFirstChild("QuestName"),
		progress = f:FindFirstChild("ProgressLabel"),
		fill = f:FindFirstChild("Bar"):FindFirstChild("Fill"),
		reward = f:FindFirstChild("RewardLabel"),
		icon = f:FindFirstChild("Icon"),
		claimButton = f:FindFirstChild("ClaimButton"),
		claimLabel = f:FindFirstChild("ClaimButton"):FindFirstChild("ClaimLabel"),
		claimed = f:FindFirstChild("Claimed"),
	}
end
