---------------------------------------------------------------- banc a401 (vague GC4, 23/11 : encaissement de la vidéo de Cantin)
-- Collé après setup.luau, setup-a60.luau et setup-a75.luau (faux Roblox d'a80). Vrais VfxController, GainController,
-- HudController, UiFeelController, CollectFeelController et UI/Motion ; DisplayController bouchonné (Fire = remote
-- CashCollect du joueur local).
SOURCES["stub/ChaseController"] = [==[
local C = { chased = false }
function C.IsChased() return C.chased end
function C.GetDistance() return nil end
function C.IsClose() return false end
function C.GetGuard() return nil end
return C
]==]
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
	for _, fn in D.listeners do
		fn(amount, slot, position)
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
for _, name in { "Cash_Pad", "Cash_Whoosh", "Cash_Tick" } do
	new("Sound", { Name = name }, SOUNDS)
end

local function named(parent, name)
	local out = {}
	for _, child in parent:GetChildren() do
		if child.Name == name then
			table.insert(out, child)
		end
	end
	return out
end
local function flyersShown()
	return #named(Workspace, "FX_Collect_Bill") + #named(Workspace, "FX_Collect_Coin")
end
local function played(name, from)
	local list = {}
	for i = (from or 0) + 1, #SOUNDS_PLAYED do
		if SOUNDS_PLAYED[i].name == name then
			table.insert(list, SOUNDS_PLAYED[i])
		end
	end
	return list
end

local VfxCfg = requireModule(ReplicatedStorage.Shared.Config.Vfx, "client")
local FEEL = UiMotionC.CollectFeel
local FOUNT = VfxCfg.Collect.Fountain
P1:SetAttribute("Cash", 100)
P1:SetAttribute("Income", 10)
P1:SetAttribute("Speed", 10)
P1:SetAttribute("Strength", 5)
P1:SetAttribute("WalkSpeed", 16)
P1:SetAttribute("Damage", 1)
P1:SetAttribute("CashCollected", 0)
local hud = makeHud()
local glow = new("ImageLabel", { Name = "CollectGlow", Visible = false, ImageTransparency = 1, Size = UDim2.fromScale(1, 1) }, hud)

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
local cash = el(hud, "Cash")
local cashRow = el(hud, "CashRow")
local pad = Vector3.new(10, 1, 5)
local ranks = {}
Vfx.OnCollectArrive(function(rank, total, wave)
	table.insert(ranks, { rank = rank, total = total, wave = wave })
end)
local function rowScale()
	local s = scaleNamed(cashRow, UiMotionC.PopScaleName)
	return if s then s.Scale else 1
end

check(UiMotionC.CashFly.Enabled == false and FEEL.Enabled == true, "A0 case qui vole coupée (comme dans le jeu), CollectFeel allumé")
print("\n== A1. Hausse de Cash avant le remote : chiffre retenu jusqu'à la 1re arrivée, fontaine, sons, vignette")
check(cash.Text == "$100", `A1a départ « $100 » ({cash.Text})`)
local s0 = #SOUNDS_PLAYED
P1:SetAttribute("Cash", 1100)
P1:SetAttribute("CashCollected", 1000)
step(1 / 60)
Display.Fire(1000, 1, pad)
step(1 / 60)
local early = flyersShown()
check(early >= 1 and early <= 2, `A1b fontaine : 1 ou 2 billets sortis à la 1re image ({early})`)
check(#played("Cash_Pad", s0) == 1 and #played("Cash_Whoosh", s0) == 1, "A1c Cash_Pad au contact, Cash_Whoosh au départ des billets")
step(0.08)
check(glow.Visible == true and glow.ImageTransparency < 0.5, `A1d vignette CollectGlow montée ({glow.ImageTransparency})`)
step(0.25)
check(flyersShown() == 7, `A1e les 7 billets sont sortis un par un ({flyersShown()})`)
check(cash.Text == "$100" and #played("Cash_Collect", s0) == 0, `A1f avant la 1re arrivée : chiffre retenu, pas de Cash_Collect ({cash.Text})`)
check(#ranks == 0, "A1g aucune arrivée encore")
-- 1re arrivée prévue à PopTime + HoverTime + FlyTime (± FlyJitter) après la sortie du 1er billet
local firstAt = FOUNT.PopTime + FOUNT.HoverTime + FOUNT.FlyTime
step(firstAt + FOUNT.FlyJitter + 0.02 - 0.35)
check(#ranks >= 1 and ranks[1].rank == 1 and ranks[1].total == 7, `A1h 1re arrivée signalée (rang 1 sur 7) vers {firstAt} s ({#ranks})`)
check(#played("Cash_Collect", s0) == 1, "A1i Cash_Collect à la 1re arrivée, une fois")
step(0.06)
check(rowScale() > 1.1, `A1j CashRow grossi à la 1re arrivée ({rowScale()})`)
check(cash.Text ~= "$100", `A1k le chiffre défile ({cash.Text})`)
step(0.5)
local ordered = #ranks == 7
for i, r in ranks do
	ordered = ordered and r.rank == i and r.total == 7
end
check(ordered, `A1l 7 arrivées signalées dans l'ordre, rang et total ({#ranks})`)
local ticks = played("Cash_Tick", s0)
check(#ticks == 6, `A1m un tic par arrivée suivante (6, {#ticks})`)
local rising = #ticks == 6
for i = 2, #ticks do
	rising = rising and ticks[i].speed > ticks[i - 1].speed
end
check(rising and near(ticks[#ticks].speed, 2 ^ (FEEL.TickSemitones / 12), 1e-3), `A1n tics de plus en plus aigus, dernier à +{FEEL.TickSemitones} demi-tons ({ticks[#ticks] and ticks[#ticks].speed})`)
step(0.4)
check(cash.Text == "$1.1K", `A1o chiffre final « $1.1K » ({cash.Text})`)
check(scaleNamed(cashRow, UiMotionC.PopScaleName) == nil, "A1p CashRow revenu à 1, UIScale retiré")
check(glow.Visible == false and glow.ImageTransparency == 1, "A1q vignette rendue à son état d'origine")
check(Vfx.GetState().Flyers == 0 and flyersShown() == 0, "A1r billets détruits")
local st = Collect.GetState()
check(st.Sessions == 0 and st.Waiting == false and st.Popped == false and st.Glows == 0, "A1s rien ne reste dans CollectFeelController")

print("\n== A2. Remote avant la hausse de Cash")
ranks = {}
s0 = #SOUNDS_PLAYED
Display.Fire(1000, 2, pad)
step(1 / 60)
P1:SetAttribute("Cash", 2100)
P1:SetAttribute("CashCollected", 2000)
step(0.3)
check(cash.Text == "$1.1K", `A2a chiffre retenu ({cash.Text})`)
step(0.5)
check(#ranks >= 1 and #played("Cash_Collect", s0) == 1 and cash.Text ~= "$1.1K", `A2b relâché à la 1re arrivée ({cash.Text})`)
step(0.8)
check(cash.Text == "$2.1K" and Collect.GetState().Sessions == 0 and not Collect.GetState().Waiting, `A2c « $2.1K », rien ne reste ({cash.Text})`)

print("\n== A3. VISUAL EFFECTS OFF : aucun billet, comme avant après FallbackDelay ; pas de vignette")
P1:SetAttribute("VfxEnabled", false)
s0 = #SOUNDS_PLAYED
P1:SetAttribute("Cash", 3100)
P1:SetAttribute("CashCollected", 3000)
step(1 / 60)
Display.Fire(1000, 1, pad)
step(1 / 60)
check(flyersShown() == 0 and glow.Visible == false, "A3a ni billet ni vignette")
step(FEEL.FallbackDelay + 0.05)
check(#played("Cash_Collect", s0) == 1, "A3b Cash_Collect après le délai de secours")
check(scaleNamed(cashRow, UiMotionC.PopScaleName) ~= nil, "A3c CashRow sursaute (CashBump)")
step(1)
check(cash.Text == "$3.1K" and not Collect.GetState().Waiting, `A3d « $3.1K » ({cash.Text})`)
P1:SetAttribute("VfxEnabled", nil)

print("\n== A4. Encaissement sans plaque (pas de remote) : relâché après FallbackDelay")
s0 = #SOUNDS_PLAYED
P1:SetAttribute("Cash", 3600)
P1:SetAttribute("CashCollected", 3500)
step(FEEL.FallbackDelay / 2)
check(cash.Text == "$3.1K", `A4a retenu un instant ({cash.Text})`)
step(FEEL.FallbackDelay)
check(#played("Cash_Collect", s0) == 1 and #played("Cash_Pad", s0) == 0, "A4b puis Cash_Collect, sans Cash_Pad")
step(1)
check(cash.Text == "$3.6K", `A4c « $3.6K » ({cash.Text})`)

print("\n== A5. Deux plaques à la suite : rien ne s'empile")
ranks = {}
s0 = #SOUNDS_PLAYED
P1:SetAttribute("Cash", 4600)
P1:SetAttribute("CashCollected", 4500)
step(1 / 60)
Display.Fire(1000, 1, pad)
step(0.3)
P1:SetAttribute("Cash", 5600)
P1:SetAttribute("CashCollected", 5500)
step(1 / 60)
Display.Fire(1000, 2, pad)
step(0.05)
check(Collect.GetState().Glows == 1 and #named(hud, "CollectGlow") == 1, "A5a une seule vignette en cours")
step(2)
check(#ranks == 14, `A5b 14 arrivées signalées ({#ranks})`)
check(#played("Cash_Collect", s0) == 2, `A5c un Cash_Collect par plaque ({#played("Cash_Collect", s0)})`)
check(cash.Text == "$5.6K", `A5d « $5.6K » ({cash.Text})`)
check(scaleNamed(cashRow, UiMotionC.PopScaleName) == nil and glow.Visible == false and glow.ImageTransparency == 1, "A5e CashRow et vignette revenus")
st = Collect.GetState()
check(st.Sessions == 0 and not st.Waiting and st.Glows == 0, "A5f rien ne reste")

print("\n== A6. « +$X » au-dessus du joueur : dépasse, tient, rétrécit jusqu'à 0")
local TEXT = FEEL.Text
step(1.5) -- CashMinGap
P1:SetAttribute("Cash", 6600)
P1:SetAttribute("CashCollected", 6500)
step(1 / 60)
Display.Fire(1000, 1, pad)
local gains = named(PLAYER_GUI, "BB_Gain")
check(#gains == 1, `A6a un BB_Gain ({#gains})`)
local bb = gains[1]
local row = bb and el(bb, "Row")
local scale = row and scaleNamed(row, "GainScale")
check(scale ~= nil and scale.Scale >= TEXT.From and scale.Scale < TEXT.From + 0.2, `A6b Row part de {TEXT.From} (une image plus tard : {scale and scale.Scale})`)
step(TEXT.InTime)
check(scale ~= nil and scale.Scale > 1.05, `A6c dépasse vers {TEXT.Over} ({scale and scale.Scale})`)
step(TEXT.SettleTime + 0.1)
check(scale ~= nil and near(scale.Scale, 1, 0.02), `A6d revient à 1 ({scale and scale.Scale})`)
local offset = bb.StudsOffset
step(TEXT.Hold - 0.1 + TEXT.OutTime / 2)
check(scale ~= nil and scale.Scale < 0.9 and bb.StudsOffset.Y > offset.Y, `A6e rétrécit en montant ({scale and scale.Scale})`)
local amount = el(bb, "Amount")
check(amount.TextTransparency == 0, "A6f sans fondu")
step(TEXT.OutTime)
check(bb.Parent == nil and #named(PLAYER_GUI, "BB_Gain") == 0, "A6g détruit à la fin")
step(1)

print("\n== A7. Retenue jamais relâchée par des billets perdus : MaxWait")
ranks = {}
P1:SetAttribute("Cash", 7600)
P1:SetAttribute("CashCollected", 7500)
step(1 / 60)
Display.Fire(1000, 1, pad)
step(0.05)
for _, m in named(Workspace, "FX_Collect_Bill") do
	m:Destroy()
end
for _, m in named(Workspace, "FX_Collect_Coin") do
	m:Destroy()
end
step(FEEL.MaxWait + 0.2)
check(cash.Text == "$7.6K" and not Collect.GetState().Waiting, `A7a relâché quand même ({cash.Text})`)
step(1)
check(Vfx.GetState().Flyers == 0, "A7b plus aucun billet")

summary()
