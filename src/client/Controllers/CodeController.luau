--!strict
-- CodeController (MAJ 0 ; agent a162, vague 50) : champ de code cadeau et compte à rebours de la prochaine MAJ,
-- dans UI_Settings ou UI_Rewards (le 1er trouvé ; noms proposés à Clément, tous facultatifs) :
--   CodeBox        TextBox : le code saisi (Entrée l'envoie aussi) ;
--   RedeemButton   GuiButton : envoie RedeemCode(CodeBox.Text) ;
--   CodeStatus     TextLabel : la réponse du serveur (« Code redeemed! », « Invalid code »…) ;
--   UpdateCountdown TextLabel : « NEXT UPDATE IN 2d 04h » (Config/Codes), caché quand la date est passée.
-- Sans ces éléments, rien ne se passe (la réponse arrive aussi en Notify). Aucun style n'est touché.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Codes = require(Shared:WaitForChild("Config"):WaitForChild("Codes"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))

local SCREENS = { "UI_Settings", "UI_Rewards" }
local REFRESH = 1 -- V0 : cadence (s) du compte à rebours

local localPlayer = Players.LocalPlayer
local net: any = nil
local bound: { [Instance]: boolean } = {}
local countdowns: { TextLabel } = {}
local statuses: { TextLabel } = {}

local function first(gui: Instance, name: string, class: string): Instance?
	for _, found in Find.all(gui, name) do
		if found:IsA(class) then
			return found
		end
	end
	return nil
end

local function bind(gui: Instance)
	if bound[gui] then
		return
	end
	bound[gui] = true
	local box = first(gui, "CodeBox", "TextBox") :: TextBox?
	local button = first(gui, "RedeemButton", "GuiButton") :: GuiButton?
	local status = first(gui, "CodeStatus", "TextLabel") :: TextLabel?
	local countdown = first(gui, "UpdateCountdown", "TextLabel") :: TextLabel?
	if status then
		table.insert(statuses, status)
	end
	if countdown then
		table.insert(countdowns, countdown)
	end
	if box == nil then
		return
	end
	local field: TextBox = box
	local function send()
		local text = field.Text
		if text ~= "" and #text <= Codes.MaxLength and net then
			net.Client.RedeemCode:Fire(text)
		end
	end
	if button then
		button.Activated:Connect(send)
	end
	field.FocusLost:Connect(function(enter: boolean)
		if enter then
			send()
		end
	end)
end

local function refresh()
	local text = Codes.FormatCountdown(Codes.NextUpdateAt - Workspace:GetServerTimeNow())
	for _, label in countdowns do
		label.Visible = text ~= nil
		if text then
			label.Text = string.format(Codes.CountdownFormat, text)
		end
	end
end

local CodeController = {}

function CodeController.Start()
	net = require(Shared:WaitForChild("Net"):WaitForChild("Net") :: ModuleScript) :: any
	net.Client.CodeResult:Connect(function(_status: string, message: string)
		for _, label in statuses do
			label.Text = message
		end
	end)
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child: Instance)
		if table.find(SCREENS, child.Name) and child:IsA("ScreenGui") then
			bind(child)
			refresh()
		end
	end)
	for _, name in SCREENS do
		local gui = playerGui:FindFirstChild(name)
		if gui and gui:IsA("ScreenGui") then
			bind(gui)
		end
	end
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= REFRESH then
			elapsed = 0
			refresh()
		end
	end)
	refresh()
end

function CodeController.GetCountdownText(): string?
	return Codes.FormatCountdown(Codes.NextUpdateAt - Workspace:GetServerTimeNow())
end

return CodeController
