--!strict
-- FunnelController (a414, vague GC7, client) : envoie au serveur (remote FunnelStep) les étapes d'entonnoir que seul le
-- client voit ; FunnelService les vérifie et les envoie à AnalyticsService (Config/Funnels). Rien d'autre : aucune UI
-- touchée, aucun état de jeu.
--
-- Étapes :
--   Loaded       l'écran de chargement UI_Loading (LoadingScreen de ReplicatedFirst) a quitté le PlayerGui, ou n'y est
--                pas ; valeur = time() du client (secondes depuis son lancement) ;
--   <p>Open      l'écran d'une boutique de Funnels.Screens s'allume (Enabled passe à true) ;
--   RobuxView    boutique Robux allumée : sa liste défile de Funnels.ViewScroll px, ou la souris passe sur un BuyButton ;
--   <p>Buy       clic sur un BuyButton de l'écran allumé (boutique Robux : seulement avec Features.RobuxShop, sinon la
--                vitrine n'ouvre aucun achat).
-- Préfixe <p> : Robux, Weapon ou Aura. Un écran recréé (ResetOnSpawn) est rebranché. Features.Analytics ou
-- Config/Telemetry.Enabled à false : rien n'est branché.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Features = require(Config:WaitForChild("Features"))
local Funnels = require(Config:WaitForChild("Funnels"))
local Telemetry = require(Config:WaitForChild("Telemetry"))

local LOADING_SCREEN = "UI_Loading"
local BUY_BUTTON = "BuyButton"

local localPlayer = Players.LocalPlayer
local net: any = nil

local FunnelController = {}

local function fire(step: string, value: number?)
	if net == nil then
		return
	end
	pcall(function()
		net.Client.FunnelStep:Fire(step, value)
	end)
end

-- Écran d'une boutique : Open à l'allumage, View (Robux) et Buy pendant qu'il est allumé.
local function bindScreen(gui: ScreenGui, prefix: string)
	local robux = prefix == "Robux"
	local viewed = false
	local scrolled = 0
	local function view()
		if robux and gui.Enabled and not viewed then
			viewed = true
			fire("RobuxView")
		end
	end
	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if gui.Enabled then
			viewed = false
			scrolled = 0
			fire(`{prefix}Open`)
		end
	end)
	local function hook(descendant: Instance)
		if descendant:IsA("GuiButton") and descendant.Name == BUY_BUTTON then
			descendant.Activated:Connect(function()
				if gui.Enabled and (not robux or Features.RobuxShop) then
					view()
					fire(`{prefix}Buy`)
				end
			end)
			if robux then
				descendant.MouseEnter:Connect(view)
			end
		elseif robux and descendant:IsA("ScrollingFrame") then
			local frame = descendant :: ScrollingFrame
			local last = frame.CanvasPosition
			frame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
				local now = frame.CanvasPosition
				local moved = (now - last).Magnitude
				last = now
				if gui.Enabled and not viewed then
					scrolled += moved
					if scrolled >= Funnels.ViewScroll then
						view()
					end
				end
			end)
		end
	end
	for _, descendant in gui:GetDescendants() do
		hook(descendant)
	end
	gui.DescendantAdded:Connect(hook)
end

local function onChild(child: Instance)
	local prefix = Funnels.Screens[child.Name]
	if prefix and child:IsA("ScreenGui") then
		bindScreen(child, prefix)
	end
end

-- Attend que l'écran de chargement quitte le PlayerGui (ou qu'il n'y soit pas), puis envoie Loaded.
local function watchLoading(playerGui: Instance)
	local screen = playerGui:FindFirstChild(LOADING_SCREEN)
	while screen and screen:IsDescendantOf(playerGui) do
		screen.AncestryChanged:Wait()
	end
	fire("Loaded", math.min(time(), Funnels.MaxLoadingSeconds))
end

function FunnelController.Start()
	if Features.Analytics ~= true or Telemetry.Enabled ~= true then
		return
	end
	-- Peut attendre que le serveur ait créé les remotes.
	net = require(Shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(onChild)
	for _, child in playerGui:GetChildren() do
		onChild(child)
	end
	watchLoading(playerGui)
end

return FunnelController
