SOURCES["stub/ShelfBoxController"] = [==[
local S = {}
function S.Reserve() end
return S
]==]
SOURCES["stub/DisplayController"] = [==[
local D = { listeners = {} }
function D.OnCollect(fn)
	table.insert(D.listeners, fn)
	return function() end
end
function D.Fire(amount, slot, position)
	for _, fn in table.clone(D.listeners) do
		task.spawn(fn, amount, slot, position)
	end
end
return D
]==]
moduleScript(CONTROLLERS, "ShelfBoxController", "stub/ShelfBoxController")
moduleScript(CONTROLLERS, "DisplayController", "stub/DisplayController")
VFX_MODULE = moduleScript(CONTROLLERS, "VfxController", "client/Controllers/VfxController.luau")
local COLLECT_MODULE = moduleScript(CONTROLLERS, "CollectFeelController", "client/Controllers/CollectFeelController.luau")
local FX = folder(ASSETS, "FX")
local function flyerModel(name, partName)
	local model = new("Model", { Name = name })
	local part = new("Part", { Name = partName, Size = Vector3.new(1.4, 0.05, 0.7) }, model)
	new("Trail", { Name = "Trail" }, part)
	model.PrimaryPart = part
	model.Parent = FX
end
flyerModel("FX_Collect_Bill", "Bill")
flyerModel("FX_Collect_Coin", "Coin")
if not NO_PAD then
	local cashFolder = folder(SOUNDS, "Cash")
	new("Sound", { Name = "Cash_Pad" }, cashFolder)
end
P1:SetAttribute("Cash", 100)
P1:SetAttribute("Income", 10)
P1:SetAttribute("Speed", 10)
P1:SetAttribute("Strength", 5)
P1:SetAttribute("WalkSpeed", 16)
P1:SetAttribute("Damage", 1)
P1:SetAttribute("CashCollected", 0)
local hud = makeHud()
local Display = requireModule(CONTROLLERS.DisplayController, "client")
requireModule(ReplicatedStorage.Shared.Net.Net, "server")
local Hud = requireModule(HUD_MODULE, "client")
local Gain = requireModule(GAIN_MODULE, "client")
local Vfx = requireModule(VFX_MODULE, "client")
local Feel = requireModule(FEEL_MODULE, "client")
local Collect = requireModule(COLLECT_MODULE, "client")
taskLib.spawn(Vfx.Start)
taskLib.spawn(Feel.Start)
taskLib.spawn(Collect.Start)
taskLib.spawn(Hud.Start)
taskLib.spawn(Gain.Start)
step(0.1)
local pad = Vector3.new(10, 1, 5)
local function run(label, order)
	local s0 = #SOUNDS_PLAYED
	local t0 = now()
	local c = P1:GetAttribute("Cash")
	local cc = P1:GetAttribute("CashCollected")
	if order == "attr" then
		P1:SetAttribute("Cash", c + 1000)
		P1:SetAttribute("CashCollected", cc + 1000)
		Display.Fire(1000, 1, pad)
	else
		Display.Fire(1000, 1, pad)
		P1:SetAttribute("Cash", c + 1000)
		P1:SetAttribute("CashCollected", cc + 1000)
	end
	step(3)
	local parts = {}
	for i = s0 + 1, #SOUNDS_PLAYED do
		table.insert(parts, string.format("%s@%.2f", SOUNDS_PLAYED[i].name, SOUNDS_PLAYED[i].t - t0))
	end
	print(label, table.concat(parts, " "))
end
run("attr-puis-remote", "attr")
local function rapid(gap, n)
	local s0 = #SOUNDS_PLAYED
	local t0 = now()
	for k = 1, n do
		local c = P1:GetAttribute("Cash")
		local cc = P1:GetAttribute("CashCollected")
		P1:SetAttribute("Cash", c + 1000)
		P1:SetAttribute("CashCollected", cc + 1000)
		Display.Fire(1000, k, pad)
		step(gap)
	end
	step(3)
	local parts = {}
	for i = s0 + 1, #SOUNDS_PLAYED do
		table.insert(parts, string.format("%s@%.2f", SOUNDS_PLAYED[i].name, SOUNDS_PLAYED[i].t - t0))
	end
	print("rapide " .. gap, table.concat(parts, " "))
end
rapid(0.25, 4)
rapid(1/30, 4)
rapid(0.7, 3)
run("remote-puis-attr", "remote")
P1:SetAttribute("VfxEnabled", false)
run("sans-billets", "attr")
P1:SetAttribute("VfxEnabled", nil)
for _, l in LOG do print("LOG", l) end
summary()
