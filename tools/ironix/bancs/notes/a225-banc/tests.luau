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
---------------------------------------------------------------- a225 : copie de la cinématique (RevealItem)
check(Fx.GetState ~= nil, "a225 : banc prêt")
-- 1. copie mutée, petite au départ : habillée dès le premier contrôle (sans échelle stable)
local rv, rvBody = makeItem("RevealItem", "RevealItem", "Gold", nil, Vector3.new(40, 0, 0))
rv:ScaleTo(0.2)
advance(0.3)
local s1 = Fx.GetState(rv)
check(s1 ~= nil and s1.Effect == "Gold", "copie Gold : habillée dès le début, pendant qu'elle est petite")
check(rvBody.Color ~= BODY, "copie Gold : couleur de la mutation posée")
local h1 = holderOf(rv)
-- 2. elle grossit de 0,2 à 1 en 1 s (une image sur 60) : jamais déshabillée, rhabillée à sa taille
local undressed, holders, seen = 0, 0, {}
for i = 1, 60 do
	rv:ScaleTo(0.2 + 0.8 * i / 60)
	advance(1 / 60)
	local h = holderOf(rv)
	if Fx.GetState(rv) == nil or rvBody.Color == BODY then
		undressed += 1
	end
	if h and not seen[h] then
		seen[h] = true
		holders += 1
	end
end
check(undressed == 0, "copie qui grossit : habillage jamais retiré (" .. undressed .. " images sans)")
check(holders >= 2 and holders <= 12, "copie qui grossit : rhabillée à sa nouvelle taille (" .. holders .. " habillages)")
check(h1 ~= nil and h1.Parent == nil, "copie qui grossit : l'ancien habillage est retiré")
-- 3. petite variation (moins de RevealRescale) : même habillage
advance(0.3)
local h2 = holderOf(rv)
rv:ScaleTo(1.05)
advance(0.3)
check(h2 ~= nil and holderOf(rv) == h2, "variation de 5 % : habillage gardé")
-- 4. retrait propre avec la copie
rv:Destroy()
advance(0.3)
check(Fx.GetState(rv) == nil and h2.Parent == nil, "copie détruite : habillage retiré")
-- 5. sans mutation : rien
local plain, plainBody = makeItem("RevealItem", "RevealItem", nil, nil, Vector3.new(60, 0, 0))
plain:ScaleTo(0.2)
advance(1)
check(Fx.GetState(plain) == nil and plainBody.Color == BODY, "copie sans mutation : rien posé")
plain:Destroy()
-- 6. toutes les mutations du Config (effets) : habillée ou FX absent signalé, jamais d'erreur
local MutCfg = requireModule(ConfigF:FindFirstChild("Mutations"))
for _, entry in MutCfg.Effects do
	local e = entry.Id
	local m = makeItem("RevealItem", "RevealItem", e, nil, Vector3.new(80, 0, 0))
	m:ScaleTo(0.3)
	advance(0.3)
	local st = Fx.GetState(m)
	check(st ~= nil or countLog("FX_Mutation_" .. e) > 0, "copie " .. e .. " : habillée (ou FX absent signalé)")
	m:Destroy()
	advance(0.3)
end
-- 7. un objet exposé attend toujours une échelle stable (inchangé)
local disp = makeItem("ITM_Disp", "DisplayItem", "Gold", nil, Vector3.new(100, 0, 0))
advance(0.1)
check(Fx.GetState(disp) == nil, "objet exposé : toujours pas habillé avant une échelle stable")
