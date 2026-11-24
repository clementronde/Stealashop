---------------------------------------------------------------- banc a422 (24/11, Cantin : le son de la plaque part au contact)
-- 3e partie du banc a401 : la config du JEU (Config/CashFlash allumé, UiMotion.CollectFeel coupé, pas de rallume.pl).
-- Collé après setup.luau, setup-a60.luau et setup-a75.luau (faux Roblox d'a80). Vrais VfxController, GainController,
-- HudController, UiFeelController, CollectFeelController et UI/Motion ; DisplayController bouchonné (Fire = remote
-- CashCollect du joueur local, écouteurs lancés par task.spawn comme le vrai) ; OfflineController bouchonné (open).
-- Contrôlé : un seul son par plaque, parti à l'image du contact (Cash_Pad, ou Cash_Collect si Cash_Pad manque), plus
-- rien à l'arrivée du premier billet ; le reste de L-299 inchangé (chiffre retenu jusqu'au premier billet, voile) ;
-- écran des gains hors ligne ouvert : l'ancien encaissement (Cash_Collect au contact, une fois) ; encaissement
-- automatique : Cash_Collect, comme avant.
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
SOURCES["stub/OfflineController"] = [==[
local O = { open = false }
function O.GetState()
	return { Open = O.open }
end
return O
]==]
moduleScript(CONTROLLERS, "ShelfBoxController", "stub/ShelfBoxController")
moduleScript(CONTROLLERS, "DisplayController", "stub/DisplayController")
moduleScript(CONTROLLERS, "OfflineController", "stub/OfflineController")
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
-- Comme dans la place : Assets/Sounds/Cash/Cash_Pad (Cash_Collect est posé par setup-a60.luau).
local CASH_SOUNDS = folder(SOUNDS, "Cash")
local PAD_SOUND = new("Sound", { Name = "Cash_Pad" }, CASH_SOUNDS)

local function played(name, from)
	local list = {}
	for i = (from or 0) + 1, #SOUNDS_PLAYED do
		if SOUNDS_PLAYED[i].name == name then
			table.insert(list, SOUNDS_PLAYED[i])
		end
	end
	return list
end
local function cashSounds(from)
	local list = {}
	for i = (from or 0) + 1, #SOUNDS_PLAYED do
		local n = SOUNDS_PLAYED[i].name
		if n == "Cash_Pad" or n == "Cash_Collect" then
			table.insert(list, SOUNDS_PLAYED[i])
		end
	end
	return list
end
local function describe(list, t0)
	local parts = {}
	for _, s in list do
		table.insert(parts, string.format("%s à +%.2f s", s.name, s.t - t0))
	end
	return if #parts == 0 then "aucun" else table.concat(parts, ", ")
end

P1:SetAttribute("Cash", 100)
P1:SetAttribute("Income", 10)
P1:SetAttribute("Speed", 10)
P1:SetAttribute("Strength", 5)
P1:SetAttribute("WalkSpeed", 16)
P1:SetAttribute("Damage", 1)
P1:SetAttribute("CashCollected", 0)
local hud = makeHud()
-- UI_CashFlash de Clément (voile de L-299), bandes à leur transparence posée.
local flashGui = new("ScreenGui", { Name = "UI_CashFlash", Enabled = false, IgnoreGuiInset = true })
local edge = new("Frame", { Name = "EdgeGlow", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, flashGui)
for _, name in { "Top", "Bottom", "Left", "Right" } do
	new("Frame", { Name = name, BackgroundTransparency = 0.3, Size = UDim2.fromScale(1, 0.1) }, edge)
end
flashGui.Parent = PLAYER_GUI

local Display = requireModule(CONTROLLERS.DisplayController, "client")
local Offline = requireModule(CONTROLLERS.OfflineController, "client")
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
local cash = el(hud, "Cash")
local pad = Vector3.new(10, 1, 5)
local Flash = requireModule(ReplicatedStorage.Shared.Config.CashFlash, "client")
local FEEL = UiMotionC.CollectFeel
local VfxCfg = requireModule(ReplicatedStorage.Shared.Config.Vfx, "client")
local FOUNT = VfxCfg.Collect.Fountain
local FIRST = FOUNT.PopTime + FOUNT.HoverTime + FOUNT.FlyTime -- 1re arrivée de billet (≈ 0,68 s)
local FRAME = 1 / 30

-- Une plaque vidée : attributs Cash et CashCollected (+1000) et remote, dans l'ordre `order`.
local function collect(slot, order)
	local c = P1:GetAttribute("Cash")
	local cc = P1:GetAttribute("CashCollected")
	if order == "remote" then
		Display.Fire(1000, slot, pad)
		P1:SetAttribute("Cash", c + 1000)
		P1:SetAttribute("CashCollected", cc + 1000)
	else
		P1:SetAttribute("Cash", c + 1000)
		P1:SetAttribute("CashCollected", cc + 1000)
		Display.Fire(1000, slot, pad)
	end
end

check(Flash.Enabled == true and FEEL.Enabled == false and UiMotionC.CashFly.Enabled == false, "K0 config du jeu : CashFlash allumé, CollectFeel et case qui vole coupés")
check(Flash.SoundOnContact == true and Flash.FallbackSound == "Cash_Collect", "K0b a422 : son au contact, Cash_Collect si Cash_Pad manque (V0 Cantin, 24/11)")

print("\n== K1. Attributs puis remote : Cash_Pad à l'image du contact, une fois ; le reste de L-299 ne change pas")
local s0, t0 = #SOUNDS_PLAYED, now()
collect(1, "attr")
step(FRAME)
local early = cashSounds(s0)
check(#early == 1 and early[1].name == "Cash_Pad" and early[1].t - t0 < FRAME, `K1a un son à l'image du contact, Cash_Pad ({describe(early, t0)})`)
check(#early == 1 and math.abs(early[1].speed - 1) <= Flash.PitchJitter + 1e-9, `K1b hauteur ± {Flash.PitchJitter * 100} % ({early[1] and early[1].speed})`)
check(flashGui.Enabled == true, "K1c voile UI_CashFlash allumé au contact (inchangé)")
step(FIRST - 0.2)
check(cash.Text == "$100", `K1d chiffre encore retenu avant le 1er billet (inchangé, L-299) ({cash.Text})`)
step(0.4)
check(cash.Text ~= "$100", `K1e il défile à l'arrivée du 1er billet ({cash.Text})`)
step(Flash.LandTimeout + 0.5)
local all = cashSounds(s0)
check(#all == 1, `K1f un seul son pour la plaque, rien à l'arrivée du billet ni après LandTimeout ({describe(all, t0)})`)
check(cash.Text == "$1.1K" and flashGui.Enabled == false, `K1g chiffre final « $1.1K », voile éteint ({cash.Text})`)

print("\n== K2. Remote puis attributs : pareil")
s0, t0 = #SOUNDS_PLAYED, now()
collect(2, "remote")
step(FRAME)
early = cashSounds(s0)
check(#early == 1 and early[1].name == "Cash_Pad", `K2a Cash_Pad à l'image du contact ({describe(early, t0)})`)
step(3)
all = cashSounds(s0)
check(#all == 1 and cash.Text == "$2.1K", `K2b un seul son, « $2.1K » ({describe(all, t0)}, {cash.Text})`)

print("\n== K3. Sans Cash_Pad dans Assets/Sounds : Cash_Collect au contact, une fois")
PAD_SOUND.Parent = nil
s0, t0 = #SOUNDS_PLAYED, now()
collect(3, "attr")
step(FRAME)
early = cashSounds(s0)
check(#early == 1 and early[1].name == "Cash_Collect" and early[1].t - t0 < FRAME, `K3a un son au contact quand même : Cash_Collect ({describe(early, t0)})`)
step(3)
all = cashSounds(s0)
check(#all == 1, `K3b un seul son ({describe(all, t0)})`)
check(cash.Text == "$3.1K", `K3c « $3.1K » ({cash.Text})`)
PAD_SOUND.Parent = CASH_SOUNDS

print("\n== K4. VISUAL EFFECTS sur OFF (aucun billet) : Cash_Pad au contact, chiffre tout de suite, un seul son")
P1:SetAttribute("VfxEnabled", false)
s0, t0 = #SOUNDS_PLAYED, now()
collect(4, "attr")
step(FRAME)
early = cashSounds(s0)
check(#early == 1 and early[1].name == "Cash_Pad", `K4a Cash_Pad au contact ({describe(early, t0)})`)
step(0.5)
check(cash.Text == "$4.1K", `K4b chiffre tout de suite, sans billet ({cash.Text})`)
step(2.5)
check(#cashSounds(s0) == 1, `K4c un seul son ({describe(cashSounds(s0), t0)})`)
P1:SetAttribute("VfxEnabled", nil)

print("\n== K5. Hausse arrivée 0,5 s après le remote (au-delà de MatchWindow) : toujours un seul son, au contact")
s0, t0 = #SOUNDS_PLAYED, now()
Display.Fire(1000, 5, pad)
step(Flash.MatchWindow + 0.2)
P1:SetAttribute("Cash", P1:GetAttribute("Cash") + 1000)
P1:SetAttribute("CashCollected", P1:GetAttribute("CashCollected") + 1000)
step(3)
all = cashSounds(s0)
check(#all == 1 and all[1].name == "Cash_Pad" and all[1].t - t0 < FRAME, `K5a un seul son, Cash_Pad au contact ({describe(all, t0)})`)
check(cash.Text == "$5.1K", `K5b « $5.1K » ({cash.Text})`)

print("\n== K6. Rangée vidée en courant (4 plaques, 0,25 s d'écart) : un son par plaque, chacun à son contact")
s0, t0 = #SOUNDS_PLAYED, now()
local contacts = {}
for k = 1, 4 do
	table.insert(contacts, now())
	collect(k, "attr")
	step(0.25)
end
step(3)
all = cashSounds(s0)
local onTime = #all == 4
for k, s in all do
	onTime = onTime and s.name == "Cash_Pad" and contacts[k] ~= nil and s.t - contacts[k] < FRAME
end
check(onTime, `K6a 4 Cash_Pad, chacun à l'image de sa plaque ({describe(all, t0)})`)
check(cash.Text == "$9.1K", `K6b « $9.1K » ({cash.Text})`)

print("\n== K7. Écran des gains hors ligne ouvert : l'ancien encaissement (Cash_Collect au contact, une fois)")
Offline.open = true
s0, t0 = #SOUNDS_PLAYED, now()
collect(1, "attr")
step(FRAME)
early = cashSounds(s0)
check(#early == 1 and early[1].name == "Cash_Collect", `K7a Cash_Collect au contact ({describe(early, t0)})`)
step(3)
all = cashSounds(s0)
check(#all == 1 and #played("Cash_Pad", s0) == 0, `K7b un seul son, jamais Cash_Pad ({describe(all, t0)})`)
check(cash.Text == "$10.1K", `K7c « $10.1K » ({cash.Text})`)
Offline.open = false

print("\n== K8. Encaissement automatique (pas de remote) : Cash_Collect, comme avant")
s0, t0 = #SOUNDS_PLAYED, now()
P1:SetAttribute("Cash", P1:GetAttribute("Cash") + 500)
P1:SetAttribute("CashCollected", P1:GetAttribute("CashCollected") + 500)
step(Flash.MatchWindow + 0.1)
all = cashSounds(s0)
check(#all == 1 and all[1].name == "Cash_Collect", `K8a Cash_Collect après MatchWindow ({describe(all, t0)})`)
step(2)
check(#cashSounds(s0) == 1, "K8b un seul son")

summary()
