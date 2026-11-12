--[[
	Aperçu en Edit du texte d'argent au-dessus des plaques CollectPad_xx (2026-11-12, référence de
	Clément) : « Collect » en blanc, le montant en grand en vert, et la ligne « (Offline cash: $X) »
	en petit, sans fond, contour noir. Taille en studs : plus petit de loin, comme sur la référence.
	Copies dans CoreGui (_PROTO_CollectText), sur les plaques de PLOT_Shop_01 : rien n'est changé
	dans la map. Le texte « $0 » collé sur les plaques reste visible dessous : c'est l'actuel
	AmountGui (SurfaceGui), que cette proposition remplace.
	Proposition pour le contrat : AmountGui devient un BillboardGui (même nom, même Amount), avec en
	plus CollectLabel et OfflineLabel. Arrêt : _G.CollectProto.Stop() ; caméra : _G.CollectProto.Look().
]]

local CG = game:GetService("CoreGui")
if _G.CollectProto then pcall(_G.CollectProto.Stop) end
local folder = Instance.new("Folder"); folder.Name = "_PROTO_CollectText"; folder.Parent = CG
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
local function make(class, parent, props)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local function label(p, name, text, color, props)
	local t = make("TextLabel", p, { Name = name, Text = text, FontFace = FONT, TextColor3 = color, BackgroundTransparency = 1, TextScaled = true, TextWrapped = true })
	make("UIStroke", t, { Thickness = 3, Color = Color3.new(0, 0, 0), ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
	for k, v in props or {} do t[k] = v end
	return t
end
local shop = workspace.Map.Hub.Shops.PLOT_Shop_01
local samples = { CollectPad_01 = { "$1.6M", "(Offline cash: $1.6M)" }, CollectPad_02 = { "$26K" }, CollectPad_03 = { "$11.2K" }, CollectPad_04 = { "$131M", "(Offline cash: $129.6M)" } }
for _, pad in shop:GetDescendants() do
	if pad:IsA("BasePart") and pad.Name:match("^CollectPad_%d+$") then
		local plate = pad:FindFirstChild("Plate") or pad
		local s = samples[pad.Name] or { "$0" }
		local bb = make("BillboardGui", folder, { Name = "AmountGui_" .. pad.Name, Adornee = plate, Size = UDim2.fromScale(5.2, 2.7), StudsOffset = Vector3.new(0, 2, 0), LightInfluence = 0, MaxDistance = 70, AlwaysOnTop = false })
		label(bb, "CollectLabel", "Collect", Color3.new(1, 1, 1), { Size = UDim2.fromScale(1, 0.36) })
		label(bb, "Amount", s[1], Color3.fromHex("5cff4a"), { Position = UDim2.fromScale(0, 0.33), Size = UDim2.fromScale(1, 0.46) })
		local off = label(bb, "OfflineLabel", s[2] or "", Color3.fromHex("d8dbe6"), { Position = UDim2.fromScale(0, 0.8), Size = UDim2.fromScale(1, 0.18), Visible = s[2] ~= nil })
		local st = off:FindFirstChildOfClass("UIStroke")
		if st then st.Thickness = 2 end
	end
end
local cam = workspace.CurrentCamera
local pos, target = Vector3.new(-98, 13, 185), Vector3.new(-117, 0.5, 185)
local function look()
	cam.CFrame = CFrame.lookAt(pos, target)
	cam.Focus = CFrame.new(target)
end
_G.CollectProto = { Stop = function() folder:Destroy(); _G.CollectProto = nil end, Look = look }
look()
return "aperçu des textes d'argent posé"
