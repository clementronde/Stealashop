-- Banc a90 (vague 29, 2026-11-12) : tapis au repos (L-106 point 7) et variante Void (L-106 point 11).
local Ctl = loadController(SOURCE)
local FX = require(ReplicatedStorage.Shared.Config.TreadmillFX)
local me = Players.LocalPlayer
local DT = 1 / 60

local function newPlot(owner, x)
	local plot = newInst("Model", "Plot" .. x, workspace)
	plot:SetAttribute("OwnerUserId", owner)
	CollectionService:AddTag(plot, "PlayerPlot")
	return plot
end
local function newTreadmill(plot, at, fxName, withTexture)
	local m = newInst("Model", "Treadmill")
	setp(m, "Pivot", CFrame.new(at))
	local belt = newInst("Part", "Belt", m)
	if withTexture ~= false then newInst("Texture", "BeltTexture", belt) end
	newInst("Attachment", "RunBurstPoint", belt)
	if fxName then newInst("Folder", fxName, m) end
	m.Parent = plot
	CollectionService:AddTag(m, "Treadmill")
	return m
end
local function off(name, parent, class)
	local e = newInst(class or "ParticleEmitter", name, parent)
	setp(e, "Enabled", false)
	return e
end
local function near(a, b) return math.abs(a - b) < 1e-4 end

check("R0 Config : IdleBeltSpeed = 3 studs/s, BeltSpeed = 9", FX.IdleBeltSpeed == 3 and FX.BeltSpeed == 9, FX.IdleBeltSpeed)
Ctl.Start()
flush()

-- R. Tapis au repos -----------------------------------------------------------------------------------
local plotMe = newPlot(1, 0)
local base = newTreadmill(plotMe, Vector3.new(0, 0, 0))
local free = newTreadmill(newPlot(0, 1), Vector3.new(20, 0, 0), "CandyFX") -- parcelle libre, Candy
local bare = newTreadmill(newPlot(0, 2), Vector3.new(40, 0, 0), nil, false) -- sans BeltTexture
flush()
local tex = base.Belt.BeltTexture
local tile = tex.StudsPerTileV
tick(DT, 60)
check("R1 sans coureur : le tapis est au repos, pas animé", Ctl.IsIdling(base) and not Ctl.IsAnimating(base) and Ctl.ActiveCount() == 0)
check("R2 au repos : la bande défile à 3 studs/s", near(tex.OffsetStudsV, (FX.IdleBeltSpeed * 60 * DT) % tile), tex.OffsetStudsV)
local ctex = free.Belt.BeltTexture
check("R3 tapis d'une parcelle libre aussi, Candy à l'envers", Ctl.IsIdling(free) and near(ctex.OffsetStudsV, (-FX.IdleBeltSpeed * 60 * DT) % tile), ctex.OffsetStudsV)
check("R4 sans BeltTexture : rien, sans erreur", not Ctl.IsIdling(bare))

me:SetAttribute("TrainingMachine", "Treadmill")
flush()
local from = tex.OffsetStudsV
tick(0.1, 1)
check("R5 en course : plus au repos, animé", not Ctl.IsIdling(base) and Ctl.IsAnimating(base))
check("R6 en course : la bande repart d'où elle était, à 9 studs/s", near(tex.OffsetStudsV, (from + FX.BeltSpeed * 0.1) % tile), tex.OffsetStudsV)
check("R7 l'autre tapis reste au repos", Ctl.IsIdling(free))

me:SetAttribute("TrainingMachine", nil)
flush()
check("R8 fin de course : bande rendue, puis de nouveau au repos", Ctl.IsIdling(base) and not Ctl.IsAnimating(base) and near(tex.OffsetStudsV, from))
workspace.CurrentCamera.CFrame = CFrame.new(0, 10, FX.ActiveDistance + 50)
tick(FX.CheckInterval, 1)
check("R9 loin de la caméra : plus de défilement", not Ctl.IsIdling(base) and not Ctl.IsIdling(free))
local still = tex.OffsetStudsV
tick(DT, 30)
check("R10 loin : la bande ne bouge plus", tex.OffsetStudsV == still)
workspace.CurrentCamera.CFrame = CFrame.new(0, 10, 0)
tick(FX.CheckInterval, 1)
check("R11 de retour près : au repos", Ctl.IsIdling(base))

-- V. Void : RunBurst allumé en course, éteint au repos -----------------------------------------------
local function swap(newModel)
	base.Parent = nil
	base = newModel
	flush()
end
-- V1 : RunBurst émetteur sous VoidFX/Portal ; le portail (allumé par Clément) n'est pas touché.
local void = newTreadmill(nil, Vector3.new(0, 0, 0), "VoidFX")
local portal = newInst("Part", "Portal", void.VoidFX)
local portalFx = newInst("ParticleEmitter", "Portal", portal)
local burst = off("RunBurst", portal)
void.Parent = plotMe
swap(void)
check("V1 Void au repos : RunBurst éteint", burst.Enabled == false and Ctl.IsIdling(void))
me:SetAttribute("TrainingMachine", "Treadmill")
tick(DT, 2)
check("V2 Void en course : RunBurst (sous VoidFX) allumé", Ctl.IsAnimating(void) and burst.Enabled == true)
check("V3 le portail garde son état", portalFx.Enabled == true)
me:SetAttribute("TrainingMachine", nil)
flush()
check("V4 fin de course : RunBurst éteint de nouveau", burst.Enabled == false and not Ctl.IsAnimating(void))

-- V5 : RunBurst dossier (émetteur + lumière éteints) sous Belt/RunBurstPoint.
local void2 = newTreadmill(nil, Vector3.new(0, 0, 0), "VoidFX")
local folder = newInst("Folder", "RunBurst", void2.Belt.RunBurstPoint)
local e2 = off("Sparks", folder)
local l2 = off("Light", folder, "PointLight")
void2.Parent = plotMe
swap(void2)
me:SetAttribute("TrainingMachine", "Treadmill")
tick(DT, 2)
check("V5 RunBurst en dossier : émetteur et lumière allumés", e2.Enabled == true and l2.Enabled == true)
me:SetAttribute("TrainingMachine", nil)
flush()
check("V6 fin : émetteur et lumière éteints", e2.Enabled == false and l2.Enabled == false)

-- V7 : Void sans RunBurst (Studio pas relevé) : course normale, sans erreur.
local void3 = newTreadmill(nil, Vector3.new(0, 0, 0), "VoidFX")
void3.Parent = plotMe
swap(void3)
me:SetAttribute("TrainingMachine", "Treadmill")
tick(DT, 5)
check("V7 Void sans RunBurst : tapis animé, aucune erreur", Ctl.IsAnimating(void3))
me:SetAttribute("TrainingMachine", nil)
flush()

print(string.format("banc a90 (tapis au repos, Void) : %d vérification(s), %d échec(s)", CHECKS, FAILS))
