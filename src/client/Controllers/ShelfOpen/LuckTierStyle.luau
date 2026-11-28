--!strict
-- LuckTierStyle (client, a523, liaison L-442 ; Clément 27/11 : « plein de versions en fonction des paliers de luck ») :
-- le compteur « ×N LUCK » prend le style du palier de Clément (ReplicatedStorage/Assets/UI/LuckTiers/Tier_NN, Folder,
-- aucun script), relu à chaque changement de la chance affichée. Module d'aide (sous-dossier : le Loader ne le démarre
-- pas), utilisé par ShelfOpenController (BB_ShelfOpen.Row.Luck, icône LuckIcon) et Controllers/Reveal/Unbox
-- (BB_UnboxOdds.Odds, sans icône). Palier = le dernier Tier_n trié par MinLuck dont MinLuck ≤ la chance (Shared/LuckTiers).
--   - texte : TextColor3 = LabelColor, une copie de TextGradient (les autres UIGradient du texte éteints), chaque
--     UIStroke du texte = StrokeColor et StrokeThickness ;
--   - échelle : TextScale, rendue par scale() que l'appelant multiplie dans son UIScale (un seul UIScale par objet) ;
--     icône : un UIScale « TierScale » = IconScale ; Halo et Rays visibles selon IconHalo et IconRays (HaloGradient
--     copié sur Halo), rayons qui tournent à RaysSpeed °/s ;
--   - mouvement (Motion, MotionPeriod) comme MutationFxController : Shine (Offset X du dégradé de −1 à 1 en
--     MutationFx.ShineTime s, toutes les MotionPeriod s), Pulse (transparence des contours 0 ↔ 0,4), Spin (Rotation du
--     dégradé, un tour en MotionPeriod s) ;
--   - passage d'un palier, en montée seulement (jamais au premier affichage) : rebond Pop → 1 en PopTime s (Back Out) et
--     FX_LuckTier_<BurstLevel> (BurstLevel 0 : rien) posé où l'appelant le dit (Emit(EmitCount), lumière éteinte en
--     FadeTime, copie détruite après Duration ; deux éclats peuvent vivre ensemble) ;
--   - animations réduites (Settings.VfxReduced ou « Réduire les mouvements » de Roblox) : couleurs et tailles seulement.
-- Clear() remet le texte comme avant (couleur, contours, dégradés). Paliers absents ou interrupteur coupé : new() rend nil.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local LuckTiers = require(Shared:WaitForChild("LuckTiers"))
local MutationFx = require(Config:WaitForChild("MutationFx"))

local LuckTierStyle = {}

LuckTierStyle.Folder = { "Assets", "UI", "LuckTiers" } -- L-442 (Clément)
LuckTierStyle.FxPrefix = "FX_LuckTier_" -- L-442 : FX_LuckTier_1 à _6 dans Assets/FX
LuckTierStyle.PopTime = 0.35 -- L-442 : Pop → 1 en 0,35 s, Back Out
LuckTierStyle.RaysSpeed = 40 -- L-442 : degrés par seconde
LuckTierStyle.GradientName = "LuckTierGradient"
LuckTierStyle.IconScaleName = "TierScale"
LuckTierStyle.FxLife = 1.2 -- L-442 : Duration des éclats (repli sans attribut)
LuckTierStyle.FxEmit = 10 -- V0 : émetteur sans EmitCount (comme Config/Vfx.DefaultEmitCount)

local TAU = 2 * math.pi

export type Tier = {
	Name: string,
	MinLuck: number,
	LabelColor: Color3?,
	StrokeColor: Color3?,
	StrokeThickness: number?,
	TextScale: number,
	IconScale: number,
	IconHalo: boolean,
	IconRays: boolean,
	Motion: string,
	MotionPeriod: number,
	Pop: number,
	BurstLevel: number,
	TextGradient: UIGradient?,
	HaloGradient: UIGradient?,
}

export type Styler = {
	label: TextLabel,
	icon: GuiObject?,
	halo: GuiObject?,
	rays: GuiObject?,
	iconScale: UIScale?,
	tiers: { Tier },
	index: number, -- palier montré (0 : aucun encore)
	gradient: UIGradient?, -- copie de TextGradient posée sur le texte
	haloGradient: UIGradient?,
	strokes: { UIStroke },
	savedColor: Color3,
	savedStrokes: { [UIStroke]: { Color: Color3, Thickness: number, Transparency: number } },
	savedGradients: { [UIGradient]: boolean },
	raysRotation: number,
	popFrom: number,
	popT: number, -- avancement du rebond, ≥ PopTime : fini
	t: number,
	burstAt: (() -> CFrame?)?, -- où poser l'éclat d'un palier (nil : pas d'éclat)
	burstParent: Instance?,
	cleared: boolean,
}

local function walk(path: { string }): Instance?
	local node: Instance? = ReplicatedStorage
	for _, name in path do
		node = if node then node:FindFirstChild(name) else nil
	end
	return node
end

local function number(inst: Instance, name: string, fallback: number): number
	local value = inst:GetAttribute(name)
	return if type(value) == "number" and value == value and value < math.huge then value else fallback
end

local function color(inst: Instance, name: string): Color3?
	local value = inst:GetAttribute(name)
	return if typeof(value) == "Color3" then value else nil
end

local function gradientOf(inst: Instance, name: string): UIGradient?
	local found = inst:FindFirstChild(name)
	return if found and found:IsA("UIGradient") then found else nil
end

-- Paliers de Clément, triés par MinLuck (un Tier sans MinLuck lisible est ignoré). Relus à chaque new() : un palier
-- retouché dans Studio est pris à la prochaine ouverture.
function LuckTierStyle.Tiers(): { Tier }
	local folder = walk(LuckTierStyle.Folder)
	local out: { Tier } = {}
	if folder == nil then
		return out
	end
	for _, child in folder:GetChildren() do
		local min = child:GetAttribute("MinLuck")
		if type(min) ~= "number" or min ~= min then
			continue
		end
		local motion = child:GetAttribute("Motion")
		table.insert(out, {
			Name = child.Name,
			MinLuck = min,
			LabelColor = color(child, "LabelColor"),
			StrokeColor = color(child, "StrokeColor"),
			StrokeThickness = child:GetAttribute("StrokeThickness") :: number?,
			TextScale = math.max(number(child, "TextScale", 1), 0.1),
			IconScale = math.max(number(child, "IconScale", 1), 0.1),
			IconHalo = child:GetAttribute("IconHalo") == true,
			IconRays = child:GetAttribute("IconRays") == true,
			Motion = if type(motion) == "string" then motion else "None",
			MotionPeriod = math.max(number(child, "MotionPeriod", 2), 0.1),
			Pop = math.max(number(child, "Pop", 1), 0.1),
			BurstLevel = math.floor(number(child, "BurstLevel", 0)),
			TextGradient = gradientOf(child, "TextGradient"),
			HaloGradient = gradientOf(child, "HaloGradient"),
		})
	end
	table.sort(out, function(a: Tier, b: Tier): boolean
		return a.MinLuck < b.MinLuck
	end)
	return out
end

function LuckTierStyle.Reduced(): boolean
	local ok, value = pcall(function(): any
		local Settings = require(Config:WaitForChild("Settings")) :: any
		if Settings.VfxReduced(Players.LocalPlayer) then
			return true
		end
		return (GuiService :: any).ReducedMotionEnabled
	end)
	return ok and value == true
end

local function backOut(t: number): number
	local x = math.clamp(t, 0, 1) - 1
	local c1 = 1.70158
	return 1 + (c1 + 1) * x * x * x + c1 * x * x
end

-- Éclat d'un palier, comme VfxController.burst : émetteurs à Rate 0 lancés une fois (EmitCount), lumières allumées
-- puis éteintes en FadeTime, copie détruite après Duration. Modèle absent : rien.
function LuckTierStyle.Burst(level: number, frame: CFrame, parent: Instance?): Instance?
	if level < 1 then
		return nil
	end
	local fx = walk({ "Assets", "FX" })
	local template = if fx then fx:FindFirstChild(LuckTierStyle.FxPrefix .. tostring(level), true) else nil
	if template == nil or not template:IsA("PVInstance") then
		return nil
	end
	local copy = template:Clone()
	for _, d in copy:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("ModuleScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	copy:PivotTo(frame)
	copy.Parent = parent or Workspace
	for _, d in copy:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			d:Emit(math.floor(number(d, "EmitCount", LuckTierStyle.FxEmit)))
		elseif d:IsA("Light") then
			local fade = number(d, "FadeTime", 0)
			d.Enabled = true
			if fade > 0 then
				TweenService:Create(d, TweenInfo.new(fade, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
			else
				d.Enabled = false
			end
		end
	end
	task.delay(number(copy, "Duration", LuckTierStyle.FxLife), function()
		copy:Destroy()
	end)
	return copy
end

-- Styler du texte `label` (et de l'icône `icon`, facultative : ses enfants Halo et Rays). `burstAt` : où poser
-- l'éclat d'un palier franchi (nil : aucun éclat). nil si l'interrupteur est coupé ou qu'aucun palier n'est livré.
function LuckTierStyle.new(label: TextLabel, icon: GuiObject?, burstAt: (() -> CFrame?)?, burstParent: Instance?): Styler?
	if not LuckTiers.on() then
		return nil
	end
	local tiers = LuckTierStyle.Tiers()
	if #tiers == 0 then
		return nil
	end
	local strokes: { UIStroke } = {}
	local savedStrokes = {}
	local savedGradients: { [UIGradient]: boolean } = {}
	for _, child in label:GetChildren() do
		if child:IsA("UIStroke") then
			table.insert(strokes, child)
			savedStrokes[child] = { Color = child.Color, Thickness = child.Thickness, Transparency = child.Transparency }
		elseif child:IsA("UIGradient") then
			savedGradients[child] = child.Enabled
		end
	end
	local halo = if icon then icon:FindFirstChild("Halo") else nil
	local rays = if icon then icon:FindFirstChild("Rays") else nil
	local iconScale: UIScale? = nil
	if icon then
		local existing = icon:FindFirstChild(LuckTierStyle.IconScaleName)
		if existing and existing:IsA("UIScale") then
			iconScale = existing
		else
			local made = Instance.new("UIScale")
			made.Name = LuckTierStyle.IconScaleName
			made.Parent = icon
			iconScale = made
		end
	end
	return {
		label = label,
		icon = icon,
		halo = if halo and halo:IsA("GuiObject") then halo else nil,
		rays = if rays and rays:IsA("GuiObject") then rays else nil,
		iconScale = iconScale,
		tiers = tiers,
		index = 0,
		gradient = nil,
		haloGradient = nil,
		strokes = strokes,
		savedColor = label.TextColor3,
		savedStrokes = savedStrokes,
		savedGradients = savedGradients,
		raysRotation = if rays and rays:IsA("GuiObject") then rays.Rotation else 0,
		popFrom = 1,
		popT = math.huge,
		t = 0,
		burstAt = burstAt,
		burstParent = burstParent,
		cleared = false,
	}
end

local function mins(styler: Styler): { number }
	local out: { number } = {}
	for index, tier in styler.tiers do
		out[index] = tier.MinLuck
	end
	return out
end

local function apply(styler: Styler, tier: Tier)
	local label = styler.label
	if styler.gradient then
		styler.gradient:Destroy()
		styler.gradient = nil
	end
	for gradient in styler.savedGradients do
		gradient.Enabled = false
	end
	label.TextColor3 = tier.LabelColor or styler.savedColor
	if tier.TextGradient then
		local copy = tier.TextGradient:Clone()
		copy.Name = LuckTierStyle.GradientName
		copy.Enabled = true
		copy.Parent = label
		styler.gradient = copy
	end
	for _, stroke in styler.strokes do
		local saved = styler.savedStrokes[stroke]
		stroke.Color = tier.StrokeColor or saved.Color
		local thickness = tier.StrokeThickness
		stroke.Thickness = if type(thickness) == "number" and thickness >= 0 then thickness else saved.Thickness
		stroke.Transparency = saved.Transparency
	end
	if styler.iconScale then
		styler.iconScale.Scale = tier.IconScale
	end
	local halo = styler.halo
	if halo then
		halo.Visible = tier.IconHalo
		if styler.haloGradient then
			styler.haloGradient:Destroy()
			styler.haloGradient = nil
		end
		if tier.IconHalo and tier.HaloGradient then
			local copy = tier.HaloGradient:Clone()
			copy.Name = LuckTierStyle.GradientName
			copy.Enabled = true
			copy.Parent = halo
			styler.haloGradient = copy
		end
	end
	if styler.rays then
		styler.rays.Visible = tier.IconRays
	end
end

-- Chance affichée `value` : le palier change ? Style posé, et en montée (jamais au premier affichage) : rebond et éclat.
function LuckTierStyle.Set(styler: Styler, value: number)
	if styler.cleared then
		return
	end
	local index = math.max(LuckTiers.pick(mins(styler), value), 1)
	if index == styler.index then
		return
	end
	local rising = styler.index > 0 and index > styler.index
	styler.index = index
	local tier = styler.tiers[index]
	apply(styler, tier)
	if rising and not LuckTierStyle.Reduced() then
		if tier.Pop ~= 1 then
			styler.popFrom = tier.Pop
			styler.popT = 0
		end
		local at = if styler.burstAt then styler.burstAt() else nil
		if at and tier.BurstLevel > 0 then
			LuckTierStyle.Burst(tier.BurstLevel, at, styler.burstParent)
		end
	end
end

-- Échelle du texte à rendre par l'appelant : TextScale du palier × le rebond en cours.
function LuckTierStyle.Scale(styler: Styler): number
	local tier = styler.tiers[styler.index]
	if tier == nil or styler.cleared then
		return 1
	end
	local pop = 1
	if styler.popT < LuckTierStyle.PopTime then
		pop = styler.popFrom + (1 - styler.popFrom) * backOut(styler.popT / LuckTierStyle.PopTime)
	end
	return tier.TextScale * pop
end

-- Mouvements du palier (Shine, Pulse, Spin), rayons, rebond. Animations réduites : rien ne bouge.
function LuckTierStyle.Step(styler: Styler, dt: number)
	local tier = styler.tiers[styler.index]
	if tier == nil or styler.cleared then
		return
	end
	styler.t += dt
	styler.popT += dt
	if LuckTierStyle.Reduced() then
		styler.popT = math.huge
		return
	end
	local t = styler.t
	local period = tier.MotionPeriod
	local gradient = styler.gradient
	if tier.Motion == "Shine" and gradient then
		local sweep = MutationFx.ShineTime
		local cycle = math.max(period, sweep)
		local p = t % cycle
		gradient.Offset = Vector2.new(if p < sweep then -1 + 2 * p / sweep else -1, gradient.Offset.Y)
	elseif tier.Motion == "Pulse" then
		local wave = 0.5 - 0.5 * math.cos(TAU * t / period)
		for _, stroke in styler.strokes do
			stroke.Transparency = MutationFx.PulseStrokeTransparency * wave
		end
	elseif tier.Motion == "Spin" and gradient then
		gradient.Rotation = (360 * ((t / period) % 1)) % 360
	end
	local rays = styler.rays
	if rays and rays.Visible then
		rays.Rotation = (styler.raysRotation + LuckTierStyle.RaysSpeed * t) % 360
	end
end

-- Le texte redevient comme avant (la cote « 1 IN N » prend la place de la chance, ou la scène finit).
function LuckTierStyle.Clear(styler: Styler)
	if styler.cleared then
		return
	end
	styler.cleared = true
	local label = styler.label
	label.TextColor3 = styler.savedColor
	if styler.gradient then
		styler.gradient:Destroy()
		styler.gradient = nil
	end
	for gradient, enabled in styler.savedGradients do
		gradient.Enabled = enabled
	end
	for stroke, saved in styler.savedStrokes do
		stroke.Color = saved.Color
		stroke.Thickness = saved.Thickness
		stroke.Transparency = saved.Transparency
	end
	if styler.haloGradient then
		styler.haloGradient:Destroy()
		styler.haloGradient = nil
	end
	if styler.iconScale then
		styler.iconScale.Scale = 1
	end
end

return LuckTierStyle
