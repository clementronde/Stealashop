--!nocheck
-- Mise en place du banc a118 (vague 34, L-127 points 3 et 4), après setup61 (UI_Inventory), setup74 et setup76
-- (UI_Hotbar, HotbarController) et ext105 (antivol au sol) :
--   - module client Controllers/Unbox/AntiTheftChains (absent des listes des autres bancs) ;
--   - kit de Clément ReplicatedStorage/Assets/FX/FX_AntiTheft (antitheft_fx_build.luau) : Link (une Part ici, le
--     faux Roblox ne connaît pas UnionOperation), Padlock (Body, Shackle ; pivot en haut de l'anse), attributs ;
--   - addAlertParts() : AntiTheft (Dim, ChainA, ChainB, Padlock, LockLabel « LOCKED »), CardAlert / SlotAlert
--     (AlertLabel « ! », UIScale Pulse), cachés comme dans Studio, sur les Templates d'UI_Inventory et d'UI_Hotbar.
if SOURCES["client/Controllers/Unbox/AntiTheftChains.luau"] then
	moduleScript(CONTROLLERS:FindFirstChild("Unbox"), "AntiTheftChains", "client/Controllers/Unbox/AntiTheftChains.luau")
end

do
	local fx = ASSETS:FindFirstChild("FX") or folder(ASSETS, "FX")
	local kit = make("Model", { Name = "FX_AntiTheft" })
	kit:SetAttribute("FitSize", 2)
	kit:SetAttribute("LinkPitch", 0.34 - 2 * 0.055 - 0.005)
	kit:SetAttribute("LinkWidth", 0.2)
	kit:SetAttribute("WrapAngle", 0.85)
	make("Part", { Name = "Link", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Size = Vector3.new(0.055, 0.2, 0.34) }, kit)
	local padlock = make("Model", { Name = "Padlock" }, kit)
	local body = make("Part", { Name = "Body", Anchored = true, CanCollide = false, CanQuery = false, Size = Vector3.new(0.56, 0.46, 0.2), CFrame = CFrame.new(0, -0.1, -0.16) }, padlock)
	make("Part", { Name = "Shackle", Anchored = true, CanCollide = false, CanQuery = false, Size = Vector3.new(0.42, 0.3, 0.08), CFrame = CFrame.new(0, 0.22, -0.16) }, padlock)
	padlock.PrimaryPart = body
	body.PivotOffset = CFrame.new(0, 0.43, 0.1) -- pivot du cadenas : (0, 0.33, −0.06), en haut de l'anse
	kit.WorldPivot = CFrame.identity
	kit.Parent = fx
	FX_KIT = kit
end

local function alert(name, parent)
	local a = make("Frame", { Name = name, Visible = false }, parent)
	make("TextLabel", { Name = "AlertLabel", Text = "!" }, a)
	make("UIScale", { Name = "Pulse", Scale = 1 }, a)
	return a
end
local function overlay(parent, lockVisible)
	local o = make("Frame", { Name = "AntiTheft", Visible = false }, parent)
	make("Frame", { Name = "Dim" }, o)
	make("Frame", { Name = "ChainA" }, o)
	make("Frame", { Name = "ChainB" }, o)
	make("Frame", { Name = "Padlock" }, o)
	make("TextLabel", { Name = "LockLabel", Text = "LOCKED", Visible = lockVisible }, o)
	return o
end
function addAlertParts()
	overlay(INV.templates.Items, true)
	alert("CardAlert", INV.templates.Items)
	alert("CardAlert", INV.templates.Boxes)
	local template = HB.screen and HB.screen:FindFirstChild("Bar"):FindFirstChild("Template")
	if template then
		overlay(template, false)
		alert("SlotAlert", template)
	end
end
