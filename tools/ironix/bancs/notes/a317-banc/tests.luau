-- Banc a317 (L-299, L-304 point 3) : fonctions pures exécutées depuis les sources, puis contrôles du texte des sources.
-- SOURCES[chemin] = texte (sans \r), VERBOSE : posés par run.sh avant ce fichier.

local checks, fails = 0, 0

local function check(cond: boolean, label: string)
	checks += 1
	if cond then
		if VERBOSE then
			print("ok    " .. label)
		end
	else
		fails += 1
		print("ÉCHEC " .. label)
	end
end

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-6)
end

local function src(name: string): string
	local s = SOURCES[name]
	assert(type(s) == "string", "source absente : " .. name)
	return s
end

local function has(name: string, needle: string): boolean
	return string.find(src(name), needle, 1, true) ~= nil
end

local function count(name: string, needle: string): number
	local s = src(name)
	local n, i = 0, 1
	while true do
		local a, b = string.find(s, needle, i, true)
		if a == nil then
			break
		end
		n += 1
		i = (b :: number) + 1
	end
	return n
end

-- Texte d'une fonction de premier niveau : de `header` jusqu'au premier « end » en début de ligne.
local function body(name: string, header: string): string
	local s = src(name)
	local a = string.find(s, header, 1, true)
	assert(a ~= nil, header .. " absent de " .. name)
	local b = string.find(s, "\nend\n", a, true)
	assert(b ~= nil, "fin de " .. header .. " introuvable dans " .. name)
	return string.sub(s, a :: number, (b :: number) + 4)
end

local function contains(text: string, needle: string): boolean
	return string.find(text, needle, 1, true) ~= nil
end

------------------------------------------------------------------------------
-- Config/CashFlash et Config/DisplayMotion (vrais modules, DeepFreeze compris)
------------------------------------------------------------------------------

local DEEP = (assert(loadstring(src("shared/Config/DeepFreeze.luau"), "DeepFreeze")) :: any)()
local function config(name: string): any
	local chunk = assert(loadstring("local script, require = ...\n" .. src("shared/Config/" .. name .. ".luau"), name)) :: any
	local fakeScript = { Parent = { DeepFreeze = "DeepFreeze" } }
	return chunk(fakeScript, function(x: any): any
		assert(x == "DeepFreeze", "require inattendu dans Config/" .. name)
		return DEEP
	end)
end

local CashFlash = config("CashFlash")
local DisplayMotion = config("DisplayMotion")

check(CashFlash.Enabled == true, "C1 CashFlash.Enabled")
check(CashFlash.Screen == "UI_CashFlash" and CashFlash.Container == "EdgeGlow", "C2 écran UI_CashFlash.EdgeGlow")
check(#CashFlash.Bands == 4 and table.find(CashFlash.Bands, "Top") ~= nil and table.find(CashFlash.Bands, "Bottom") ~= nil
	and table.find(CashFlash.Bands, "Left") ~= nil and table.find(CashFlash.Bands, "Right") ~= nil, "C3 bandes Top, Bottom, Left, Right")
check(near(CashFlash.Strength, 0.45) and CashFlash.RankSpan == 7 and near(CashFlash.RankWindow, 2), "C4 voile : 0,45, rang sur 7, tournée de 2 s (L-299)")
check(near(CashFlash.InTime, 0.06) and near(CashFlash.HoldTime, 0.18) and near(CashFlash.OutTime, 0.45), "C5 voile : 0,06 / 0,18 / 0,45 s (L-299)")
check(near(CashFlash.RollTime, 0.3) and near(CashFlash.PopScale, 1.15) and near(CashFlash.PopUpTime, 0.08) and near(CashFlash.PopDownTime, 0.3), "C6 compteur : 0,3 s, ×1,15 en 0,08 puis 0,3 s (L-299)")
check(CashFlash.Sound == "Cash_Pad" and near(CashFlash.PitchJitter, 0.03), "C7 son Cash_Pad ± 3 %")
check(CashFlash.MatchWindow > 0 and CashFlash.LandTimeout > CashFlash.MatchWindow, "C8 fenêtres d'appariement positives")
check(table.isfrozen(CashFlash), "C9 Config/CashFlash gelé")

check(DisplayMotion.Enabled == true, "M1 DisplayMotion.Enabled")
check(near(DisplayMotion.FloatGap, 0.6) and near(DisplayMotion.BobHeight, 0.3) and near(DisplayMotion.BobPeriod, 2.6) and near(DisplayMotion.PhaseStep, 0.7), "M2 flottement 0,6 ± 0,3, 2,6 s, 0,7 rad (prototype)")
check(near(DisplayMotion.SpinTime, 0.7) and DisplayMotion.Hops == 2 and near(DisplayMotion.HopHeight, 0.9) and near(DisplayMotion.HopDecay, 0.45), "M3 tour 0,7 s, 2 sauts 0,9 puis × 0,45 (prototype)")
check(DisplayMotion.MaxDistance == 120, "M4 coupé au loin à 120 studs (ANIMATION_DISTANCE)")
check(DisplayMotion.BillboardAtTop == true and near(DisplayMotion.BillboardTopOffset, -0.15) and DisplayMotion.BillboardStudsOffset == 0, "M5 BB_Item au sommet −0,15, StudsOffset 0")
check(near(DisplayMotion.Headroom, 1.8), "M6 hauteur gardée libre : 1,8 stud")
check(near(12.5 - DisplayMotion.Headroom, 10.7), "M7 FitSize Y 12,5 → 10,7 de hauteur pour l'objet (chiffre de Clément, Q2)")
check(table.isfrozen(DisplayMotion), "M8 Config/DisplayMotion gelé")

------------------------------------------------------------------------------
-- GainController.FlashRank et FlashGoal (texte des sources, exécuté)
------------------------------------------------------------------------------

local G = "client/Controllers/GainController.luau"
local gainChunk = "local CashFlash, GainController = ...\n"
	.. body(G, "function GainController.FlashRank(")
	.. body(G, "function GainController.FlashGoal(")
	.. "return GainController\n"
local Gain = (assert(loadstring(gainChunk, "GainPure")) :: any)(CashFlash, {})

check(Gain.FlashRank(0, math.huge) == 1, "R1 première plaque : rang 1")
check(Gain.FlashRank(1, 0.5) == 2, "R2 plaque suivante sous 2 s : rang 2")
check(Gain.FlashRank(2, 1.9) == 3, "R3 encore sous 2 s : rang 3")
check(Gain.FlashRank(3, 2.0) == 1, "R4 à 2 s : remis à 1")
check(Gain.FlashRank(7, 5) == 1, "R5 longtemps après : remis à 1")
local rank = 0
for _ = 1, 10 do
	rank = Gain.FlashRank(rank, 0.45)
end
check(rank == 10, "R6 dix plaques à 0,45 s d'écart : rang 10")

check(near(Gain.FlashGoal(0.25, 1), 0.25 + 0.75 * 0.45), "T1 rang 1 : posée + (1 − posée) × 0,45")
check(near(Gain.FlashGoal(0.25, 4), 0.25 + 0.75 * 0.45 * (1 - 3 / 7)), "T2 rang 4 : (1 − 3/7)")
check(near(Gain.FlashGoal(0.25, 8), 0.25), "T3 rang 8 : voile à son plus fort (transparence posée)")
check(near(Gain.FlashGoal(0.25, 30), 0.25), "T4 au-delà du rang 8 : reste au plus fort")
check(Gain.FlashGoal(0.25, 2) < Gain.FlashGoal(0.25, 1), "T5 le voile se renforce le long de la rangée")

------------------------------------------------------------------------------
-- ItemIdleController.FloatMotion (texte des sources, exécuté)
------------------------------------------------------------------------------

local I = "client/Controllers/ItemIdleController.luau"
local idleChunk = "local DisplayMotion, ItemIdleController = ...\nlocal TAU = 2 * math.pi\n"
	.. body(I, "function ItemIdleController.FloatMotion(")
	.. "return ItemIdleController\n"
local Idle = (assert(loadstring(idleChunk, "IdlePure")) :: any)(DisplayMotion, {})

local h, a = Idle.FloatMotion(0, 0, nil)
check(near(h, 0) and a == 0, "F1 t = 0, phase 0 : hauteur 0, pas de tour")
h, a = Idle.FloatMotion(2.6 / 4, 0, nil)
check(near(h, 0.3) and a == 0, "F2 quart de période : +0,3 stud")
h = Idle.FloatMotion(3 * 2.6 / 4, 0, nil)
check(near(h, -0.3), "F3 trois quarts : −0,3 stud")
h = Idle.FloatMotion(0, 0.7, nil)
check(near(h, 0.3 * math.sin(0.7)), "F4 place suivante : décalée de 0,7 rad")
h = Idle.FloatMotion(1000 * 2.6, 0, nil)
check(near(h, 0, 1e-4), "F5 après 1000 périodes : pas de dérive")
h, a = Idle.FloatMotion(0, 0, 0.175)
check(near(h, 0.9) and near(a, (1 - 0.75 * 0.75) * 2 * math.pi), "F6 au quart du tour : sommet du 1er saut (0,9), tour Quad Out")
h, a = Idle.FloatMotion(0, 0, 0.35)
check(near(h, 0) and near(a, 0.75 * 2 * math.pi), "F7 à mi-tour : entre deux sauts, 3/4 de tour")
h = Idle.FloatMotion(0, 0, 0.525)
check(near(h, 0.9 * 0.45), "F8 aux 3/4 : sommet du 2e saut (0,9 × 0,45)")
h, a = Idle.FloatMotion(0, 0, 0.7)
check(near(h, 0) and a == 0, "F9 à 0,7 s : tour fini, plus de saut")
h, a = Idle.FloatMotion(0, 0, -0.1)
check(near(h, 0) and a == 0, "F10 avant l'encaissement : rien")
local highest = 0
for step = 0, 700 do
	local t = step / 1000
	local hh = Idle.FloatMotion(2.6 / 4, 0, t)
	highest = math.max(highest, hh)
end
check(highest <= DisplayMotion.BobHeight + DisplayMotion.HopHeight + 1e-6, "F11 jamais plus haut que flottement + saut (Headroom − FloatGap)")

------------------------------------------------------------------------------
-- Contrôles du texte des sources
------------------------------------------------------------------------------

-- Compteur retenu jusqu'au premier billet, Cash_Pad à la place de Cash_Collect sur une plaque.
local padJuice = body(G, "local function padJuice(")
check(not contains(padJuice, "FLY.Sound"), "S1 plaque : Cash_Collect (FLY.Sound) n'est plus joué")
check(contains(padJuice, "padSound()") and contains(padJuice, "padPop(refs)"), "S2 plaque : Cash_Pad et CashRow ×1,15 à l'arrivée")
check(contains(padJuice, "SetNextCashRoll") and contains(padJuice, "releaseAll(releases)"), "S3 plaque : Cash relâché à l'arrivée, défilement de RollTime")
check(contains(padJuice, "note.onLand = go") and contains(padJuice, "if note.landed then"), "S4 plaque : attend le premier billet (ou part s'il est déjà arrivé)")
check(contains(padJuice, "task.delay(CashFlash.LandTimeout, go)"), "S5 plaque : filet de sécurité LandTimeout")
check(contains(padJuice, "showGain(CASH, total)"), "S6 « +$X » au-dessus du joueur gardé")
local classic = body(G, "function classic(")
check(contains(classic, "Motion.PlaySound(FLY.Sound)"), "S7 autres gains (encaissement automatique) : Cash_Collect encore joué")
local classify = body(G, "local function classify(")
check(contains(classify, "if fromPad and FLASH_ON and not screenOpen(offline) then") and contains(classify, "padOrClassic(total, releases)"), "S8 hausse de CashCollected hors gains hors ligne : d'abord une plaque ?")
local padOrClassic = body(G, "local function padOrClassic(")
check(contains(padOrClassic, "classic(waiting.total, waiting.releases, true)") and contains(padOrClassic, "CashFlash.MatchWindow"), "S9 sans plaque vue (encaissement automatique) : comme avant, après MatchWindow")
local onPadCollect = body(G, "local function onPadCollect(")
check(contains(onPadCollect, "flashVeil") and contains(onPadCollect, "GainController.FlashRank(flashRank, now - flashLastAt)"), "S10 voile et rang à chaque plaque du joueur local")
check(has(G, "(onLanded :: any)(onPadLanded)") and has(G, "(onCollect :: any)(onPadCollect)"), "S11 GainController branché sur OnCollectLanded et OnCollect")
local flashVeil = body(G, "local function flashVeil(")
check(contains(flashVeil, "screen.Enabled = true") and contains(flashVeil, "screen.Enabled = false") and contains(flashVeil, "mine ~= flashToken"), "S12 voile allumé, relancé par une nouvelle plaque, éteint à la fin")

-- Billets : premier arrivé, ou tout de suite sans billets.
local V = "client/Controllers/VfxController.luau"
local collect = body(V, "function VfxController.Collect(")
check(count(V, "task.defer(land, group)") == 3, "S13 sans billets (effets coupés, modèles absents, compteur hors écran) : tout de suite")
check(count(V, "land(group)") == 2, "S14 premier billet arrivé (ou retiré) : land")
check(contains(collect, "Group = group"), "S15 chaque billet connaît son Collect")
check(has(V, "function VfxController.OnCollectLanded("), "S16 VfxController.OnCollectLanded")
check(has("client/Controllers/HudController.luau", "function HudController.SetNextCashRoll("), "S17 HudController.SetNextCashRoll")

-- Le tour et les sauts : chez tous les joueurs, pour les objets de la plaque vidée.
local D = "client/Controllers/DisplayController.luau"
local onCashCollect = body(D, "local function onCashCollect(")
check(contains(onCashCollect, "pcall(hopItems :: any, plot, slotIndex)"), "S18 encaissement d'une plaque : tour et sauts de ses objets")
check(contains(onCashCollect, "plot:GetAttribute(OWNER_ATTRIBUTE) == localPlayer.UserId"), "S19 OnCollect (voile, compteur, son) : propriétaire seulement")
check(string.find(onCashCollect, "hopItems", 1, true) < string.find(onCashCollect, "OWNER_ATTRIBUTE", 1, true), "S20 tour et sauts avant le test du propriétaire (tous les joueurs, Q3)")
check(has(I, "function ItemIdleController.Hop(") and has(I, "function ItemIdleController.WithRest("), "S21 ItemIdleController.Hop et WithRest")
check(has(I, "local move = if entryPart.halo then shift elseif piece then piece.current else whole"), "S22 le halo suit la hauteur, sans tourner")
check(has(I, "ToObjectSpace(shift * point.restWorld)"), "S23 BB_Item (BillboardPoint) suit la hauteur")
check(has(I, "local lift = if float then DisplayMotion.FloatGap - (if seenBox then minY else 0) else 0"), "S24 bas de la boîte à FloatGap au-dessus du présentoir")
check(has(I, "(slot - 1) * DisplayMotion.PhaseStep"), "S25 décalage de PhaseStep d'une place à l'autre")
check(has("client/Controllers/MutationFxController.luau", "DISPLAY_FLOATS and CollectionService:HasTag(model, \"DisplayItem\")"), "S26 MutationFx : un objet exposé compte comme animé")
check(has(V, "(itemIdle.WithRest :: any)(source, function()"), "S27 socle BEST ITEM : copie prise au repos")

-- Serveur : rien ne bouge, hauteur retirée du FitSize, BB_Item au sommet, Weight.
local S = "server/Services/DisplayService.luau"
check(has(S, "local room = fitBox.Y - DisplayMotion.Headroom - bob") and has(S, "fitFactor(display, pivot, fitBox)"), "S28 FitSize : hauteur du mouvement retirée (Q2)")
check(has(S, "top + Vector3.new(0, DisplayMotion.BillboardTopOffset, 0)"), "S29 BB_Item accroché au sommet de la boîte −0,15")
check(has(S, "gui.StudsOffset = Vector3.new(0, DisplayMotion.BillboardStudsOffset, 0)"), "S30 BB_Item : StudsOffset 0")
check(has(S, "string.upper(ItemWeight.Format(weight))"), "S31 Weight : vrai poids en capitales (« 20 KG »)")
check(has(S, "(weightField :: GuiObject).Visible = true") and has(S, "(weightField :: GuiObject).Visible = false"), "S32 Weight montré avec un poids, caché sans")
check(not has(S, "Hop("), "S33 le serveur ne fait ni tour ni saut")
check(count(S, "Net.Server.CashCollect:FireAll(plotIndex, slot, amount)") == 1, "S34 CashCollect toujours envoyé à tous (L-091)")

-- Contrat UI.
local U = "shared/Contract/UI.luau"
check(count(U, "Name = \"UI_CashFlash\"") == 1, "S35 UI_CashFlash au contrat, une seule fois")
check(has(U, "Path = \"EdgeGlow.Top\"") and has(U, "Path = \"EdgeGlow.Right\""), "S36 bandes du voile au contrat (facultatives)")

print(string.format("%d vérification(s), %d échec(s)", checks, fails))
