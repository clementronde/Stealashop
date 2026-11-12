--[[
	Texte d'argent flottant au-dessus des plaques CollectPad_xx (validé par Clément le 2026-11-12,
	aperçu : collect_text_preview.luau). À lancer en Edit, SEULEMENT quand Ironix a passé le contrat
	(Contract/Models.luau : AmountGui en BillboardGui au lieu de SurfaceGui), sinon le ContractChecker
	affiche 44 lignes rouges. Annulable (Ctrl+Z).
	Pour chaque Plate/AmountGui (SurfaceGui) des modèles de boutique (Assets/Plots : PLOT_Shop,
	PLOT_Shop_Rayons) et des 6 boutiques du hub : remplace par un BillboardGui AmountGui (même nom,
	même parent) qui contient :
	- CollectLabel « Collect » (blanc) ;
	- Amount « $0 » (vert 5cff4a, en grand) : le code y écrit déjà le montant (AmountGui.Amount) ;
	- OfflineLabel (caché, gris clair) : le code y écrit « (Offline cash: $X) » s'il le veut.
	Texte sans fond, contour noir, taille en studs (5,2 × 2,7), 2 studs au-dessus de la plaque.
	Aucun script.
]]

local CH = game:GetService("ChangeHistoryService")
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

local function build(plate)
	local old = plate:FindFirstChild("AmountGui")
	if old and old:IsA("BillboardGui") then return false end
	local bb = Instance.new("BillboardGui")
	bb.Name = "AmountGui"
	bb.Size = UDim2.fromScale(5.2, 2.7)
	bb.StudsOffset = Vector3.new(0, 2, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 70
	bb.AlwaysOnTop = false
	bb.ResetOnSpawn = false
	label(bb, "CollectLabel", "Collect", Color3.new(1, 1, 1), { Size = UDim2.fromScale(1, 0.36) })
	label(bb, "Amount", "$0", Color3.fromHex("5cff4a"), { Position = UDim2.fromScale(0, 0.33), Size = UDim2.fromScale(1, 0.46) })
	local off = label(bb, "OfflineLabel", "", Color3.fromHex("d8dbe6"), { Position = UDim2.fromScale(0, 0.8), Size = UDim2.fromScale(1, 0.18), Visible = false })
	local st = off:FindFirstChildOfClass("UIStroke")
	if st then st.Thickness = 2 end
	if old then old:Destroy() end
	bb.Parent = plate
	return true
end

local rec = CH:TryBeginRecording("Plaques : texte d'argent flottant (AmountGui en BillboardGui)")
local n = 0
for _, root in { game.ReplicatedStorage.Assets:FindFirstChild("Plots"), workspace.Map.Hub:FindFirstChild("Shops") } do
	if root then
		for _, d in root:GetDescendants() do
			if d.Name == "Plate" and d:IsA("BasePart") and d.Parent and d.Parent.Name:match("^CollectPad_%d+$") then
				if build(d) then n += 1 end
			end
		end
	end
end
if rec then CH:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
return n .. " plaques passées au texte flottant"
