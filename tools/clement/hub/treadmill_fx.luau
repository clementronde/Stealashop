--!nocheck
--[[
	Effets des tapis texturés (MOD-016, 2026-11-08), sans script : seulement des ParticleEmitter natifs
	(un tapis est répété dans les 6 boutiques, la règle FX_ du CLAUDE.md interdit tout script dessus).
	À envoyer d'un bloc à execute_luau, en mode Edit, après treadmill_assets.luau. Relançable : les
	points d'effet d'un tapis sont refaits à chaque passage.

	Images de Clément (StealAShop-Art/Training/Treadmill/ToImport), importées au nom du groupe
	RoundStone Studio ; identifiants retrouvés par search_asset (scope group, Image).

	PLOT_Treadmill_Void :
	  - PortalPoint (dans le portique, face au coureur) : Portal (tourbillon qui tourne) et Ring
	    (anneau de runes, sens inverse), deux particules fixes qui se relaient en fondu ;
	  - FlamePoint_L et FlamePoint_R (haut des piliers arrière) : flammes violettes en flipbook 4x4 ;
	  - AuraPoint_L et AuraPoint_R (au pied des cristaux) : halos et étincelles qui montent.
	PLOT_Treadmill_Fire :
	  - FlamePoint_L et FlamePoint_R (haut des capots arrière) : flammes orange en flipbook 4x4.
	Tout est allumé en permanence ; le code peut couper ou renforcer (Enabled, Rate) pendant la course.
]]

local RS = game:GetService("ReplicatedStorage")

local IDS = {
	Portal = "rbxassetid://84512886638305", -- FX_Treadmill_Void_Portal
	Ring = "rbxassetid://116768765895475", -- FX_Treadmill_Void_Ring
	Glow = "rbxassetid://111652023541007", -- FX_Treadmill_Void_Glow
	Sparkle = "rbxassetid://98038936938675", -- FX_Treadmill_Void_Sparkle
	FlameVoid = "rbxassetid://97499105576701", -- FX_Treadmill_Flame_Void
	FlameFire = "rbxassetid://115813684641761", -- FX_Treadmill_Flame_Fire
}

local function ns(t)
	local k = {}
	for _, p in t do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2])) end
	return NumberSequence.new(k)
end

local function point(part, name, pos)
	local old = part.Parent:FindFirstChild(name, true)
	if old then old:Destroy() end
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = part
	a.WorldCFrame = CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)) -- avant de l'attache vers le coureur (+Z)
	return a
end

local function emitter(parent, name, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	for k, v in props do e[k] = v end
	e.Parent = parent
	return e
end

-- disque fixe face au coureur, qui tourne : deux particules qui se relaient en fondu
local function disc(parent, name, texture, size, rotSpeed, lightEmission, zOffset)
	return emitter(parent, name, {
		Texture = texture, Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Front, Speed = NumberRange.new(0.01), SpreadAngle = Vector2.new(0, 0),
		LockedToPart = true, Lifetime = NumberRange.new(4), Rate = 0.5,
		Size = ns({ { 0, size }, { 1, size } }), Transparency = ns({ { 0, 1 }, { 0.25, 0.05 }, { 0.75, 0.05 }, { 1, 1 } }),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(rotSpeed),
		LightEmission = lightEmission, LightInfluence = 0, ZOffset = zOffset, Brightness = 1.2,
	})
end

local function flames(parent, texture, color)
	return emitter(parent, "Flame", {
		Texture = texture, FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.Loop, FlipbookFramerate = NumberRange.new(18, 22),
		FlipbookStartRandom = true, Orientation = Enum.ParticleOrientation.FacingCameraWorldUp,
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(1, 1.6), SpreadAngle = Vector2.new(6, 6),
		Acceleration = Vector3.new(0, 2, 0), Lifetime = NumberRange.new(0.6, 0.9), Rate = 7,
		Size = ns({ { 0, 1.5 }, { 0.6, 1.3 }, { 1, 0.7 } }), Transparency = ns({ { 0, 0.15 }, { 0.75, 0.25 }, { 1, 1 } }),
		Color = ColorSequence.new(color), LightEmission = 0.7, LightInfluence = 0, Brightness = 1.3,
	})
end

local function aura(parent)
	emitter(parent, "Glow", {
		Texture = IDS.Glow, EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.6, 1.2),
		SpreadAngle = Vector2.new(35, 35), Lifetime = NumberRange.new(2, 3), Rate = 3,
		Size = ns({ { 0, 0.2 }, { 0.3, 0.7 }, { 1, 0.3 } }), Transparency = ns({ { 0, 1 }, { 0.2, 0.3 }, { 1, 1 } }),
		LightEmission = 1, LightInfluence = 0,
	})
	emitter(parent, "Sparkle", {
		Texture = IDS.Sparkle, EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(45, 45), Lifetime = NumberRange.new(0.8, 1.4), Rate = 4,
		Size = ns({ { 0, 0 }, { 0.3, 0.45 }, { 1, 0 } }), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90),
		LightEmission = 1, LightInfluence = 0,
	})
end

local plots = RS.Assets.Plots
local report = {}

local void = plots:FindFirstChild("PLOT_Treadmill_Void")
if void then
	local host = void.VoidSteel
	-- portique : ouverture x ±1,76, y 1,52..5,52 ; plaque du fond à z -3,46 (repère du tapis, avant vers -Z)
	local portal = point(host, "PortalPoint", Vector3.new(0, 3.52, -3.38))
	disc(portal, "Portal", IDS.Portal, 3.4, 35, 0.15, 0)
	disc(portal, "Ring", IDS.Ring, 3.9, -20, 1, 0.2)
	for _, s in { { "L", -1 }, { "R", 1 } } do
		local f = point(host, "FlamePoint_" .. s[1], Vector3.new(s[2] * 2.08, 2.94, 3.66)) -- haut des piliers arrière
		flames(f, IDS.FlameVoid, Color3.new(1, 1, 1))
		local a = point(host, "AuraPoint_" .. s[1], Vector3.new(s[2] * 2.6, 0.6, 0.3)) -- pied des cristaux
		aura(a)
	end
	table.insert(report, "PLOT_Treadmill_Void : portail, anneau, 2 flammes, 2 auras")
end

local fire = plots:FindFirstChild("PLOT_Treadmill_Fire")
if fire then
	local host = fire.Steel
	for _, s in { { "L", -1 }, { "R", 1 } } do
		local f = point(host, "FlamePoint_" .. s[1], Vector3.new(s[2] * 2.08, 1.32, 3.66)) -- haut des capots arrière
		flames(f, IDS.FlameFire, Color3.new(1, 1, 1))
	end
	table.insert(report, "PLOT_Treadmill_Fire : 2 flammes")
end

local missing = {}
for k, v in IDS do if v == "rbxassetid://0" then table.insert(missing, k) end end
table.insert(report, #missing == 0 and "toutes les images sont branchées" or ("images manquantes : " .. table.concat(missing, ", ")))
return table.concat(report, "\n")
