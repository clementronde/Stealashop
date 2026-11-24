--!nocheck
-- Mise en place du banc a74 (vague 24, L-095 point 6), après celle du banc a61 version a62 (setup.luau de
-- la copie d'a51, setup61.luau : écrans UI_HUD et UI_Inventory par buildInventoryUi) :
--   - bouchons côté client : ChaseController (IsChased = CHASED), ChaseFeelController (cache UI_Hotbar
--     pendant la poursuite et remet l'Enabled d'avant à la fin, comme le vrai : hotbarStates), et
--     NotifyController (Show note le message dans NOTIFIED) ;
--   - vrai HotbarController ;
--   - buildHotbarUi(player, opts) : StarterGui/UI_Hotbar du relevé de Studio du 2026-11-11 (Enabled =
--     false ; Bar {SlotCount = 6, TouchSlotCount = 4}, UIListLayout, Template caché : Clip avec Glow,
--     Icon, KeyLabel « 1 », ItemName « Item », Income « $0/s », Equipped et HoverOutline cachés) et la
--     colonne LeftRailTouch de UI_HUD avec son propre InventoryButton ;
--   - SOUNDS : sons d'UI joués par Motion (Motion.SetSoundPlayer, posé par useSounds()).

SOURCES["stub/ChaseController"] = [==[
local ChaseController = {}
function ChaseController.IsChased()
	return CHASED == true
end
function ChaseController.GetGuard()
	return nil
end
return ChaseController
]==]
CHASED = false

SOURCES["stub/ChaseFeelController"] = [==[
local ChaseFeelController = {}
local states = {}
local active = false
function ChaseFeelController.Start()
	task.spawn(function()
		while true do
			task.wait(0.1)
			local playerGui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
			if CHASED then
				active = true
				local hotbar = playerGui and playerGui:FindFirstChild("UI_Hotbar")
				if hotbar then
					if states[hotbar] == nil then
						states[hotbar] = hotbar.Enabled
					end
					hotbar.Enabled = false
				end
			elseif active then
				active = false
				for screen, enabled in states do
					if screen.Parent then
						screen.Enabled = enabled
					end
				end
				table.clear(states)
			end
		end
	end)
end
return ChaseFeelController
]==]

SOURCES["stub/NotifyController"] = [==[
local NotifyController = {}
function NotifyController.Show(message, kind)
	table.insert(NOTIFIED, { message = message, kind = kind })
end
return NotifyController
]==]
NOTIFIED = {}

moduleScript(CONTROLLERS, "HotbarController", "client/Controllers/HotbarController.luau")
moduleScript(CONTROLLERS, "ChaseController", "stub/ChaseController")
moduleScript(CONTROLLERS, "ChaseFeelController", "stub/ChaseFeelController")
moduleScript(CONTROLLERS, "NotifyController", "stub/NotifyController")

HOTBAR_TEMPLATE_IMAGE = "rbxassetid://55"
TEMPLATE_CLIP = Color3.new(0.2, 0.2, 0.25)
TEMPLATE_GLOW = Color3.new(1, 1, 1)
make("Decal", { Name = "ICON_BOX_Premium", Texture = "rbxassetid://9100" }, ICONS)

function makeHotbarScreen(enabled)
	local gui = make("ScreenGui", { Name = "UI_Hotbar", Enabled = enabled == true }, nil)
	local bar = make("Frame", { Name = "Bar" }, gui)
	bar:SetAttribute("SlotCount", 6)
	bar:SetAttribute("TouchSlotCount", 4)
	make("UIListLayout", { Name = "UIListLayout" }, bar)
	local t = make("TextButton", { Name = "Template", Visible = false, Text = "" }, bar)
	local clip = make("Frame", { Name = "Clip", BackgroundColor3 = TEMPLATE_CLIP }, t)
	make("ImageLabel", { Name = "Glow", ImageColor3 = TEMPLATE_GLOW }, clip)
	make("ImageLabel", { Name = "Icon", Image = HOTBAR_TEMPLATE_IMAGE, Position = UDim2.new(0.5, 0, 0.5, 0), Rotation = 0 }, t)
	make("TextLabel", { Name = "KeyLabel", Text = "1" }, t)
	make("TextLabel", { Name = "ItemName", Text = "Item" }, t)
	make("TextLabel", { Name = "Income", Text = "$0/s" }, t)
	make("Frame", { Name = "Equipped", Visible = false }, t)
	make("Frame", { Name = "HoverOutline", Visible = false }, t)
	return gui
end

HB = {}
function buildHotbarUi(player, opts)
	opts = opts or {}
	local gui = player:FindFirstChild("PlayerGui")
	local touchRail = make("Frame", { Name = "LeftRailTouch" }, INV.hud)
	local touchButton = make("TextButton", { Name = "InventoryButton", Text = "" }, touchRail)
	HB = { touchButton = touchButton }
	if opts.noHotbar then
		return HB
	end
	local screen = makeHotbarScreen(false)
	screen.Parent = gui
	HB.screen = screen
	return HB
end

-- Cases clonées de la barre, par nom (Slot_<clé>), et leur nombre.
function slotsOf(screen)
	local out, n = {}, 0
	local bar = (screen or HB.screen):FindFirstChild("Bar")
	for _, child in bar:GetChildren() do
		if string.sub(child.Name, 1, 5) == "Slot_" then
			out[child.Name] = child
			n += 1
		end
	end
	return out, n
end
-- Noms des cases, dans l'ordre (LayoutOrder).
function slotOrder(screen)
	local list = {}
	for name, slot in slotsOf(screen) do
		table.insert(list, slot)
	end
	table.sort(list, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	local names = {}
	for _, slot in list do
		table.insert(names, slot.Name)
	end
	return table.concat(names, ",")
end
function slotPart(slot, name)
	return Find.path(slot, name)
end
SOUNDS = {}
function useSounds()
	local Motion = requireModule(CONTROLLERS:FindFirstChild("UI"):FindFirstChild("Motion"), "client")
	Motion.SetSoundPlayer(function(name)
		table.insert(SOUNDS, name)
	end)
	return Motion
end
function lastNotify()
	return NOTIFIED[#NOTIFIED]
end
function near(a, b)
	return math.abs(a.R - b.R) < 1e-6 and math.abs(a.G - b.G) < 1e-6 and math.abs(a.B - b.B) < 1e-6
end
