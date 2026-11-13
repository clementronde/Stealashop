--!strict
-- OfflineController (DEV-102, client ; liaison L-092 3f) : l'écran UI_Offline de Clément, qui fait réclamer
-- les gains hors ligne (relevé de Studio du 2026-11-11, agents/wave22-studio.md ; contrat : Contract/UI).
--
-- Rôle :
--   - le serveur (OfflineService) pose sur le Player l'attribut Offline.PendingAttribute (« OfflinePending ») :
--     dollars entiers gagnés hors ligne, en attente du Claim. Tant qu'il vaut au moins 1 $, l'écran s'ouvre
--     (Motion.Open), Offline.OpenDelay s après l'arrivée du personnage (le temps que le HUD apparaisse) et
--     seulement quand aucun autre écran de son groupe (attribut ScreenGroup de Clément, « Menu ») n'est
--     allumé : il attend, par exemple, que l'écran des récompenses se ferme. Un nouveau joueur n'a rien en
--     attente (attribut à 0) : l'écran ne s'ouvre jamais pour lui, tutoriel compris ;
--   - Amount = la somme en attente (Format.money : « $30K »), remise à jour si elle change ;
--   - ClaimButton : envoie le remote ClaimOffline (sans argument : le serveur verse ce qui attend dans le
--     profil), joue Offline.ClaimSound (Offline_Claim, L-097 point 8), puis ferme l'écran. L'argent vole ensuite vers le total (GainController : la case part du
--     centre de l'écran, L-091 point 3), grâce à GetState().Open, vrai jusqu'au versement ;
--   - DoubleButton (×2 contre des Robux) : la boutique Robux est coupée (Features.RobuxShop = false), et même
--     ouverte, aucun produit Robux « gains hors ligne ×2 » n'existe encore (MonetizationService) : un clic
--     montre seulement le Notify SOON_TEXT (« Soon »), comme la vitrine de la boutique Robux (L-071) ;
--     PriceLabel garde le texte de Clément ;
--   - pas de CloseButton (choix de Clément) : l'écran ne se ferme que par Claim, ou quand un autre écran
--     du groupe s'ouvre (Motion.SetCloser). Rien n'est perdu : la somme reste en attente (dans le profil,
--     côté serveur) et l'écran se rouvre dès que le groupe est libre ;
--   - secours : si UI_HUD est là mais pas UI_Offline (écran retiré ou renommé), l'argent ne doit pas rester
--     bloqué : il est réclamé tout seul, avec le Notify Offline.Message (« Your shop earned $X while you
--     were away! ») et une ligne orange en Studio.
-- Sans réponse du serveur au bout de CLAIM_TIMEOUT s (Claim refusé, remote perdu), l'écran peut se rouvrir.
-- Le Flyer caché de UI_Offline n'est pas utilisé (la case qui vole est UI_HUD.CashFly.Template, comme pour
-- les récompenses). Seuls sont touchés : Enabled de l'écran et le texte d'Amount (2.2, « Libre pour
-- Ironix ») ; jamais un style. Un écran recréé (ResetOnSpawn) est rebranché, fermé.
--
-- API (client) :
--   OfflineController.GetState() -> { Open: boolean, Pending: number }
--       Open : l'écran est ouvert, ou un Claim vient de partir et l'argent n'est pas encore arrivé (lu par
--       GainController) ; Pending : dollars en attente (attribut du serveur).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Offline = require(Shared:WaitForChild("Config"):WaitForChild("Offline"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Format = require(Shared:WaitForChild("Format"))
local Motion = require(script.Parent:WaitForChild("UI"):WaitForChild("Motion"))

-- Ce que ce contrôleur utilise de NotifyController.
type NotifyApi = { Show: (message: string, kind: string?) -> () }

-- Écran branché.
type Screen = {
	gui: ScreenGui,
	amount: TextLabel?,
	connections: { RBXScriptConnection },
}

local SCREEN = "UI_Offline"
local HUD = "UI_HUD"
local GROUP_ATTRIBUTE = "ScreenGroup" -- même nom que Controllers/UI/Motion
-- V0 proposés, absents du doc :
local SOON_TEXT = "Soon" -- même mot que la vitrine de la boutique Robux (RobuxShopController)
local CHECK_INTERVAL = 0.5 -- s entre deux vérifications « faut-il ouvrir l'écran ? »
local CLAIM_TIMEOUT = 5 -- s sans versement après un Claim : l'écran peut se rouvrir

local IS_STUDIO = RunService:IsStudio()

local OfflineController = {}

local localPlayer = Players.LocalPlayer
local net: any = nil
local notifier: NotifyApi? = nil
local screen: Screen? = nil
local isOpen = false
local claiming = false
local claimSentAt = 0
local readyAt: number? = nil -- os.clock() à partir duquel l'écran peut s'ouvrir (personnage là + OpenDelay)
local reported: { [string]: boolean } = {}

local function reportOnce(key: string, message: string)
	if IS_STUDIO and not reported[key] then
		reported[key] = true
		warn(message)
	end
end

local function sibling(name: string): any
	local module = script.Parent:FindFirstChild(name)
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	return if ok and type(result) == "table" then result else nil
end

local function notify(message: string, kind: string?)
	local api = notifier
	if api then
		pcall(api.Show, message, kind)
	end
end

-- Dollars entiers en attente (attribut du serveur) ; 0 s'il manque ou est illisible.
local function pending(): number
	local value = localPlayer:GetAttribute(Offline.PendingAttribute)
	if type(value) ~= "number" or value ~= value or value < 1 or value == math.huge then
		return 0
	end
	return math.floor(value)
end

-- Un autre écran allumé du même groupe ScreenGroup que `gui` (rangé à côté de lui).
local function groupBusy(gui: ScreenGui): boolean
	local group = gui:GetAttribute(GROUP_ATTRIBUTE)
	local parent = gui.Parent
	if type(group) ~= "string" or group == "" or parent == nil then
		return false
	end
	for _, other in parent:GetChildren() do
		if other ~= gui and other:IsA("ScreenGui") and (other :: ScreenGui).Enabled and other:GetAttribute(GROUP_ATTRIBUTE) == group then
			return true
		end
	end
	return false
end

-- Écran ------------------------------------------------------------------------------------------

local function writeAmount(current: Screen)
	local label = current.amount
	local text = Format.money(pending())
	if label and label.Text ~= text then
		label.Text = text
	end
end

local function close()
	isOpen = false
	local current = screen
	if current then
		Motion.Close(current.gui)
	end
end

local function open(current: Screen)
	isOpen = true
	writeAmount(current)
	Motion.Open(current.gui)
end

-- Envoie le Claim (une fois : la suite attend le versement ou CLAIM_TIMEOUT).
local function sendClaim(): boolean
	if claiming or pending() < 1 or net == nil then
		return false
	end
	claiming = true
	claimSentAt = os.clock()
	net.Client.ClaimOffline:Fire()
	return true
end

local function onClaim()
	if sendClaim() then
		Motion.PlaySound(Offline.ClaimSound) -- L-097 point 8 ; Cash_Collect suit à l'arrivée (GainController)
		close()
	end
end

local function onDouble()
	-- Boutique Robux coupée, et aucun produit « ×2 » encore : rien d'autre que « Soon » (voir l'en-tête).
	notify(SOON_TEXT, "Info")
end

local function button(root: Instance, name: string): GuiButton?
	local found = Find.path(root, name)
	if found and found:IsA("GuiButton") then
		return found :: GuiButton
	end
	reportOnce(`button:{name}`, `[Offline] {SCREEN}.{name} introuvable ou pas un bouton`)
	return nil
end

local function bind(gui: ScreenGui)
	local old = screen
	if old then
		for _, connection in old.connections do
			connection:Disconnect()
		end
	end
	isOpen = false
	gui.Enabled = false -- fermé tant que rien n'attend
	Motion.SetCloser(gui, close) -- un autre écran du groupe s'ouvre : on se ferme, la somme reste en attente

	local found = Find.path(gui, "Amount")
	local current: Screen = {
		gui = gui,
		amount = if found and found:IsA("TextLabel") then found :: TextLabel else nil,
		connections = {},
	}
	screen = current
	local claimButton = button(gui, "ClaimButton")
	if claimButton then
		table.insert(current.connections, claimButton.Activated:Connect(onClaim))
	end
	local doubleButton = button(gui, "DoubleButton")
	if doubleButton then
		table.insert(current.connections, doubleButton.Activated:Connect(onDouble))
	end
end

-- Écran branché encore présent, ou celui de PlayerGui (branché au passage), ou nil.
local function currentScreen(): Screen?
	local current = screen
	if current and current.gui.Parent ~= nil then
		return current
	end
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local gui = if playerGui then playerGui:FindFirstChild(SCREEN) else nil
	if gui and gui:IsA("ScreenGui") then
		bind(gui :: ScreenGui)
		return screen
	end
	return nil
end

-- Écran absent mais HUD là : l'argent est réclamé tout seul (secours, voir l'en-tête).
local function fallback()
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil or playerGui:FindFirstChild(HUD) == nil then
		return -- les écrans ne sont pas encore arrivés
	end
	local amount = pending()
	reportOnce("screen", `[Offline] écran {SCREEN} absent de PlayerGui : gains hors ligne réclamés sans écran`)
	if sendClaim() then
		notify(string.format(Offline.Message, Format.money(amount)), "Info")
	end
end

-- Toutes les CHECK_INTERVAL s : ouvrir, garder ou fermer l'écran.
local function check()
	local now = os.clock()
	if claiming and now - claimSentAt > CLAIM_TIMEOUT then
		claiming = false -- pas de versement : le Claim pourra repartir
	end
	if readyAt == nil and localPlayer.Character ~= nil then
		readyAt = now + math.max(0, Offline.OpenDelay)
	end
	local ready = readyAt
	local wanted = pending() >= 1 and not claiming and ready ~= nil and now >= ready
	local current = currentScreen()
	if current == nil then
		if wanted then
			fallback()
		end
		return
	end
	if isOpen and not current.gui.Enabled then
		isOpen = false -- éteint par ailleurs
	end
	if wanted and not isOpen and not groupBusy(current.gui) then
		open(current)
	elseif isOpen and pending() < 1 and not claiming then
		close() -- plus rien en attente
	end
end

local function onPendingChanged()
	local current = screen
	if isOpen and current then
		writeAmount(current)
	end
	if claiming and pending() < 1 then
		-- Versé. Au tour suivant : GainController classe d'abord la hausse de Cash (écran « ouvert »).
		task.defer(function()
			if pending() < 1 then
				claiming = false
			end
		end)
	end
end

function OfflineController.GetState(): { Open: boolean, Pending: number }
	return { Open = isOpen or claiming, Pending = pending() }
end

function OfflineController.Start()
	-- Peut attendre que le serveur ait créé les remotes.
	net = require(Shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any
	notifier = sibling("NotifyController")

	localPlayer:GetAttributeChangedSignal(Offline.PendingAttribute):Connect(onPendingChanged)
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child: Instance)
		if child.Name == SCREEN and child:IsA("ScreenGui") then
			bind(child :: ScreenGui)
		end
	end)
	local existing = playerGui:FindFirstChild(SCREEN)
	if existing and existing:IsA("ScreenGui") then
		bind(existing :: ScreenGui)
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed < CHECK_INTERVAL then
			return
		end
		elapsed = 0
		check()
	end)
end

return OfflineController
