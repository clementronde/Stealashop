--!strict
-- DiamondBalance (vague 63, a209 ; liaison L-204 point 3, L-188 B ; client) : le solde de diamants de
-- UI_DiamondShop, seul endroit où il s'affiche (décision de Clément). Module d'aide rangé dans Controllers/UI (le
-- Loader ne le démarre pas) : ShopFxController appelle DiamondBalance.Start().
--
-- Header.Balance.Amount (Config/ShopFx.Diamonds.Amount) écrit l'attribut Diamonds du joueur (Format.short) : premier
-- remplissage d'un coup ; une hausse défile comme Cash ; une baisse (un achat) décompte en 1,9 s, Quint Out (les
-- réglages de Config/Hud.CashSpent, comme le Cash du HUD, par Motion.Roll), et Balance.Spent (TextLabel rouge de
-- Clément, caché au repos) montre « -X » : il apparaît en SpentIn s, reste SpentHold s, puis monte et s'efface en
-- SpentOut s, et se recache. Un achat de plus pendant ce temps s'ajoute au montant et le garde à l'écran.
-- Sans l'attribut (le serveur ne l'écrit pas encore), sans l'écran ou sans Amount : rien n'est écrit.
--
-- Ce qui est touché : Text de Amount et de Spent ; le temps de « -X » seulement, Visible, Position (montée) et
-- transparences de Spent (TextTransparency, et Transparency de ses UIStroke), remises à la valeur de Clément à la fin.
-- Une connexion Heartbeat seulement pendant « -X ».
--
-- API (client) :
--   DiamondBalance.Start()
--   DiamondBalance.GetSpent() -> number?   montant affiché par « -X » (nil : caché)   (bancs)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local ShopFx = require(Config:WaitForChild("ShopFx"))
local Hud = require(Config:WaitForChild("Hud"))
local Format = require(Shared:WaitForChild("Format"))
local Find = require(Shared:WaitForChild("Contract"):WaitForChild("Find"))
local Motion = require(script.Parent:WaitForChild("Motion"))

local SPEC = ShopFx.Diamonds
local SPENT_INFO = TweenInfo.new(Hud.CashSpent.Time, Hud.CashSpent.Style, Hud.CashSpent.Direction)

type Fader = { object: Instance, property: string, base: number }

type Spent = {
	label: TextLabel,
	visible: boolean, -- Visible de Clément
	position: UDim2,
	faders: { Fader },
	rise: number, -- px
	startedAt: number,
	amount: number,
}

local DiamondBalance = {}

local localPlayer = Players.LocalPlayer
local written: { [TextLabel]: number } = setmetatable({}, { __mode = "k" }) :: any
local spent: Spent? = nil
local heartbeat: RBXScriptConnection? = nil

local function format(value: number): string
	return Format.short(value)
end

local function screen(): ScreenGui?
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local found = if playerGui then playerGui:FindFirstChild(SPEC.Screen) else nil
	return if found and found:IsA("ScreenGui") then found :: ScreenGui else nil
end

local function label(gui: ScreenGui, path: string): TextLabel?
	local found = Find.path(gui, path)
	return if found and found:IsA("TextLabel") then found :: TextLabel else nil
end

local function stopHeartbeat()
	local connection = heartbeat
	heartbeat = nil
	if connection then
		connection:Disconnect()
	end
end

local function endSpent()
	local current = spent
	spent = nil
	stopHeartbeat()
	if current == nil then
		return
	end
	for _, fader in current.faders do
		(fader.object :: any)[fader.property] = fader.base
	end
	current.label.Position = current.position
	current.label.Visible = current.visible
end

local function setFade(current: Spent, u: number) -- 0 = comme Clément, 1 = effacé
	for _, fader in current.faders do
		(fader.object :: any)[fader.property] = fader.base + (1 - fader.base) * u
	end
end

local function step()
	local current = spent
	if current == nil or current.label.Parent == nil then
		endSpent()
		return
	end
	local t = os.clock() - current.startedAt
	local fadeIn, hold, out = SPEC.SpentIn, SPEC.SpentHold, SPEC.SpentOut
	local p = current.position
	if t < fadeIn then
		setFade(current, 1 - t / fadeIn)
		current.label.Position = p
	elseif t < fadeIn + hold then
		setFade(current, 0)
		current.label.Position = p
	elseif t < fadeIn + hold + out then
		local u = (t - fadeIn - hold) / out
		setFade(current, u)
		current.label.Position = UDim2.new(p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset - current.rise * u)
	else
		endSpent()
	end
end

local function showSpent(gui: ScreenGui, amount: number)
	local found = label(gui, SPEC.Spent)
	if found == nil or amount <= 0 then
		return
	end
	local now = os.clock()
	local current = spent
	if current ~= nil and current.label == found then
		-- un achat de plus : le montant s'ajoute, « -X » reste (son apparition continue, la pause repart)
		current.amount += amount
		local elapsed = now - current.startedAt
		current.startedAt = now - math.min(elapsed, SPEC.SpentIn)
		current.label.Position = current.position
	else
		endSpent()
		local faders: { Fader } = {}
		local all: { Instance } = found:GetDescendants()
		table.insert(all, 1, found)
		for _, object in all do
			if object == found then
				table.insert(faders, { object = object, property = "TextTransparency", base = found.TextTransparency })
			elseif object:IsA("UIStroke") then
				table.insert(faders, { object = object :: Instance, property = "Transparency", base = (object :: UIStroke).Transparency })
			end
		end
		local height = found.AbsoluteSize.Y
		current = {
			label = found,
			visible = found.Visible,
			position = found.Position,
			faders = faders,
			rise = SPEC.SpentRise * (if height > 0 then height else 20),
			startedAt = now,
			amount = amount,
		}
		spent = current
	end
	local shown = current :: Spent
	shown.label.Text = `{SPEC.Prefix}{Format.short(shown.amount)}`
	shown.label.Visible = true
	if heartbeat == nil then
		heartbeat = RunService.Heartbeat:Connect(step)
	end
	step()
end

local function write()
	local gui = screen()
	local amount = if gui then label(gui, SPEC.Amount) else nil
	local value = localPlayer:GetAttribute(SPEC.Attribute)
	if gui == nil or amount == nil or type(value) ~= "number" or value ~= value then
		return
	end
	local previous = written[amount]
	written[amount] = value
	if previous ~= nil and value < previous then
		Motion.Roll(amount, previous, value, format, SPENT_INFO)
		showSpent(gui, previous - value)
	else
		Motion.Roll(amount, previous, value, format)
	end
end

function DiamondBalance.GetSpent(): number?
	local current = spent
	return if current then current.amount else nil
end

-- Écran arrivé (copie neuve) : « -X » caché au repos, le solde tout de suite.
local function prepare()
	local gui = screen()
	local found = if gui then label(gui, SPEC.Spent) else nil
	local current = spent
	if found and (current == nil or current.label ~= found) then
		found.Visible = false
	end
	write()
end

function DiamondBalance.Start()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	localPlayer:GetAttributeChangedSignal(SPEC.Attribute):Connect(write)
	playerGui.ChildAdded:Connect(function(child: Instance)
		if child.Name == SPEC.Screen then
			task.defer(prepare)
		end
	end)
	prepare()
end

return DiamondBalance
