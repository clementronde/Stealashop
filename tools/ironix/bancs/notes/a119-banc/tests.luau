-- Scénarios du banc a119 (vague 34, L-127 point 5) : MutationFxController, styles du texte et effets des objets.

---------------------------------------------------------------- arbre du jeu
local Shared = folder(ReplicatedStorage, "Shared")
local ConfigF = folder(Shared, "Config")
for _, m in { "DeepFreeze", "MutationFx", "Mutations" } do
	moduleScript(ConfigF, m, "shared/Config/" .. m .. ".luau")
end
local Client = folder(newInstance("Folder"), "Client")
local Controllers = folder(Client, "Controllers")
local FxModule = moduleScript(Controllers, "MutationFxController", "client/Controllers/MutationFxController.luau")

local function inst(class, parent, name, props)
	local o = newInstance(class)
	o.Name = name
	for k, v in props or {} do
		o[k] = v
	end
	if parent then
		o.Parent = parent
	end
	return o
end
local function hex(h)
	return Color3.fromHex(h)
end
local function str(v)
	return tostring(v)
end

-- Assets de Clément (relevé de Studio du 2026-11-13 : mutations_style_build, mutations_fx_build).
local Assets = folder(ReplicatedStorage, "Assets")
local UIF = folder(Assets, "UI")
local Styles = folder(UIF, "MutationStyles")
local STYLE = {
	Gold = { "FFFFFF", "6B3A00", "Shine", 2, 20 },
	Neon = { "FFFFFF", "3B0057", "Pulse", 1.6, 0 },
	Glitch = { "FFFFFF", "000000", "Glitch", 0.8, 0 },
	Hacked = { "7CFF6B", "001A05", "Scan", 1.5, 90 },
	Rainbow = { "FFFFFF", "2B1240", "Spin", 3, 0 },
	Shiny = { "FFFFFF", "2E3B5C", "Shine", 2.5, 20 },
	Diamond = { "FFFFFF", "0C2F5C", "Shine", 1.5, 20 },
	Size = { "FFFFFF", "1F2C40", "None", 0, 90 },
}
for id, s in STYLE do
	local f = folder(Styles, id)
	f:SetAttribute("LabelColor", hex(s[1]))
	f:SetAttribute("StrokeColor", hex(s[2]))
	f:SetAttribute("Motion", s[3])
	f:SetAttribute("MotionPeriod", s[4])
	for _, g in { "TagGradient", "TextGradient" } do
		local grad = inst("UIGradient", f, g, { Enabled = true, Rotation = s[5], Offset = Vector2.new(0, 0) })
		grad:SetAttribute("Which", g .. ":" .. id)
	end
end

local FXF = folder(Assets, "FX")
local Muts = folder(FXF, "Mutations")
Muts:SetAttribute("ReferenceSize", 2)
local function fxStyle(id, attrs, emitters, ghosts, arc)
	local f = folder(Muts, "FX_Mutation_" .. id)
	local defaults = { ColorMode = "Keep", TintColor = hex("FFFFFF"), ShadeMin = 1, Material = "", Reflectance = -1, Motion = "None", MotionPeriod = 0, EmitterBoxScale = 1, LightBrightness = 0, LightRange = 0, GlitchJump = 0, GlitchSpread = 1 }
	for k, v in defaults do
		f:SetAttribute(k, if attrs[k] ~= nil then attrs[k] else v)
	end
	local ef = folder(f, "Emitters")
	for _, name in emitters do
		inst("ParticleEmitter", ef, name, {
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.35, 1), NumberSequenceKeypoint.new(1, 0) }),
			Speed = NumberRange.new(0.1, 0.2),
			Acceleration = Vector3.new(0, 0.5, 0),
		})
	end
	if ghosts then
		local gf = folder(f, "Ghosts")
		for name, a in ghosts do
			local c = inst("Configuration", gf, name)
			for k, v in a do
				c:SetAttribute(k, v)
			end
		end
	end
	if arc then
		local xf = folder(f, "Extras")
		local m = inst("Model", xf, "RainbowArc")
		m:SetAttribute("FitHeight", 2)
		local root = inst("Part", m, "Root", { Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2) })
		m.PrimaryPart = root
	end
	return f
end
fxStyle("Gold", { ColorMode = "Shade", TintColor = hex("FFC531"), ShadeMin = 0.5, Material = "Foil", Reflectance = 0.05 }, { "Sparkles" })
fxStyle("Shiny", { Reflectance = 0.1 }, { "Glints", "Twinkles" })
fxStyle("Neon", { ColorMode = "Saturate", Material = "Neon", Motion = "Pulse", MotionPeriod = 1.6, LightBrightness = 1.2, LightRange = 6 }, {}, {
	Glow_01 = { Color = hex("FFFFFF"), KeepColor = true, Material = "Neon", Transparency = 0.7, Offset = Vector3.zero, Scale = 1.06, Jitter = 0 },
})
fxStyle("Glitch", { Motion = "Glitch", MotionPeriod = 0.9, EmitterBoxScale = 0.8, GlitchJump = 0.03, GlitchSpread = 1.8 }, { "PixelsMagenta" }, {
	Ghost_01 = { Color = hex("FF2E88"), KeepColor = false, Material = "ForceField", Transparency = 0, Offset = Vector3.new(-0.025, 0.01, 0), Scale = 1, Jitter = 0.015 },
	Ghost_02 = { Color = hex("2EFFF0"), KeepColor = false, Material = "ForceField", Transparency = 0, Offset = Vector3.new(0.025, -0.01, 0), Scale = 1, Jitter = 0.015 },
})
fxStyle("Rainbow", { ColorMode = "Shade", TintColor = hex("FF4D4D"), ShadeMin = 0.65, Material = "Neon", Motion = "Rainbow", MotionPeriod = 3, LightBrightness = 1, LightRange = 6 }, { "Sparkles" }, {
	Glow_01 = { Color = hex("FFFFFF"), KeepColor = true, Material = "Neon", Transparency = 0.78, Offset = Vector3.zero, Scale = 1.08, Jitter = 0 },
}, true)
-- Diamond : volontairement absent (FX manquant).

local Fx = requireModule(FxModule)
Fx.Start()

local BODY = hex("802020")
local CAP = hex("E0E0E0")
local HALO = hex("FFD700")
-- Objet : Root invisible (PrimaryPart), Body et Cap visibles, RarityHalo, BB_Item sur BillboardPoint ; boîte 2 × 3 × 1.
local function makeItem(name, tag, effect, size, at, opts)
	opts = opts or {}
	local m = inst("Model", nil, name)
	local base = CFrame.new(at or Vector3.new(0, 0, 0))
	local root = inst("Part", m, "Root", { Transparency = 1, Color = hex("123456"), Size = Vector3.new(2, 3, 1), CFrame = base * CFrame.new(0, 1.5, 0), Material = Enum.Material.Plastic, Reflectance = 0 })
	root.Anchored = opts.anchored ~= false
	m.PrimaryPart = root
	local body = inst("Part", m, "Body", { Color = BODY, Size = Vector3.new(2, 2, 1), CFrame = base * CFrame.new(0, 1, 0), Material = Enum.Material.Plastic, Reflectance = 0 })
	body.Anchored = opts.anchored ~= false
	local cap = inst("Part", m, "Cap", { Color = CAP, Size = Vector3.new(1, 1, 1), CFrame = base * CFrame.new(0, 2.5, 0), Material = Enum.Material.SmoothPlastic, Reflectance = 0 })
	cap.Anchored = opts.anchored ~= false
	inst("Part", m, "RarityHalo", { Color = HALO, Size = Vector3.new(6, 0.2, 6), CFrame = base, Material = Enum.Material.Neon, Reflectance = 0 })
	local point = inst("Attachment", root, "BillboardPoint")
	local bb = inst("BillboardGui", point, "BB_Item")
	inst("TextLabel", bb, "ItemName", { Text = "Soda Can", TextColor3 = hex("FFFFFF") })
	local mut = inst("TextLabel", bb, "Mutation", { Text = "BIG GOLD", TextColor3 = hex("FFC21A") })
	inst("UIStroke", mut, "UIStroke", { Color = hex("000000"), Transparency = 0 })
	inst("ProximityPrompt", cap, "StealPrompt")
	if opts.idle then
		m:SetAttribute("Idle", "Spin")
	end
	m:SetAttribute("ItemUid", "uid-" .. name)
	m:SetAttribute("MutationEffect", effect)
	m:SetAttribute("MutationSize", size)
	m.Parent = Workspace
	CollectionService:AddTag(m, tag)
	return m, body, cap, root, mut
end
local function holderOf(model)
	local st = Fx.GetState(model)
	return if st then st.Holder else nil
end
local function countLog(text)
	local n = 0
	for _, l in LOG do
		if string.find(l.text, text, 1, true) then
			n += 1
		end
	end
	return n
end

---------------------------------------------------------------- 1. StyleId
check(Fx.StyleId({ Effect = "Gold" }) == "Gold", "StyleId : effet")
check(Fx.StyleId({ Size = "Big", Effect = "Neon" }) == "Neon", "StyleId : taille + effet = l'effet")
check(Fx.StyleId({ Size = "Big" }) == "Size", "StyleId : taille seule = Size")
check(Fx.StyleId(nil) == nil and Fx.StyleId({ Effect = "Nope" }) == nil, "StyleId : rien sans mutation connue")

---------------------------------------------------------------- 2. MutationTag (inventaire)
local PlayerGui = folder(Workspace, "PlayerGuiStub")
local screen = inst("ScreenGui", PlayerGui, "UI_Inventory", { Enabled = true })
local card = inst("Frame", screen, "Card")
local tag = inst("Frame", card, "MutationTag")
local origGrad = inst("UIGradient", tag, "UIGradient", { Enabled = true, Rotation = 0, Offset = Vector2.new(0, 0) })
local tagStroke = inst("UIStroke", tag, "UIStroke", { Color = hex("111111"), Transparency = 0 })
local tagLabel = inst("TextLabel", tag, "MutationLabel", { Text = "BIG GOLD", TextColor3 = hex("3A2200") })
local labelStroke = inst("UIStroke", tagLabel, "UIStroke", { Color = hex("222222"), Transparency = 0 })

Fx.StyleTag(tag, tagLabel, { Size = "Big", Effect = "Gold" })
local own = tag:FindFirstChild("MutationGradient")
check(own ~= nil and own:GetAttribute("Which") == "TagGradient:Gold", "tag : TagGradient de Gold posé (MutationGradient)")
check(origGrad.Enabled == false, "tag : l'UIGradient de Clément est éteint (remplacé)")
check(tagLabel.TextColor3 == hex("FFFFFF"), "tag : MutationLabel à LabelColor")
check(tagStroke.Color == hex("6B3A00") and labelStroke.Color == hex("6B3A00"), "tag : contours à StrokeColor")
Fx.StyleTag(tag, tagLabel, { Size = "Big", Effect = "Gold" })
local grads = 0
for _, c in tag:GetChildren() do
	if c.Name == "MutationGradient" then
		grads += 1
	end
end
check(grads == 1 and tag:FindFirstChild("MutationGradient") == own, "tag : carte repeinte, même dégradé (pas de doublon)")
-- Shine : l'Offset X balaie de −1 à 1.
local xs = {}
for _ = 1, 150 do
	advance(1 / 60)
	xs[#xs + 1] = own.Offset.X
end
local minX, maxX = math.huge, -math.huge
for _, x in xs do
	minX = math.min(minX, x)
	maxX = math.max(maxX, x)
end
check(minX >= -1 - 1e-6 and maxX <= 1 + 1e-6 and maxX > 0, "Shine : Offset X balayé entre −1 et 1 (" .. string.format("%.2f..%.2f", minX, maxX) .. ")")
-- écran éteint : plus rien ne bouge
screen.Enabled = false
local frozen = own.Offset.X
advance(2)
check(own.Offset.X == frozen, "écran éteint : le dégradé n'est pas animé")
screen.Enabled = true
-- taille seule : style Size, sans mouvement
Fx.StyleTag(tag, tagLabel, { Size = "Huge" })
local sizeGrad = tag:FindFirstChild("MutationGradient")
check(sizeGrad ~= nil and sizeGrad:GetAttribute("Which") == "TagGradient:Size", "tag : taille seule = style Size")
-- sans mutation : remis comme avant
Fx.StyleTag(tag, tagLabel, nil)
check(tag:FindFirstChild("MutationGradient") == nil, "tag sans mutation : dégradé retiré")
check(origGrad.Enabled == true, "tag sans mutation : UIGradient de Clément rallumé")
check(tagLabel.TextColor3 == hex("3A2200") and tagStroke.Color == hex("111111") and labelStroke.Color == hex("222222"), "tag sans mutation : couleurs d'origine")

-- Mouvements des autres styles (lignes de texte libres).
local function motionLabel(id)
	local l = inst("TextLabel", screen, "M_" .. id, { TextColor3 = hex("FF0000") })
	local s = inst("UIStroke", l, "UIStroke", { Color = hex("000000"), Transparency = 0 })
	Fx.StyleText(l, { Effect = id })
	return l, l:FindFirstChild("MutationGradient"), s
end
local neonL, neonG, neonS = motionLabel("Neon")
local glitchL, glitchG = motionLabel("Glitch")
local hackedL, hackedG = motionLabel("Hacked")
local rainbowL, rainbowG = motionLabel("Rainbow")
check(neonL.TextColor3 == hex("FFFFFF") and neonG:GetAttribute("Which") == "TextGradient:Neon", "texte : TextGradient, texte blanc")
local pulseMin, pulseMax, glitchJumps, ys, rots = math.huge, -math.huge, 0, {}, {}
for _ = 1, 240 do
	advance(1 / 60)
	pulseMin = math.min(pulseMin, neonS.Transparency)
	pulseMax = math.max(pulseMax, neonS.Transparency)
	if math.abs(math.abs(glitchG.Offset.X) - 0.3) < 1e-6 then
		glitchJumps += 1
	end
	ys[hackedG.Offset.Y] = true
	rots[rainbowG.Rotation] = true
end
check(pulseMin >= 0 and pulseMax <= 0.4 + 1e-6 and pulseMax > 0.3, "Pulse : contours entre 0 et 0,4")
check(glitchJumps > 0 and glitchJumps < 120, "Glitch : Offset X saute de ±0,3 par moments (" .. glitchJumps .. " images)")
local nY, nR = 0, 0
for _ in ys do
	nY += 1
end
for _ in rots do
	nR += 1
end
check(nY > 20, "Scan : Offset Y défile")
check(nR > 20, "Spin : Rotation tourne")
local rainbowLabel = rainbowL -- (garde la référence)
rainbowLabel:Destroy()
advance(0.1)
check(Fx.GetStats().Texts == 3, "texte détruit : plus suivi (" .. Fx.GetStats().Texts .. ")")

---------------------------------------------------------------- 3. objets
local gold, goldBody, goldCap, goldRoot, goldMut = makeItem("ITM_Gold", "DisplayItem", "Gold", "Big", Vector3.new(0, 0, 0))
advance(0.1)
check(Fx.GetState(gold) == nil, "objet : pas habillé avant une échelle stable")
advance(0.6)
local st = Fx.GetState(gold)
check(st ~= nil and st.Effect == "Gold" and st.Shown == true, "Gold : habillé et montré (proche)")
check(goldMut.TextColor3 == hex("FFFFFF") and goldMut:FindFirstChild("MutationGradient") ~= nil
	and goldMut:FindFirstChild("MutationGradient"):GetAttribute("Which") == "TextGradient:Gold", "BB_Item : ligne Mutation au style Gold, texte blanc")
check(goldMut.UIStroke.Color == hex("6B3A00"), "BB_Item : contour à StrokeColor")
local tint = hex("FFC531")
local lumBody, lumCap = 0.299 * BODY.R + 0.587 * BODY.G + 0.114 * BODY.B, 0.299 * CAP.R + 0.587 * CAP.G + 0.114 * CAP.B
local shadeBody = 0.5 + 0.5 * math.clamp(lumBody / lumCap, 0, 1)
check(goldBody.Color == Color3.new(tint.R * shadeBody, tint.G * shadeBody, tint.B * shadeBody), "Shade : TintColor × clarté de la pièce")
check(goldCap.Color == tint, "Shade : la pièce la plus claire prend la teinte pleine")
check(str(goldBody.Material) == "Enum.Material.Foil" and goldBody.Reflectance == 0.05, "Gold : matière Foil, reflet 0,05")
check(goldRoot.Color == hex("123456") and str(goldRoot.Material) == "Enum.Material.Plastic", "Root invisible : jamais touchée")
check(gold.RarityHalo.Color == HALO and str(gold.RarityHalo.Material) == "Enum.Material.Neon", "halo de rareté : jamais touché")
local holder = holderOf(gold)
check(holder ~= nil and holder.Parent ~= nil and holder.Parent.Name == "_MutationFX" and not holder:IsDescendantOf(gold), "FX rangés dans Workspace/_MutationFX, pas dans l'objet")
local fxPart = holder and holder:FindFirstChild("MutationFX")
check(fxPart ~= nil and fxPart.Transparency == 1 and fxPart.CanQuery == false, "MutationFX : pièce invisible, sans requête")
local em = fxPart and fxPart:FindFirstChild("Sparkles")
-- boîte des pièces visibles : 2 × 3 × 1 → k = 3 / 2
check(em ~= nil and near(em.Size.Keypoints[2].Value, 1.5) and near(em.Speed.Max, 0.3), "particules : tailles et vitesses × plus grand côté / ReferenceSize")
check(fxPart and near(fxPart.Size.X, 2) and near(fxPart.Size.Y, 3) and near(fxPart.Position.Y, 1.5), "MutationFX : à la boîte de l'objet (sans le halo)")

-- Keep (Shiny)
local shiny, shinyBody = makeItem("ITM_Shiny", "FloorItem", "Shiny", nil, Vector3.new(10, 0, 0))
advance(0.6)
check(Fx.GetState(shiny) ~= nil and shinyBody.Color == BODY and shinyBody.Reflectance == 0.1 and str(shinyBody.Material) == "Enum.Material.Plastic", "Keep : couleurs et matière gardées, reflet posé")

-- Saturate + coque (Neon)
local neon, neonBody = makeItem("ITM_Neon", "ShelfItem", "Neon", nil, Vector3.new(-10, 0, 0))
advance(0.6)
local nh, ns, nv = neonBody.Color:ToHSV()
check(ns >= 0.85 - 1e-3 and nv >= 0.75, "Saturate : couleurs poussées")
local neonHolder = holderOf(neon)
local glow = neonHolder and neonHolder:FindFirstChild("MutationGlow_01")
check(glow ~= nil, "Neon : coque MutationGlow_01")
local glowBody = glow and glow:FindFirstChild("Body")
check(glowBody ~= nil and glowBody.Color == neonBody.Color and str(glowBody.Material) == "Enum.Material.Neon", "coque KeepColor : couleur de la pièce de l'objet, néon")
check(glow and glow:FindFirstChild("RarityHalo", true) == nil and glow:FindFirstChild("BB_Item", true) == nil and glow:FindFirstChild("StealPrompt", true) == nil, "copie : sans halo, billboard ni invite")
check(glow and not CollectionService:HasTag(glow, "ShelfItem") and glow:GetAttribute("ItemUid") == nil and glow:GetAttribute("MutationEffect") == nil, "copie : sans tag ni attribut")
check(glowBody and glowBody.Anchored == true and glowBody.CanQuery == false and glowBody.CanCollide == false, "copie : ancrée, sans collision ni requête")
check(glow and glow:FindFirstChild("Root") ~= nil and glow.Root.Transparency == 1, "copie : la Root reste invisible")
local light = neonHolder and neonHolder:FindFirstChild("MutationLight", true)
check(light ~= nil and near(light.Range, 6 * 1.5), "Neon : PointLight, portée × k")
local c1 = neonBody.Color
local b1 = light and light.Brightness
advance(0.4)
check(neonBody.Color ~= c1 and light and light.Brightness ~= b1, "Pulse : la couleur et la lumière respirent")
check(glowBody and glowBody.Color == neonBody.Color, "Pulse : la coque suit la couleur")

-- Glitch : doubles, saut remis exactement
local glitch, glitchBody = makeItem("ITM_Glitch", "DisplayItem", "Glitch", nil, Vector3.new(0, 0, -10))
local glitchStart = glitchBody.CFrame
advance(0.6)
local gh = holderOf(glitch)
local g1, g2 = gh and gh:FindFirstChild("MutationGhost_01"), gh and gh:FindFirstChild("MutationGhost_02")
check(g1 ~= nil and g2 ~= nil and g1.Body.Color == hex("FF2E88") and str(g1.Body.Material) == "Enum.Material.ForceField", "Glitch : deux doubles ForceField magenta et cyan")
local sawBurst, sawMoved, ghostMoves, last = false, false, 0, g1 and g1.Body.CFrame
for _ = 1, 300 do
	advance(1 / 60)
	local s = Fx.GetState(glitch)
	if s and s.Bursting then
		sawBurst = true
		if glitchBody.CFrame ~= glitchStart then
			sawMoved = true
		end
	end
	if g1 and g1.Body.CFrame ~= last then
		ghostMoves += 1
		last = g1.Body.CFrame
	end
end
check(sawBurst and sawMoved, "Glitch : l'objet saute pendant un saut")
check(ghostMoves > 20, "Glitch : les doubles tremblent (" .. ghostMoves .. " déplacements)")
-- fin de saut : remis exactement
for _ = 1, 120 do
	local s = Fx.GetState(glitch)
	if s and not s.Bursting then
		break
	end
	advance(1 / 60)
end
check(glitchBody.CFrame == glitchStart, "Glitch : après le saut, l'objet est exactement à sa place")
-- objet animé (Idle) : jamais de saut
local idle, idleBody = makeItem("ITM_GlitchIdle", "DisplayItem", "Glitch", nil, Vector3.new(5, 0, -10), { idle = true })
local idleStart = idleBody.CFrame
advance(0.6)
local idleMoved = false
for _ = 1, 200 do
	advance(1 / 60)
	if idleBody.CFrame ~= idleStart then
		idleMoved = true
	end
end
check(Fx.GetState(idle) ~= nil and not idleMoved, "Glitch sur un objet animé (Idle) : pas de saut")

-- Rainbow : arc derrière, couleur qui tourne
local rainbow, rainbowBody = makeItem("ITM_Rainbow", "DisplayItem", "Rainbow", nil, Vector3.new(-5, 0, -10))
advance(0.6)
local rh = holderOf(rainbow)
local arc = rh and rh:FindFirstChild("RainbowArc")
check(arc ~= nil and arc:GetPivot().Position.Z > rainbowBody.Position.Z, "Rainbow : arc-en-ciel derrière l'objet (+Z)")
local rc = rainbowBody.Color
advance(0.5)
check(rainbowBody.Color ~= rc, "Rainbow : la couleur tourne")
local rglow = rh and rh:FindFirstChild("MutationGlow_01")
check(rglow and rglow.Body.Color == rainbowBody.Color, "Rainbow : la coque suit la couleur")

-- objet porté (non ancré) : les effets suivent
local carried, carriedBody = makeItem("CarryVisual", "CarriedItem", "Gold", nil, Vector3.new(0, 0, 5), { anchored = false })
advance(0.6)
local ch = holderOf(carried)
local cfx = ch and ch:FindFirstChild("MutationFX")
check(cfx ~= nil, "objet porté : habillé")
carried:PivotTo(carried:GetPivot() * CFrame.new(3, 0, 0))
advance(1 / 60)
check(cfx and near(cfx.Position.X, carriedBody.Position.X) and near(cfx.Position.X, 3), "objet porté : MutationFX suit l'objet")

-- objet loin : habillé (couleurs) mais rien de montré ni d'animé
local far, farBody = makeItem("ITM_Far", "DisplayItem", "Rainbow", nil, Vector3.new(500, 0, 0))
advance(0.6)
local fs = Fx.GetState(far)
check(fs ~= nil and fs.Shown == false and fs.Holder.Parent == nil, "objet loin : particules, doubles et arc retirés")
local farColor = farBody.Color
advance(1)
check(farBody.Color == farColor, "objet loin : couleur figée (pas animé)")
local camera = Workspace.CurrentCamera
local oldCam = camera.CFrame
camera.CFrame = CFrame.new(500, 10, 20)
advance(0.3)
check(Fx.GetState(far).Shown == true and holderOf(far).Parent ~= nil, "objet revenu près : effets remis")
local nearColor = farBody.Color
advance(0.5)
check(farBody.Color ~= nearColor, "objet proche : de nouveau animé")
camera.CFrame = oldCam
advance(0.3)

-- échelle qui bouge (révélation du rayon) : habillé seulement une fois stable, à sa taille finale
local grow, growBody = makeItem("ITM_Grow", "ShelfItem", "Gold", nil, Vector3.new(0, 0, 15))
grow:ScaleTo(0.2)
for i = 1, 6 do
	advance(0.1)
	grow:ScaleTo(0.2 + 0.8 * i / 6)
end
check(Fx.GetState(grow) == nil, "échelle qui bouge : pas encore habillé")
advance(0.7)
local gfx = holderOf(grow) and holderOf(grow):FindFirstChild("MutationFX")
check(gfx ~= nil and near(gfx.Size.Y, 3, 1e-3), "échelle stable : habillé à la taille finale")

-- mutation retirée : tout est nettoyé
local goldHolder = holderOf(gold)
gold:SetAttribute("MutationEffect", nil)
advance(0.3)
check(Fx.GetState(gold) == nil and goldHolder.Parent == nil, "mutation retirée : effets détruits")
check(goldBody.Color == BODY and goldCap.Color == CAP and str(goldBody.Material) == "Enum.Material.Plastic" and goldBody.Reflectance == 0, "mutation retirée : couleurs, matière et reflet d'origine")
check(goldMut:FindFirstChild("MutationGradient") ~= nil and goldMut:FindFirstChild("MutationGradient"):GetAttribute("Which") == "TextGradient:Size", "taille restée : BB_Item au style Size")
gold:SetAttribute("MutationSize", nil)
advance(0.3)
check(goldMut:FindFirstChild("MutationGradient") == nil and goldMut.TextColor3 == hex("FFC21A"), "plus de mutation : ligne Mutation remise comme avant")

-- objet détruit : plus suivi, effets détruits
local neonHolder2 = holderOf(neon)
local tracked = Fx.GetStats().Tracked
neon:Destroy()
advance(0.3)
check(neonHolder2.Parent == nil and Fx.GetStats().Tracked == tracked - 1, "objet détruit : effets détruits, plus suivi")

-- FX manquant : objet normal, un seul avertissement
local d1, d1Body = makeItem("ITM_Diamond1", "DisplayItem", "Diamond", nil, Vector3.new(0, 0, 25))
local d2 = makeItem("ITM_Diamond2", "DisplayItem", "Diamond", nil, Vector3.new(3, 0, 25))
advance(1)
check(Fx.GetState(d1) == nil and Fx.GetState(d2) == nil and d1Body.Color == BODY, "FX manquant : l'objet reste normal")
check(countLog("FX_Mutation_Diamond absent") == 1, "FX manquant : un seul avertissement (" .. countLog("FX_Mutation_Diamond absent") .. ")")

local others = 0
for _, l in LOG do
	if l.kind == "ERROR" or (l.kind == "WARN" and not string.find(l.text, "FX_Mutation_Diamond absent", 1, true)) then
		others += 1
		print("    " .. l.text)
	end
end
check(others == 0, "aucune erreur ni autre avertissement dans le journal")
