--!nocheck
-- Retouches du lot 1 des tapis apres les captures d'essai (Chef de projet, 26/11 : « un vrai carton, avec ses ondulations
-- et du scotch brun, et le FRAGILE sur la face visible » ; « un metal net a la place de l'eponge »). A lancer en Edit APRES
-- tools/clement/tapis_lib.luau + tools/clement/tapis_lot1.luau (qui font deja carton lisse, Bronze en MetalBrosse, details
-- de Base). Face visible = +Z (cote coureur), vue de 3/4 arriere. Aucun script ; le texte FRAGILE est une SurfaceGui.
local T = game.ServerStorage.Previews.TREADMILLS
local function part(parent, name, size, cf, hex, o)
	o = o or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = Color3.fromHex(hex)
	p.Material = o.mat or Enum.Material.SmoothPlastic
	if o.reflect then p.Reflectance = o.reflect end
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- ===== CARDBOARD =====
local dec = T.PLOT_Treadmill_Cardboard_v3.Decor
for _, d in dec:GetChildren() do
	if d.Name:find("Flute") or d.Name == "FragileBorder" then d:Destroy() end
end
-- scotch brun franc, un peu brillant
for _, d in dec:GetChildren() do
	if d:IsA("BasePart") and (d.Name:find("_Tape") or d.Name:find("_Flap")) then
		d.Color = Color3.fromHex("8E5B2B")
		d.Reflectance = 0.12
	end
end
-- ondulations : coin dechire sur la face visible de quelques cartons, cannelures verticales
local function flutes(box, u, v, w, h)
	local face = box.CFrame * CFrame.new(u, v, box.Size.Z / 2 + 0.012)
	part(dec, box.Name .. "_FluteBg", Vector3.new(w, h, 0.02), face, "#E9C48E")
	local n = math.max(4, math.floor(w / 0.11))
	for k = 1, n do
		local x = -w / 2 + (k - 0.5) * w / n
		part(dec, box.Name .. "_Flute" .. k, Vector3.new(0.035, h - 0.04, 0.02), face * CFrame.new(x, 0, 0.012), "#B88449")
	end
	part(dec, box.Name .. "_FluteTop", Vector3.new(w, 0.04, 0.03), face * CFrame.new(0, h / 2 - 0.02, 0.012), "#C99A5E")
end
flutes(dec.Lintel, 3.3, -0.25, 0.9, 0.5)
flutes(dec["Stack-1_2"], 0.35, -0.45, 0.55, 0.45)
flutes(dec["Stack1_1"], -0.3, 0.5, 0.6, 0.4)
flutes(dec["Stack1_3"], 0.3, -0.5, 0.5, 0.4)
-- FRAGILE lisible : etiquette blanche a bord rouge, texte rouge, sur la face visible du linteau
local lab = dec.FragileLabel
for _, n in { "FragileGlass", "FragileBar" } do
	local x = dec:FindFirstChild(n)
	if x then x:Destroy() end
end
local faceZ = (dec.Lintel.CFrame * CFrame.new(0, 0, dec.Lintel.Size.Z / 2)).Position.Z
lab.Color = Color3.fromHex("F4F1EA")
lab.Size = Vector3.new(lab.Size.X, lab.Size.Y, 0.08)
lab.CFrame = CFrame.new(lab.Position.X, lab.Position.Y, faceZ + 0.03)
part(dec, "FragileBorder", Vector3.new(lab.Size.X + 0.12, lab.Size.Y + 0.12, 0.03), CFrame.new(lab.Position.X, lab.Position.Y, faceZ + 0.005), "#D8343C")
local old = lab:FindFirstChild("FragileText")
if old then old:Destroy() end
local sg = Instance.new("SurfaceGui")
sg.Name = "FragileText"
sg.Face = Enum.NormalId.Back
sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
sg.PixelsPerStud = 80
sg.LightInfluence = 1
local t = Instance.new("TextLabel")
t.Name = "Label"
t.BackgroundTransparency = 1
t.Size = UDim2.fromScale(1, 1)
t.Font = Enum.Font.FredokaOne
t.Text = "FRAGILE"
t.TextScaled = true
t.TextWrapped = true
t.TextColor3 = Color3.fromHex("D8343C")
local pad = Instance.new("UIPadding")
pad.PaddingLeft, pad.PaddingRight = UDim.new(0.06, 0), UDim.new(0.06, 0)
pad.PaddingTop, pad.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.12, 0)
pad.Parent = t
t.Parent = sg
sg.Parent = lab
-- fleches « haut » posees sur la face (elles etaient a moitie dans le carton)
for _, n in { "UpArrow-1", "UpArrow1", "UpArrowHead-1", "UpArrowHead1" } do
	local a = dec:FindFirstChild(n)
	if a then a.CFrame = a.CFrame + Vector3.new(0, 0, 0.03) end
end

-- ===== BRONZE : metal net (piliers, bornes et medaille lisses, sans Reflectance : elle virait au rose sous le ciel ; bandes en MetalBrosse sombre) =====
for _, d in T.PLOT_Treadmill_Bronze_v3:GetDescendants() do
	if d:IsA("BasePart") and (d.Name:match("^Pillar%-?1$") or d.Name:match("^RearPost") or d.Name == "Medal") then
		d.MaterialVariant = ""
		d.Material = Enum.Material.SmoothPlastic
		d.Color = Color3.fromHex("A85E26")
		d.Reflectance = 0
	end
end
return "retouches du lot 1 faites"
