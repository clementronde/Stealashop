-- Banc a82 (vague 26) : TreadmillFxController anime les tapis pendant la course seulement.
local Ctl = loadController(SOURCE)
local FX = require(ReplicatedStorage.Shared.Config.TreadmillFX)
local me = Players.LocalPlayer

-- Parcelles et tapis -------------------------------------------------------------------------------
local function newPlot(owner, x)
	local plot = newInst("Model", "Plot" .. x, workspace)
	plot:SetAttribute("OwnerUserId", owner)
	CollectionService:AddTag(plot, "PlayerPlot")
	return plot
end

local function part(name, parent, class)
	return newInst(class or "MeshPart", name, parent)
end

-- Tapis à la façon de PLOT_Treadmill_<variant> (noms relevés dans Studio le 2026-11-11).
local function newTreadmill(variant, plot, at)
	local m = newInst("Model", "Treadmill")
	setp(m, "Pivot", CFrame.new(at))
	local belt = part("Belt", m, "Part")
	newInst("Texture", "BeltTexture", belt)
	newInst("Attachment", "UsePoint", belt)
	local burst = newInst("Attachment", "RunBurstPoint", belt)
	local function emitter(name, parent, enabled)
		local e = newInst("ParticleEmitter", name, parent)
		setp(e, "Enabled", enabled)
		return e
	end
	local function fpart(name, parent, offset)
		local p = part(name, parent, "Part")
		setp(p, "CFrame", CFrame.new(at + (offset or Vector3.new())))
		return p
	end
	if variant == "Police" then
		emitter("RunStreak", burst, false)
		local fx = newInst("Folder", "PoliceFX", m)
		for _, n in { "FlareR1", "FlareR2", "FlareB1", "FlareB2" } do emitter("Flare", fpart(n, fx), true) end
		for _, n in { "Light_red", "Light_blue" } do
			local l = newInst("PointLight", "Light", fpart(n, fx))
			setp(l, "Brightness", 1.5)
		end
		for i, n in { "Sweep_red", "Sweep_blue" } do
			local p = fpart(n, fx, Vector3.new(i, 4, 0))
			newInst("SpotLight", "Spot", p)
		end
		local rt = fpart("RunTrail", fx)
		local a0 = newInst("Attachment", "RunTrail0", rt)
		local a1 = newInst("Attachment", "RunTrail1", rt)
		local tr = newInst("Trail", "Trail", rt)
		setp(tr, "Attachment0", a0)
		setp(tr, "Attachment1", a1)
		setp(part("SirenRed", m), "Color", Color3.fromHex("FF2A3A"))
		setp(part("SirenBlue", m), "Color", Color3.fromHex("2F9BFF"))
	elseif variant == "Gold" then
		emitter("RunBurst", burst, false)
		local fx = newInst("Folder", "GoldFX", m)
		for i = 1, 4 do fpart("Halo" .. i, fx, Vector3.new(i, 3, 0)) end
		newInst("PointLight", "WingLight", fpart("WingFX", fx))
		part("GoldGlow", m)
	elseif variant == "Candy" then
		emitter("RunPops", burst, false)
		emitter("RunPuff", burst, false)
		local fx = newInst("Folder", "CandyFX", m)
		for i = 1, 6 do emitter("Pop", fpart("Popper" .. i, fx), true) end
		local rt = fpart("RunTrail", fx)
		newInst("Trail", "Trail", rt)
		local pm = part("Peppermint", m)
		setp(pm, "CFrame", CFrame.new(at + Vector3.new(0, 2.45, -3.15)))
		part("BeltArrows", m)
	elseif variant == "LaserVault" then
		emitter("RunCoins", burst, false)
		local fx = newInst("Folder", "LaserVaultFX", m)
		fpart("ScanGate", fx, Vector3.new(0, 6, 4.12))
		for i = 1, 3 do
			local a = fpart("Alarm" .. i, fx)
			emitter("Flash", a, true)
			newInst("PointLight", "Light", a)
		end
		for i = 1, 9 do newInst("Beam", "Beam", fpart("Laser" .. i, fx)) end
		part("AlarmGlow", m)
	end
	m.Parent = plot
	CollectionService:AddTag(m, "Treadmill")
	return m
end

-- Instantané des propriétés d'un modèle (pour vérifier le retour exact aux valeurs d'origine).
local function snapshot(root)
	local out = {}
	local function walk(inst)
		for k, v in inst._p do out[inst] = out[inst] or {}; out[inst][k] = v end
		for _, c in inst._children do walk(c) end
	end
	walk(root)
	return out
end
local function sameAs(root, snap)
	for inst, props in snap do
		for k, v in props do
			if inst._p[k] ~= v then
				return false, inst.Name .. "." .. k
			end
		end
	end
	return true
end

local function trailsOn(player)
	local root = player.Character:FindFirstChild("HumanoidRootPart")
	local n = 0
	for _, c in root._children do if c.ClassName == "Trail" then n += 1 end end
	return n, #root._children
end

Ctl.Start()
flush()
local DT = 1 / 60

-- 1. Sans coureur : rien n'est animé, aucune écriture ---------------------------------------------
local plotMe = newPlot(1, 0)
local police = newTreadmill("Police", plotMe, Vector3.new(0, 0, 0))
local snapPolice = snapshot(police)
flush()
WRITES = 0
tick(DT, 120)
check("1 sans coureur : aucun tapis animé", Ctl.ActiveCount() == 0)
check("1 sans coureur : aucune écriture en 2 s", WRITES == 0, WRITES)
me:SetAttribute("TrainingMachine", "Bench")
tick(DT, 60)
check("1 au banc : tapis immobile", not Ctl.IsAnimating(police) and WRITES == 0, WRITES)

-- 2. Course sur le tapis Police ---------------------------------------------------------------------
me:SetAttribute("TrainingMachine", "Treadmill")
flush()
check("2 course : tapis animé dès le changement d'attribut", Ctl.IsAnimating(police))
local tex = police.Belt.BeltTexture
tick(0.1, 1)
check("2 la bande défile (9 studs/s)", math.abs(tex.OffsetStudsV - (FX.BeltSpeed * 0.1) % tex.StudsPerTileV) < 1e-6, tex.OffsetStudsV)
check("2 RunStreak allumé", police.Belt.RunBurstPoint.RunStreak.Enabled == true)
local nTrail, nKids = trailsOn(me)
check("2 RunTrail copié sur le HumanoidRootPart (Trail + 2 attaches)", nTrail == 1 and nKids == 3, nKids)
check("2 l'original du RunTrail reste éteint", police.PoliceFX.RunTrail.Trail.Enabled == false)
-- t = 0,1 : dans le premier flash rouge (0 à 0,12), bleu éteint.
check("2 flash rouge : Light_red à 6", police.PoliceFX.Light_red.Light.Brightness == 6, police.PoliceFX.Light_red.Light.Brightness)
check("2 bleu hors flash : Light_blue à 0", police.PoliceFX.Light_blue.Light.Brightness == 0)
check("2 SirenRed en couleur pleine", nearC(police.SirenRed.Color, Color3.fromHex("FF2A3A")))
local blue = Color3.fromHex("2F9BFF")
check("2 SirenBlue assombrie à 65 %", nearC(police.SirenBlue.Color, Color3.new(blue.R * 0.65, blue.G * 0.65, blue.B * 0.65)))
check("2 Emit(1) des FlareR au début du flash", police.PoliceFX.FlareR1.Flare._emits == 1 and police.PoliceFX.FlareB1.Flare._emits == 0)
tick(0.05, 8) -- t = 0,5 : premier flash bleu (0,45 à 0,57)
check("2 flash bleu : Light_blue à 6, FlareB émis", police.PoliceFX.Light_blue.Light.Brightness == 6 and police.PoliceFX.FlareB2.Flare._emits == 1)
check("2 deux flashs rouges vus (0 et 0,2)", police.PoliceFX.FlareR2.Flare._emits == 2, police.PoliceFX.FlareR2.Flare._emits)
local sweep = police.PoliceFX.Sweep_red
check("2 Sweep_red tourne sur place", not nearCF(sweep.CFrame, snapPolice[sweep].CFrame) and nearV(sweep.CFrame.Position, snapPolice[sweep].CFrame.Position))

-- 3. Fin de la course : tout revient exactement --------------------------------------------------------
me:SetAttribute("TrainingMachine", nil)
flush()
local ok, what = sameAs(police, snapPolice)
check("3 fin : valeurs d'origine rendues", ok, what)
check("3 fin : copie du trail détruite", (trailsOn(me)) == 0 and #me.Character.HumanoidRootPart._children == 0)
WRITES = 0
tick(DT, 60)
check("3 après la fin : plus rien d'animé, aucune écriture", Ctl.ActiveCount() == 0 and WRITES == 0, WRITES)

-- 4. Changement de modèle (MachineVariantService) pendant la course -----------------------------------
me:SetAttribute("TrainingMachine", "Treadmill")
tick(DT, 10)
check("4 Police animé avant l'échange", Ctl.IsAnimating(police))
police.Parent = nil -- le serveur met l'ancien de côté
local gold = newTreadmill("Gold", plotMe, Vector3.new(0, 0, 0))
local snapGold = snapshot(gold)
gold.Parent = plotMe
flush()
tick(DT, 6)
ok, what = sameAs(police, snapPolice)
check("4 l'ancien tapis est arrêté et rendu", not Ctl.IsAnimating(police) and ok, what)
check("4 copie du trail Police retirée", (trailsOn(me)) == 0)
check("4 le nouveau tapis est suivi", Ctl.IsAnimating(gold) and Ctl.ActiveCount() == 1)
check("4 Gold : RunBurst allumé, Halo1 tourne", gold.Belt.RunBurstPoint.RunBurst.Enabled and not nearCF(gold.GoldFX.Halo1.CFrame, snapGold[gold.GoldFX.Halo1].CFrame))
check("4 Gold : WingLight pulse entre 1,2 et 2,2", gold.GoldFX.WingFX.WingLight.Brightness >= 1.2 and gold.GoldFX.WingFX.WingLight.Brightness <= 2.2)

-- 5. VISUAL EFFECTS sur OFF : la bande seule ------------------------------------------------------------
me:SetAttribute("VfxEnabled", false)
flush()
tick(DT, 6)
check("5 OFF : RunBurst éteint", gold.Belt.RunBurstPoint.RunBurst.Enabled == false)
check("5 OFF : halos rendus à leur place", nearCF(gold.GoldFX.Halo1.CFrame, snapGold[gold.GoldFX.Halo1].CFrame))
check("5 OFF : WingLight rendue", gold.GoldFX.WingFX.WingLight.Brightness == snapGold[gold.GoldFX.WingFX.WingLight].Brightness)
local before = gold.Belt.BeltTexture.OffsetStudsV
tick(DT, 3)
check("5 OFF : la bande défile encore", gold.Belt.BeltTexture.OffsetStudsV ~= before)
me:SetAttribute("VfxEnabled", true)
flush()
tick(DT, 3)
check("5 ON : effets revenus", gold.Belt.RunBurstPoint.RunBurst.Enabled == true)

-- 6. Distance : un tapis loin de la caméra n'est pas animé -----------------------------------------------
workspace.CurrentCamera.CFrame = CFrame.new(0, 10, FX.ActiveDistance + 50)
tick(FX.CheckInterval, 2)
ok, what = sameAs(gold, snapGold)
check("6 loin : arrêté et rendu", not Ctl.IsAnimating(gold) and ok, what)
workspace.CurrentCamera.CFrame = CFrame.new(0, 10, 0)
tick(FX.CheckInterval, 2)
check("6 de retour près : animé", Ctl.IsAnimating(gold))

-- 7. Autre joueur : son tapis à lui, pas celui d'un autre ----------------------------------------------
local bob = newPlayer(2)
local plotBob = newPlot(2, 40)
local candy = newTreadmill("Candy", plotBob, Vector3.new(40, 0, 0))
local snapCandy = snapshot(candy)
local plotNobody = newPlot(nil, 80)
local lv = newTreadmill("LaserVault", plotNobody, Vector3.new(80, 0, 0))
flush()
bob:SetAttribute("TrainingMachine", "Treadmill")
flush()
check("7 le tapis de Bob est animé chez moi aussi", Ctl.IsAnimating(candy) and Ctl.IsAnimating(gold))
check("7 le tapis d'une parcelle sans propriétaire reste immobile", not Ctl.IsAnimating(lv))
tick(0.1, 1)
local ctex = candy.Belt.BeltTexture
check("7 Candy : la bande défile à l'envers", math.abs(ctex.OffsetStudsV - ((-FX.BeltSpeed * 0.1) % ctex.StudsPerTileV)) < 1e-6, ctex.OffsetStudsV)
check("7 Candy : trail sur le perso de Bob", (trailsOn(bob)) == 1 and (trailsOn(me)) == 0)
local pm = candy.Peppermint
check("7 Candy : Peppermint tourne autour de l'axe avant-arrière (Z inchangé)", not nearCF(pm.CFrame, snapCandy[pm].CFrame) and math.abs(pm.CFrame.Position.Z - snapCandy[pm].CFrame.Position.Z) < 1e-6)
local pops = 0
tick(0.1, 20)
for i = 1, 6 do pops += candy.CandyFX["Popper" .. i].Pop._emits end
check("7 Candy : des Popper éclatent (30 par coup)", pops > 0 and pops % FX.Candy.PopCount == 0, pops)

-- 8. Streaming : une pièce qui arrive pendant la course fait repartir le tapis, sans fausser l'origine ---
local late = newInst("Part", "LatePiece")
late.Parent = candy
tick(FX.CheckInterval, 2)
check("8 tapis repris après l'arrivée d'une pièce", Ctl.IsAnimating(candy))
bob:SetAttribute("TrainingMachine", nil)
flush()
ok, what = sameAs(candy, snapCandy)
check("8 fin : valeurs d'origine (pas celles de la course)", ok, what)
check("8 fin : trail de Bob retiré", (trailsOn(bob)) == 0)

-- 9. LaserVault : ScanGate dans le repère du tapis, alarme -------------------------------------------
local snapLv = snapshot(lv)
plotBob:SetAttribute("OwnerUserId", nil)
plotNobody:SetAttribute("OwnerUserId", 2)
bob:SetAttribute("TrainingMachine", "Treadmill")
flush()
tick(0.25, 4) -- t = 1
local y = lv.LaserVaultFX.ScanGate.CFrame.Position.Y
check("9 ScanGate à y = 3,5 + 2,5·cos(0,8 t)", math.abs(y - (3.5 + 2.5 * math.cos(0.8))) < 1e-6, y)
check("9 RunCoins allumé", lv.Belt.RunBurstPoint.RunCoins.Enabled)
local flashes = 0
for i = 1, 3 do flashes += lv.LaserVaultFX["Alarm" .. i].Flash._emits end
tick(DT, 120)
local flashes2 = 0
for i = 1, 3 do flashes2 += lv.LaserVaultFX["Alarm" .. i].Flash._emits end
check("9 Flash de l'alarme émis, au plus une fois par 0,3 s", flashes2 > flashes and flashes2 - flashes <= 3 * 7, flashes2 - flashes)
bob:SetAttribute("TrainingMachine", nil)
flush()
ok, what = sameAs(lv, snapLv)
check("9 fin : LaserVault rendu", ok, what)

-- 10. Départ du coureur ----------------------------------------------------------------------------------
me:SetAttribute("TrainingMachine", nil)
flush()
check("10 plus aucun tapis animé", Ctl.ActiveCount() == 0)

print(string.format("banc a82 (tapis animés) : %d vérification(s), %d échec(s)", CHECKS, FAILS))
